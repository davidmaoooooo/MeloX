@preconcurrency import AVFoundation
import Foundation

enum AudioPlaybackState: Equatable {
    case idle
    case loading
    case paused
    case playing
}

enum AudioPlaybackError: LocalizedError {
    case audioSession(Error)
    case itemFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .audioSession(let error):
            "无法启用音频播放：\(error.localizedDescription)"
        case .itemFailed(let error):
            if let error {
                "音源载入失败：\(error.localizedDescription)"
            } else {
                "音源载入失败，请稍后重试。"
            }
        }
    }
}

@MainActor
final class AudioPlaybackEngine {
    var onStateChanged: ((AudioPlaybackState) -> Void)?
    var onProgressChanged: ((TimeInterval) -> Void)?
    var onDurationChanged: ((TimeInterval) -> Void)?
    var onPlaybackEnded: (() -> Void)?
    var onFailure: ((Error) -> Void)?
    var onAutoMixTransitionBegan:
        ((Int, AutoMixTransitionPlan) -> Void)?
    var onAutoMixTransitionProgress: ((Double) -> Void)?
    var onAutoMixTransitionCompleted: ((Int) -> Void)?
    var onAutoMixPreparationFailed: ((Int, Error) -> Void)?
    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: ((Bool) -> Void)?
    var onOutputDeviceDisconnected: (() -> Void)?

    private(set) var state: AudioPlaybackState = .idle

    private let itemFactory: AudioPlaybackItemFactory
    private let autoMixController:
        AutoMixDeckTransitionController
    private let observedPlayers: [AVPlayer]
    private var timeObservers: [Any?] = [nil, nil]
    private var timeControlObservers:
        [NSKeyValueObservation?] = [nil, nil]
    private var notificationObservers: [NSObjectProtocol] = []
    private var wantsPlayback = false
    private var pendingSeekTime: TimeInterval = 0
    private var seekGeneration = 0
    private var suppressesProgressUpdates = false
    private var didReportCurrentItemFailure = false
    private var loadGeneration = 0

    private var decks: [AudioPlaybackDeck] {
        autoMixController.decks
    }

    private var activeDeckIndex: Int {
        autoMixController.activeDeckIndex
    }

    private var activeDeck: AudioPlaybackDeck {
        autoMixController.activeDeck
    }

    var hasCurrentItem: Bool {
        activeDeck.player.currentItem != nil
    }

    var expectsPlaybackToContinue: Bool {
        wantsPlayback
    }

    var nowPlayingPlayers: [AVPlayer] {
        decks.map(\.player)
    }

    var hasPreparedAutoMix: Bool {
        autoMixController.hasPreparedTransition
    }

    init(equalizerConfiguration: AudioEqualizerConfiguration) {
        let factory = AudioPlaybackItemFactory(
            equalizerConfiguration: equalizerConfiguration
        )
        itemFactory = factory
        let controller =
            AutoMixDeckTransitionController(
                itemFactory: factory
            )
        autoMixController = controller
        observedPlayers = controller.decks.map(\.player)
        bindAutoMixController()
        installPlayerObservers()
        installAudioSessionObservers()
    }

    deinit {
        for (player, observer) in zip(
            observedPlayers,
            timeObservers
        ) {
            if let observer {
                player.removeTimeObserver(observer)
            }
        }
        for observer in notificationObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func load(
        _ source: PlaybackSource,
        startAt: TimeInterval = 0,
        autoplay: Bool
    ) async {
        loadGeneration += 1
        let generation = loadGeneration
        cancelAutoMix()
        wantsPlayback = autoplay
        pendingSeekTime = max(0, startAt)
        seekGeneration += 1
        suppressesProgressUpdates = pendingSeekTime > 0
        didReportCurrentItemFailure = false
        transition(to: .loading)

        let item = await itemFactory.makeItem(
            for: source,
            preferredForwardBufferDuration: 8,
            autoMixEqualizerState:
                activeDeck
                    .autoMixEqualizerState
        )
        guard generation == loadGeneration,
              !Task.isCancelled else {
            return
        }
        activeDeck.replaceCurrentItem(
            with: item,
            identifier: nil
        )
        if autoplay {
            play()
        }
    }

    func unload() {
        loadGeneration += 1
        wantsPlayback = false
        pendingSeekTime = 0
        seekGeneration += 1
        suppressesProgressUpdates = false
        didReportCurrentItemFailure = false
        autoMixController.reset()
        transition(to: .idle)
    }

    func play() {
        guard let item = activeDeck.player.currentItem else {
            return
        }
        wantsPlayback = true
        guard item.status == .readyToPlay,
              !suppressesProgressUpdates else {
            transition(to: .loading)
            return
        }
        do {
            try activateAudioSession()
            activeDeck.player.play()
            autoMixController.resumeIncomingIfNeeded()
            updateStateFromPlayer()
        } catch {
            wantsPlayback = false
            onFailure?(AudioPlaybackError.audioSession(error))
        }
    }

    func pause() {
        wantsPlayback = false
        autoMixController.pauseAll()
        publishProgressIfAvailable()
        updateStateFromPlayer()
    }

    func seek(to seconds: TimeInterval) {
        guard let item = activeDeck.player.currentItem else {
            return
        }
        cancelAutoMix()
        let position = max(0, seconds)
        seekGeneration += 1
        if item.status != .readyToPlay {
            pendingSeekTime = position
            suppressesProgressUpdates = position > 0
            onProgressChanged?(position)
            return
        }

        pendingSeekTime = 0
        suppressesProgressUpdates = false
        activeDeck.player.seek(
            to: CMTime(
                seconds: position,
                preferredTimescale: 600
            ),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        onProgressChanged?(position)
    }

    func setVolume(_ volume: Double) {
        autoMixController.setVolume(volume)
    }

    func setEqualizerConfiguration(
        _ configuration: AudioEqualizerConfiguration
    ) {
        itemFactory.updateEqualizer(configuration)
    }

    func prepareAutoMix(
        _ source: PlaybackSource,
        identifier: Int,
        plan: AutoMixTransitionPlan
    ) async {
        await autoMixController.prepare(
            source,
            identifier: identifier,
            plan: plan
        )
        autoMixController.startIfNeeded(
            wantsPlayback: wantsPlayback
        )
    }

    func cancelAutoMix() {
        autoMixController.cancel(
            wantsPlayback: wantsPlayback
        )
    }

    private func bindAutoMixController() {
        autoMixController.onTransitionBegan = {
            [weak self] identifier, plan in
            self?.onAutoMixTransitionBegan?(
                identifier,
                plan
            )
        }
        autoMixController.onTransitionProgress = {
            [weak self] progress in
            self?.onAutoMixTransitionProgress?(progress)
        }
        autoMixController.onTransitionCompleted = {
            [weak self] identifier in
            self?.onAutoMixTransitionCompleted?(identifier)
        }
        autoMixController.onPreparationFailed = {
            [weak self] identifier, error in
            self?.onAutoMixPreparationFailed?(
                identifier,
                error
            )
        }
        autoMixController.onActiveDeckChanged = {
            [weak self] in
            guard let self else { return }
            self.publishProgressIfAvailable()
            self.publishDurationIfAvailable()
            self.updateStateFromPlayer()
        }
    }

    private func installPlayerObservers() {
        for index in decks.indices {
            let deck = decks[index]
            deck.onItemStatusChanged = {
                [weak self, weak deck] item in
                guard let self, let deck else { return }
                self.handleItemStatusChange(
                    item,
                    on: deck,
                    at: index
                )
            }

            timeObservers[index] =
                deck.player.addPeriodicTimeObserver(
                    forInterval: CMTime(
                        seconds: 0.1,
                        preferredTimescale: 600
                    ),
                    queue: .main
                ) { [weak self] time in
                    MainActor.assumeIsolated {
                        self?.handlePeriodicTime(
                            time,
                            deckIndex: index
                        )
                    }
                }

            timeControlObservers[index] =
                deck.player.observe(
                    \.timeControlStatus,
                    options: [.initial, .new]
                ) { [weak self] _, _ in
                    guard let self else { return }
                    Task { @MainActor [self] in
                        guard index
                                == self.activeDeckIndex else {
                            return
                        }
                        self.updateStateFromPlayer()
                    }
                }
        }

        let center = NotificationCenter.default
        notificationObservers.append(
            center.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.handleItemEnded(
                        notification.object
                    )
                }
            }
        )
        notificationObservers.append(
            center.addObserver(
                forName:
                    .AVPlayerItemFailedToPlayToEndTime,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    let error = notification.userInfo?[
                        AVPlayerItemFailedToPlayToEndTimeErrorKey
                    ] as? Error
                    self?.handleItemFailedToEnd(
                        notification.object,
                        error: error
                    )
                }
            }
        )
    }

    private func handlePeriodicTime(
        _ time: CMTime,
        deckIndex: Int
    ) {
        guard deckIndex == activeDeckIndex else { return }
        let seconds = time.seconds
        if seconds.isFinite,
           !suppressesProgressUpdates {
            onProgressChanged?(max(0, seconds))
        }
        publishDurationIfAvailable()
        autoMixController.startIfNeeded(
            wantsPlayback: wantsPlayback
        )
    }

    private func handleItemStatusChange(
        _ item: AVPlayerItem,
        on deck: AudioPlaybackDeck,
        at deckIndex: Int
    ) {
        guard deck.player.currentItem === item else { return }
        if deckIndex != activeDeckIndex {
            autoMixController.handleStandbyStatus(
                item,
                deckIndex: deckIndex,
                wantsPlayback: wantsPlayback
            )
            return
        }

        switch item.status {
        case .unknown:
            transition(to: .loading)
        case .readyToPlay:
            publishDurationIfAvailable()
            if pendingSeekTime > 0 {
                let position = pendingSeekTime
                pendingSeekTime = 0
                applyInitialSeek(
                    to: position,
                    for: item
                )
                return
            }
            suppressesProgressUpdates = false
            resumePlaybackIfNeeded()
        case .failed:
            fail(with: item.error)
        @unknown default:
            fail(with: item.error)
        }
    }

    private func handleItemEnded(_ object: Any?) {
        guard let item = object as? AVPlayerItem else {
            return
        }
        if autoMixController.finishIfOutgoingEnded(
            item,
            wantsPlayback: wantsPlayback
        ) {
            return
        }
        guard activeDeck.player.currentItem === item else {
            return
        }
        onPlaybackEnded?()
    }

    private func handleItemFailedToEnd(
        _ object: Any?,
        error: Error?
    ) {
        guard let item = object as? AVPlayerItem else {
            return
        }
        if autoMixController.failPreparedIfMatching(
            item,
            error: error
        ) {
            return
        }
        guard activeDeck.player.currentItem === item else {
            return
        }
        fail(with: error)
    }

    private func updateStateFromPlayer() {
        guard let item = activeDeck.player.currentItem else {
            transition(to: .idle)
            return
        }
        if item.status == .failed {
            fail(with: item.error)
            return
        }
        if suppressesProgressUpdates {
            transition(to: .loading)
            return
        }
        switch activeDeck.player.timeControlStatus {
        case .paused:
            transition(
                to:
                    item.status == .unknown
                        ? .loading
                        : .paused
            )
        case .waitingToPlayAtSpecifiedRate:
            transition(to: .loading)
        case .playing:
            transition(to: .playing)
        @unknown default:
            transition(to: .paused)
        }
    }

    private func publishDurationIfAvailable() {
        guard let seconds =
                activeDeck.player.currentItem?
                    .duration.seconds,
              seconds.isFinite,
              seconds > 0 else {
            return
        }
        onDurationChanged?(seconds)
    }

    private func publishProgressIfAvailable() {
        guard !suppressesProgressUpdates else { return }
        let seconds =
            activeDeck.player.currentTime().seconds
        guard seconds.isFinite else { return }
        onProgressChanged?(max(0, seconds))
    }

    private func applyInitialSeek(
        to position: TimeInterval,
        for item: AVPlayerItem
    ) {
        seekGeneration += 1
        let generation = seekGeneration
        activeDeck.player.seek(
            to: CMTime(
                seconds: position,
                preferredTimescale: 600
            ),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        ) { [weak self] finished in
            guard let self else { return }
            Task { @MainActor [self] in
                guard generation == self.seekGeneration,
                      self.activeDeck.player.currentItem
                        === item else {
                    return
                }
                self.suppressesProgressUpdates = false
                if finished {
                    self.onProgressChanged?(position)
                } else {
                    self.publishProgressIfAvailable()
                }
                self.resumePlaybackIfNeeded()
            }
        }
    }

    private func resumePlaybackIfNeeded() {
        if wantsPlayback {
            play()
        } else {
            updateStateFromPlayer()
        }
    }

    private func fail(with error: Error?) {
        guard !didReportCurrentItemFailure else { return }
        didReportCurrentItemFailure = true
        wantsPlayback = false
        autoMixController.pauseAll()
        transition(to: .paused)
        onFailure?(AudioPlaybackError.itemFailed(error))
    }

    private func transition(
        to newState: AudioPlaybackState
    ) {
        guard state != newState else { return }
        state = newState
        onStateChanged?(newState)
    }

    private func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func installAudioSessionObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        notificationObservers.append(
            center.addObserver(
                forName:
                    AVAudioSession.interruptionNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.handleInterruption(notification)
                }
            }
        )
        notificationObservers.append(
            center.addObserver(
                forName:
                    AVAudioSession.routeChangeNotification,
                object: session,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.handleRouteChange(notification)
                }
            }
        )
    }

    private func handleInterruption(
        _ notification: Notification
    ) {
        guard let rawType = notification.userInfo?[
            AVAudioSessionInterruptionTypeKey
        ] as? UInt,
              let type =
                AVAudioSession.InterruptionType(
                    rawValue: rawType
                ) else {
            return
        }
        switch type {
        case .began:
            onInterruptionBegan?()
        case .ended:
            let rawOptions = notification.userInfo?[
                AVAudioSessionInterruptionOptionKey
            ] as? UInt ?? 0
            let shouldResume =
                AVAudioSession.InterruptionOptions(
                    rawValue: rawOptions
                ).contains(.shouldResume)
            onInterruptionEnded?(shouldResume)
        @unknown default:
            break
        }
    }

    private func handleRouteChange(
        _ notification: Notification
    ) {
        guard let rawReason = notification.userInfo?[
            AVAudioSessionRouteChangeReasonKey
        ] as? UInt,
              AVAudioSession.RouteChangeReason(
                rawValue: rawReason
              ) == .oldDeviceUnavailable else {
            return
        }
        pause()
        onOutputDeviceDisconnected?()
    }
}
