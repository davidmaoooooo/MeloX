import AVFoundation
import Combine
import Foundation

@MainActor
final class WatchPlaybackStore: ObservableObject {
    @Published private(set) var currentSong: WatchSong?
    @Published private var playbackQueue = WatchPlaybackQueue()
    @Published private(set) var isPlaying = false
    @Published private(set) var isLoading = false
    @Published private(set) var progress: TimeInterval = 0
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var repeatMode: WatchRepeatMode = .off
    @Published private(set) var volume: Double = 1
    @Published private(set) var errorMessage: String?

    private let api: WatchNeteaseAPI
    private let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var interruptionObserver: NSObjectProtocol?
    private var loadGeneration = 0
    private var progressUpdatedAt = Date()
    private var lastPersistenceDate = Date.distantPast
    private var wasPlayingBeforeInterruption = false

    var queue: [WatchSong] {
        playbackQueue.songs
    }

    var currentIndex: Int {
        playbackQueue.currentIndex
    }

    var isShuffled: Bool {
        playbackQueue.isShuffled
    }

    var playbackOrderIndices: [Int] {
        playbackQueue.playbackOrderIndices
    }

    init(api: WatchNeteaseAPI) {
        self.api = api
        volume = UserDefaults.standard.double(
            forKey: WatchPreferenceKey.volume
        )
        player.volume = Float(volume)
        restorePersistedSession()
        configureAudioSession()
        observePlayer()
        observeAudioSession()
    }

    func play(
        _ song: WatchSong,
        in songs: [WatchSong]? = nil
    ) async {
        if let songs, !songs.isEmpty {
            let index =
                songs.firstIndex(where: { $0.id == song.id }) ?? 0
            playbackQueue.replace(with: songs, startingAt: index)
        } else if let index = queue.firstIndex(where: { $0.id == song.id }) {
            playbackQueue.select(index: index)
        } else {
            playbackQueue.replace(with: [song], startingAt: 0)
        }
        currentSong = playbackQueue.currentSong
        await loadCurrentSong(
            autoplay: UserDefaults.standard.bool(
                forKey: WatchPreferenceKey.autoPlaySelection
            )
        )
    }

    func playQueueItem(at index: Int) async {
        guard playbackQueue.select(index: index) else { return }
        currentSong = playbackQueue.currentSong
        await loadCurrentSong(autoplay: true)
    }

    func togglePlayback() {
        guard currentSong != nil else { return }
        if player.currentItem == nil {
            let restoredPosition = progress
            Task {
                await loadCurrentSong(
                    autoplay: true,
                    restorePosition: restoredPosition
                )
            }
        } else if isPlaying {
            let pausedPosition = position(at: Date())
            player.pause()
            isPlaying = false
            progress = pausedPosition
            progressUpdatedAt = Date()
            persistSession()
        } else {
            player.play()
            isPlaying = true
            progressUpdatedAt = Date()
        }
    }

    func next() async {
        guard !queue.isEmpty else { return }
        guard playbackQueue.move(
            by: 1,
            wraps: repeatMode == .all
        ) else {
            player.pause()
            isPlaying = false
            persistSession()
            return
        }
        currentSong = playbackQueue.currentSong
        await loadCurrentSong(autoplay: true)
    }

    func previous() async {
        let behavior = WatchPreviousButtonBehavior(
            rawValue: UserDefaults.standard.string(
                forKey: WatchPreferenceKey.previousButtonBehavior
            ) ?? ""
        ) ?? .restartAfterFiveSeconds
        if behavior == .restartAfterFiveSeconds,
           position(at: Date()) > 5 {
            seek(to: 0)
            return
        }
        guard !queue.isEmpty else { return }
        guard playbackQueue.move(
            by: -1,
            wraps: repeatMode == .all
        ) else {
            return
        }
        currentSong = playbackQueue.currentSong
        await loadCurrentSong(autoplay: true)
    }

    func seek(to seconds: TimeInterval) {
        let target = max(0, min(seconds, duration))
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        progress = target
        progressUpdatedAt = Date()
        persistSession()
    }

    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
        persistSession()
    }

    func setRepeatMode(_ mode: WatchRepeatMode) {
        repeatMode = mode
        persistSession()
    }

    func toggleShuffle() {
        playbackQueue.setShuffleEnabled(!isShuffled)
        persistSession()
    }

    func setShuffleEnabled(_ isEnabled: Bool) {
        playbackQueue.setShuffleEnabled(isEnabled)
        persistSession()
    }

    func setPlaybackMode(
        isShuffled: Bool,
        repeatMode: WatchRepeatMode
    ) {
        playbackQueue.setShuffleEnabled(isShuffled)
        self.repeatMode = repeatMode
        persistSession()
    }

    func setVolume(_ value: Double) {
        volume = min(max(value, 0), 1)
        player.volume = Float(volume)
        UserDefaults.standard.set(
            volume,
            forKey: WatchPreferenceKey.volume
        )
    }

    func position(at date: Date) -> TimeInterval {
        guard isPlaying else { return progress }
        let estimate = progress
            + max(date.timeIntervalSince(progressUpdatedAt), 0)
        guard duration > 0 else { return max(estimate, 0) }
        return min(max(estimate, 0), duration)
    }

    func reloadForSelectedQuality() async {
        guard currentSong != nil else { return }
        let currentPosition = position(at: Date())
        let shouldResume = isPlaying
        await loadCurrentSong(
            autoplay: shouldResume,
            restorePosition: currentPosition
        )
    }

    func setRestoresLastSession(_ isEnabled: Bool) {
        if isEnabled {
            persistSession()
        } else {
            UserDefaults.standard.removeObject(
                forKey: WatchPersistedPlaybackSession.storageKey
            )
        }
    }

    private func loadCurrentSong(
        autoplay: Bool,
        restorePosition: TimeInterval? = nil
    ) async {
        guard let currentSong else { return }
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        errorMessage = nil

        do {
            let quality = WatchStreamingQuality(
                rawValue: UserDefaults.standard.string(
                    forKey: WatchPreferenceKey.streamingQuality
                ) ?? ""
            ) ?? .high
            let url = try await api.playbackURL(
                id: currentSong.id,
                bitrate: quality.bitrate
            )
            guard generation == loadGeneration else { return }
            let item = AVPlayerItem(url: url)
            player.replaceCurrentItem(with: item)
            duration = currentSong.duration
            let targetPosition = min(
                max(restorePosition ?? 0, 0),
                max(duration, 0)
            )
            progress = targetPosition
            progressUpdatedAt = Date()
            if targetPosition > 0 {
                await player.seek(
                    to: CMTime(
                        seconds: targetPosition,
                        preferredTimescale: 600
                    ),
                    toleranceBefore: .zero,
                    toleranceAfter: .zero
                )
            }
            isLoading = false
            if autoplay {
                player.play()
                isPlaying = true
            } else {
                isPlaying = false
            }
            persistSession()
        } catch {
            guard generation == loadGeneration else { return }
            isLoading = false
            isPlaying = false
            errorMessage = error.localizedDescription
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func observePlayer() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.progress = max(time.seconds, 0)
                self.progressUpdatedAt = Date()
                if let itemDuration = self.player.currentItem?.duration.seconds,
                   itemDuration.isFinite,
                   itemDuration > 0 {
                    self.duration = itemDuration
                }
                self.isPlaying = self.player.timeControlStatus == .playing
                if Date().timeIntervalSince(self.lastPersistenceDate) >= 5 {
                    self.persistSession()
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.repeatMode == .one {
                    self.seek(to: 0)
                    self.player.play()
                } else {
                    await self.next()
                }
            }
        }
    }

    private func observeAudioSession() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { notification in
            let rawType = notification.userInfo?[
                AVAudioSessionInterruptionTypeKey
            ] as? UInt
            let rawOptions = notification.userInfo?[
                AVAudioSessionInterruptionOptionKey
            ] as? UInt ?? 0
            Task { @MainActor [weak self] in
                guard let rawType else { return }
                self?.handleAudioInterruption(
                    rawType: rawType,
                    rawOptions: rawOptions
                )
            }
        }
    }

    private func handleAudioInterruption(
        rawType: UInt,
        rawOptions: UInt
    ) {
        guard let type = AVAudioSession.InterruptionType(
            rawValue: rawType
        ) else {
            return
        }

        switch type {
        case .began:
            wasPlayingBeforeInterruption = isPlaying
            progress = position(at: Date())
            progressUpdatedAt = Date()
            player.pause()
            isPlaying = false
        case .ended:
            let shouldResume = AVAudioSession.InterruptionOptions(
                rawValue: rawOptions
            )
            .contains(.shouldResume)
            if wasPlayingBeforeInterruption,
               shouldResume,
               UserDefaults.standard.bool(
                forKey: WatchPreferenceKey.resumesAfterInterruption
               ) {
                player.play()
                isPlaying = true
                progressUpdatedAt = Date()
            }
            wasPlayingBeforeInterruption = false
        @unknown default:
            break
        }
    }

    private func restorePersistedSession() {
        guard UserDefaults.standard.bool(
            forKey: WatchPreferenceKey.restoresLastSession
        ),
        let data = UserDefaults.standard.data(
            forKey: WatchPersistedPlaybackSession.storageKey
        ),
        let session = try? JSONDecoder().decode(
            WatchPersistedPlaybackSession.self,
            from: data
        ),
        !session.queue.isEmpty else {
            return
        }

        playbackQueue.restore(
            songs: session.queue,
            currentIndex: session.currentIndex,
            isShuffled: session.isShuffled,
            shuffledOrder: session.shuffledOrder ?? []
        )
        currentSong = playbackQueue.currentSong
        duration = currentSong?.duration ?? 0
        progress = min(max(session.progress, 0), duration)
        progressUpdatedAt = Date()
        repeatMode =
            WatchRepeatMode(rawValue: session.repeatMode) ?? .off
    }

    private func persistSession() {
        guard UserDefaults.standard.bool(
            forKey: WatchPreferenceKey.restoresLastSession
        ),
        !queue.isEmpty else {
            return
        }
        let session = WatchPersistedPlaybackSession(
            queue: queue,
            currentIndex: currentIndex,
            progress: position(at: Date()),
            repeatMode: repeatMode.rawValue,
            isShuffled: isShuffled,
            shuffledOrder: playbackQueue.shuffledOrder
        )
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(
            data,
            forKey: WatchPersistedPlaybackSession.storageKey
        )
        lastPersistenceDate = Date()
    }
}

private struct WatchPersistedPlaybackSession: Codable {
    static let storageKey = "melox.watch.playbackSession"

    let queue: [WatchSong]
    let currentIndex: Int
    let progress: TimeInterval
    let repeatMode: String
    let isShuffled: Bool
    let shuffledOrder: [Int]?
}
