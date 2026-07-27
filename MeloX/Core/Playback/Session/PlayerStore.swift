import Foundation
import Observation

private enum LyricsLiveActivityPublication: Equatable {
    case inactive
    case content(LyricsLiveActivityPublicationSignature)
}

private struct LyricsLiveActivityPublicationSignature: Equatable {
    let songID: Int
    let currentLyricID: LyricLine.ID?
    let nextLyricID: LyricLine.ID?
    let isPlaying: Bool
    let title: String
    let subtitle: String
    let compactText: String
    let compactScrollDistancePoints: Int
    let artworkURL: URL?
    let preferences: LyricsLiveActivityPreferences
    let durationMilliseconds: Int
}

@MainActor
@Observable
final class PlayerStore {
    private(set) var currentSong: Song?
    private(set) var isPlaying = false
    private(set) var progress: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var seekRevision = 0
    private(set) var isLoading = false
    private(set) var playbackIssue: PlaybackIssue?
    private(set) var volume: Double = 1
    private(set) var repeatMode: RepeatMode = .off
    private(set) var isAutoplayEnabled = false
    private(set) var isAutoMixEnabled = false
    private(set) var autoMixTransitionProgress: Double?
    private(set) var autoMixTransitionKind:
        AutoMixTransitionKind?
    private(set) var autoMixIncomingSongName: String?
    private(set) var queueModeIndicator:
        QueuePlaybackModeIndicator?

    private var playbackQueue = PlaybackQueue()

    var queue: [Song] { playbackQueue.songs }
    var currentIndex: Int { playbackQueue.currentIndex }
    var isShuffled: Bool { playbackQueue.isShuffled }
    var unplayedQueueIndices: [Int] {
        playbackQueue.upcomingIndices(wraps: false)
    }
    var upcomingQueueIndices: [Int] {
        playbackQueue.upcomingIndices(
            wraps: repeatMode == .all
        )
    }
    var queueModeBadgeSystemImage: String? {
        queueModeIndicator?.systemImage
    }
    var isAutoMixTransitioning: Bool {
        autoMixTransitionProgress != nil
    }
    var canPlayNext: Bool {
        isAutoplayEnabled
            || (
                queue.count > 1
                    && playbackQueue.canMove(
                        by: 1,
                        wraps: repeatMode == .all
                    )
            )
    }

    @ObservationIgnored
    private let api: NeteaseAPI

    @ObservationIgnored
    private let settings: AppSettings

    @ObservationIgnored
    private let downloads: DownloadStore

    @ObservationIgnored
    private let engine: AudioPlaybackEngine

    @ObservationIgnored
    private let autoMixCoordinator:
        AutoMixPlaybackCoordinator

    @ObservationIgnored
    private let nowPlayingSession: NowPlayingSession

    @ObservationIgnored
    private let lyricsLiveActivityController:
        LyricsLiveActivityController

    @ObservationIgnored
    private let persistence: PlaybackPersistence

    @ObservationIgnored
    private let historyRecorder: PlaybackHistoryRecorder

    @ObservationIgnored
    private var loadGeneration = 0

    @ObservationIgnored
    private var isResolvingSource = false

    @ObservationIgnored
    private var hasRestoredPlayback = false

    @ObservationIgnored
    private var shouldResumeAfterInterruption = false

    @ObservationIgnored
    private var lastPersistedSecond = -1

    @ObservationIgnored
    private var lastProgressUpdateDate = Date()

    @ObservationIgnored
    private var historySourceID: Int?

    @ObservationIgnored
    private var hasRecordedCurrentStart = false

    @ObservationIgnored
    private var isUsingDownloadedSource = false

    @ObservationIgnored
    private var currentLoadShouldAutoplay = false

    @ObservationIgnored
    private var currentPlaybackSource: PlaybackSource?

    @ObservationIgnored
    private var isLoadingAutoplayRecommendations = false

    @ObservationIgnored
    private var nowPlayingLyricsSongID: Int?

    @ObservationIgnored
    private var nowPlayingLyrics: [LyricLine] = []

    @ObservationIgnored
    private var publishedNowPlayingLyricID: LyricLine.ID?

    @ObservationIgnored
    private var publishedLyricsLiveActivity:
        LyricsLiveActivityPublication?

    init(
        api: NeteaseAPI,
        settings: AppSettings,
        downloads: DownloadStore,
        persistence: PlaybackPersistence? = nil,
        onPlaybackRecorded: @escaping (Song) -> Void = { _ in }
    ) {
        self.api = api
        self.settings = settings
        self.downloads = downloads
        self.persistence = persistence ?? PlaybackPersistence()
        historyRecorder = PlaybackHistoryRecorder(
            api: api,
            settings: settings,
            onRecorded: onPlaybackRecorded
        )
        let engine = AudioPlaybackEngine(
            equalizerConfiguration: settings.equalizer.configuration
        )
        self.engine = engine
        autoMixCoordinator = AutoMixPlaybackCoordinator(
            api: api,
            downloads: downloads,
            engine: engine
        )
        nowPlayingSession = NowPlayingSession(
            players: engine.nowPlayingPlayers
        )
        lyricsLiveActivityController = LyricsLiveActivityController()
        bindEngine()
        bindAutoMixCoordinator()
        bindRemoteCommands()
        applyVolumeControlMode()
    }

    func restore() async {
        guard !hasRestoredPlayback else { return }
        hasRestoredPlayback = true
        guard let snapshot = persistence.load(), !snapshot.queue.isEmpty else {
            lyricsLiveActivityController.synchronize(with: nil)
            return
        }

        playbackQueue.restore(
            songs: snapshot.queue,
            currentIndex: snapshot.currentIndex,
            isShuffled: snapshot.isShuffled,
            shuffledOrder: snapshot.shuffledOrder
        )
        currentSong = playbackQueue.currentSong
        progress = max(snapshot.progress, 0)
        lastProgressUpdateDate = Date()
        duration = TimeInterval(currentSong?.durationMS ?? 0) / 1_000
        repeatMode = RepeatMode(rawValue: snapshot.repeatMode) ?? .off
        volume = min(max(snapshot.volume, 0), 1)
        historySourceID = snapshot.historySourceID
        isAutoplayEnabled = snapshot.autoplayEnabled ?? false
        isAutoMixEnabled = snapshot.autoMixEnabled ?? false
        updateQueueModeIndicator(
            preferred: snapshot.queueModeIndicator.flatMap(
                QueuePlaybackModeIndicator.init(rawValue:)
            )
        )
        applyVolumeControlMode()

        await loadCurrentSong(
            autoplay: false,
            startAt: progress
        )
    }

    func play(
        _ song: Song,
        in songs: [Song]? = nil,
        sourceID: Int? = nil
    ) async {
        recordCurrentPlayback()
        if let songs, !songs.isEmpty {
            let index = songs.firstIndex(where: { $0.id == song.id }) ?? 0
            playbackQueue.replace(with: songs, startingAt: index)
            historySourceID = sourceID
        } else if let existingIndex = queue.firstIndex(where: { $0.id == song.id }) {
            _ = playbackQueue.select(index: existingIndex)
        } else {
            playbackQueue.replace(with: [song], startingAt: 0)
            historySourceID = sourceID
        }
        hasRecordedCurrentStart = false
        await loadCurrentSong(autoplay: true)
    }

    func playAll(_ songs: [Song], sourceID: Int? = nil) async {
        guard !songs.isEmpty else { return }
        recordCurrentPlayback()
        playbackQueue.replace(with: songs, startingAt: 0)
        historySourceID = sourceID
        hasRecordedCurrentStart = false
        await loadCurrentSong(autoplay: true)
    }

    func togglePlayback() {
        guard currentSong != nil else { return }
        if engine.hasCurrentItem {
            if isPlaying {
                engine.pause()
                persistSnapshot()
            } else {
                playbackIssue = nil
                engine.play()
            }
        } else {
            Task { @MainActor [weak self] in
                await self?.retry()
            }
        }
    }

    func retry() async {
        guard currentSong != nil else { return }
        await loadCurrentSong(autoplay: true)
    }

    func dismissPlaybackIssue() {
        playbackIssue = nil
    }

    func reloadCurrentSongForQualityChange() async {
        guard currentSong != nil else { return }
        let shouldAutoplay = isPlaying
        let resumePosition = estimatedProgress()
        await loadCurrentSong(
            autoplay: shouldAutoplay,
            startAt: resumePosition
        )
    }

    func next() async {
        await moveToNext(recordingCurrentPlayback: true)
    }

    private func moveToNext(recordingCurrentPlayback: Bool) async {
        guard !queue.isEmpty else { return }
        if !playbackQueue.canMove(
            by: 1,
            wraps: repeatMode == .all
        ), isAutoplayEnabled {
            await appendAutoplayRecommendationsIfNeeded()
        }
        if recordingCurrentPlayback {
            recordCurrentPlayback()
        }
        guard playbackQueue.canMove(
            by: 1,
            wraps: repeatMode == .all
        ) else {
            stopAtQueueEnd()
            return
        }
        guard playbackQueue.move(by: 1, wraps: repeatMode == .all) else {
            stopAtQueueEnd()
            return
        }
        hasRecordedCurrentStart = false
        await loadCurrentSong(autoplay: true)
    }

    func previous() async {
        guard !queue.isEmpty else { return }
        if settings.previousRestartsCurrentSong, progress > 5 {
            seek(to: 0)
            return
        }
        guard playbackQueue.canMove(by: -1, wraps: repeatMode == .all) else {
            seek(to: 0)
            return
        }
        recordCurrentPlayback()
        guard playbackQueue.move(by: -1, wraps: repeatMode == .all) else { return }
        hasRecordedCurrentStart = false
        await loadCurrentSong(autoplay: true)
    }

    func playFromQueue(at index: Int) async {
        guard queue.indices.contains(index) else { return }
        recordCurrentPlayback()
        guard playbackQueue.select(index: index) else { return }
        hasRecordedCurrentStart = false
        await loadCurrentSong(autoplay: true)
    }

    func addToPlaybackQueue(_ song: Song) {
        cancelAutoMixPreparation()
        playbackQueue.append(song)
        persistSnapshot()
        prepareAutoMixIfNeeded()
    }

    func moveUpcomingQueueItems(
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) {
        cancelAutoMixPreparation()
        playbackQueue.moveUpcomingSongs(
            fromOffsets: source,
            toOffset: destination,
            wraps: repeatMode == .all
        )
        persistSnapshot()
        prepareAutoMixIfNeeded()
    }

    func seek(to seconds: TimeInterval) {
        let maximum = duration > 0 ? duration : TimeInterval(currentSong?.durationMS ?? 0) / 1_000
        let clamped = max(0, min(seconds, maximum))
        cancelAutoMixPreparation()
        engine.seek(to: clamped)
        progress = clamped
        seekRevision += 1
        lastProgressUpdateDate = Date()
        updateNowPlayingState(
            forceNowPlayingLyrics: true,
            forceLyricsLiveActivity: true
        )
        persistSnapshot()
    }

    func setNowPlayingLyrics(_ lyrics: [LyricLine], for songID: Int?) {
        guard let songID, currentSong?.id == songID else { return }
        nowPlayingLyricsSongID = songID
        nowPlayingLyrics = lyrics
        updateNowPlayingLyricMetadata()
        updateLyricsLiveActivity()
    }

    func applySystemNowPlayingLyricsPreference() {
        updateNowPlayingLyricMetadata(force: true)
    }

    func applyLyricsLiveActivityPreference() {
        updateLyricsLiveActivity(force: true)
    }

    func refreshLyricsLiveActivity() {
        updateLyricsLiveActivity(force: true)
    }

    func estimatedProgress(at date: Date = Date()) -> TimeInterval {
        guard isPlaying else { return progress }
        let elapsed = max(date.timeIntervalSince(lastProgressUpdateDate), 0)
        let maximum = duration > 0 ? duration : TimeInterval(currentSong?.durationMS ?? 0) / 1_000
        let estimated = progress + elapsed
        return maximum > 0 ? min(estimated, maximum) : estimated
    }

    func setVolume(_ value: Double) {
        volume = min(max(value, 0), 1)
        applyVolumeControlMode()
        persistSnapshot()
    }

    func applyVolumeControlMode() {
        let effectiveVolume = settings.playerVolumeControlMode == .independent
            ? volume
            : 1
        engine.setVolume(effectiveVolume)
    }

    func applyEqualizerSettings() {
        engine.setEqualizerConfiguration(settings.equalizer.configuration)
    }

    func cycleRepeatMode() {
        cancelAutoMixPreparation()
        switch repeatMode {
        case .off:
            repeatMode = .all
            queueModeIndicator = .repeatAll
        case .all:
            repeatMode = .one
            queueModeIndicator = .repeatOne
        case .one:
            repeatMode = .off
            updateQueueModeIndicator()
        }
        persistSnapshot()
    }

    func toggleShuffle() {
        cancelAutoMixPreparation()
        playbackQueue.toggleShuffle()
        if isShuffled {
            queueModeIndicator = .shuffle
        } else {
            updateQueueModeIndicator()
        }
        persistSnapshot()
    }

    func toggleAutoplay() {
        isAutoplayEnabled.toggle()
        if isAutoplayEnabled {
            queueModeIndicator = .autoplay
        } else {
            updateQueueModeIndicator()
        }
        persistSnapshot()
        guard isAutoplayEnabled else { return }

        Task { @MainActor [weak self] in
            await self?.appendAutoplayRecommendationsIfNeeded()
        }
    }

    func toggleAutoMix() {
        setAutoMixEnabled(!isAutoMixEnabled)
    }

    func setAutoMixEnabled(_ isEnabled: Bool) {
        guard isAutoMixEnabled != isEnabled else { return }
        isAutoMixEnabled = isEnabled
        if isEnabled {
            queueModeIndicator = .autoMix
        } else {
            updateQueueModeIndicator()
            cancelAutoMixPreparation()
        }
        persistSnapshot()
        if isEnabled {
            prepareAutoMixIfNeeded()
        }
    }

    func applyAutoMixSettings() {
        cancelAutoMixPreparation()
        persistSnapshot()
        guard isAutoMixEnabled else { return }
        prepareAutoMixIfNeeded()
    }

    private func loadCurrentSong(
        autoplay: Bool,
        startAt: TimeInterval = 0
    ) async {
        guard let song = playbackQueue.currentSong else { return }
        cancelAutoMixPreparation()
        loadGeneration += 1
        let generation = loadGeneration
        currentSong = song
        progress = max(0, startAt)
        lastProgressUpdateDate = Date()
        duration = TimeInterval(song.durationMS) / 1_000
        isResolvingSource = true
        isLoading = true
        isPlaying = false
        isUsingDownloadedSource = false
        currentPlaybackSource = nil
        currentLoadShouldAutoplay = autoplay
        playbackIssue = nil
        if nowPlayingLyricsSongID != song.id {
            nowPlayingLyricsSongID = nil
            nowPlayingLyrics = []
            publishedNowPlayingLyricID = nil
        }
        engine.unload()
        nowPlayingSession.setSong(
            song,
            duration: duration,
            queueIndex: currentIndex,
            queueCount: queue.count,
            lyricsDisplaySettings: nowPlayingLyricsDisplaySettings
        )
        updateNowPlayingState()
        persistSnapshot()

        do {
            let source: PlaybackSource
            if let downloadedSource = downloads.localPlaybackSource(songID: song.id) {
                source = downloadedSource
                isUsingDownloadedSource = true
            } else {
                source = try await api.playbackSource(id: song.id)
            }
            guard generation == loadGeneration, currentSong?.id == song.id else { return }
            isResolvingSource = false
            currentPlaybackSource = source
            await engine.load(
                source,
                startAt: startAt,
                autoplay: autoplay
            )
        } catch is CancellationError {
            return
        } catch {
            guard generation == loadGeneration, currentSong?.id == song.id else { return }
            isResolvingSource = false
            isLoading = false
            isPlaying = false
            playbackIssue = PlaybackIssue(song: song, error: error)
            updateNowPlayingState()
            persistSnapshot()
        }
    }

    private func handlePlaybackEnded() async {
        recordCurrentPlayback(completed: true)
        if repeatMode == .one {
            hasRecordedCurrentStart = false
            seek(to: 0)
            engine.play()
            return
        }
        await moveToNext(recordingCurrentPlayback: false)
    }

    private func handleEngineFailure(_ error: Error) async {
        if let playbackError = error as? AudioPlaybackError,
           case .itemFailed = playbackError,
           isUsingDownloadedSource,
           let song = currentSong {
            let resumePosition = progress
            let shouldAutoplay = currentLoadShouldAutoplay
            isUsingDownloadedSource = false
            downloads.discardInvalidDownload(songID: song.id)
            await loadCurrentSong(
                autoplay: shouldAutoplay,
                startAt: resumePosition
            )
            return
        }

        if let song = currentSong {
            playbackIssue = PlaybackIssue(song: song, error: error)
        }
        isLoading = false
        isPlaying = false
        updateNowPlayingState()

        if let playbackError = error as? AudioPlaybackError,
           case .itemFailed = playbackError {
            engine.unload()
        }
        persistSnapshot()
    }

    private func stopAtQueueEnd() {
        cancelAutoMixPreparation()
        engine.pause()
        engine.seek(to: 0)
        progress = 0
        lastProgressUpdateDate = Date()
        isPlaying = false
        isLoading = false
        updateNowPlayingState()
        persistSnapshot()
    }

    private func bindEngine() {
        engine.onStateChanged = { [weak self] state in
            guard let self else { return }
            switch state {
            case .idle:
                self.isPlaying = false
                if !self.isResolvingSource {
                    self.isLoading = false
                }
            case .loading:
                self.isPlaying = false
                self.isLoading = true
            case .paused:
                self.isPlaying = false
                if self.engine.expectsPlaybackToContinue {
                    self.isLoading = true
                    self.currentLoadShouldAutoplay = true
                } else {
                    self.isLoading = false
                }
            case .playing:
                self.isPlaying = true
                self.isLoading = false
                self.currentLoadShouldAutoplay = true
                self.playbackIssue = nil
                self.recordCurrentPlaybackStartIfNeeded()
                self.prepareAutoMixIfNeeded()
            }
            self.lastProgressUpdateDate = Date()
            self.updateNowPlayingState()
        }
        engine.onProgressChanged = { [weak self] value in
            guard let self else { return }
            self.progress = value
            self.lastProgressUpdateDate = Date()
            self.updateNowPlayingLyricMetadata()
            self.updateLyricsLiveActivity()
            let second = Int(value)
            if second != self.lastPersistedSecond {
                self.lastPersistedSecond = second
                self.persistSnapshot()
            }
            self.prepareAutoMixIfNeeded()
        }
        engine.onDurationChanged = { [weak self] value in
            guard let self else { return }
            self.duration = value
            self.updateNowPlayingState()
        }
        engine.onPlaybackEnded = { [weak self] in
            Task { @MainActor in
                await self?.handlePlaybackEnded()
            }
        }
        engine.onFailure = { [weak self] error in
            Task { @MainActor in
                await self?.handleEngineFailure(error)
            }
        }
        engine.onInterruptionBegan = { [weak self] in
            guard let self else { return }
            self.shouldResumeAfterInterruption = self.isPlaying
            self.engine.pause()
        }
        engine.onInterruptionEnded = { [weak self] shouldResume in
            guard let self else { return }
            if shouldResume, self.shouldResumeAfterInterruption {
                self.engine.play()
            }
            self.shouldResumeAfterInterruption = false
        }
        engine.onOutputDeviceDisconnected = { [weak self] in
            self?.shouldResumeAfterInterruption = false
        }
    }

    private func bindAutoMixCoordinator() {
        autoMixCoordinator.onTransitionBegan = {
            [weak self] context, plan in
            guard let self,
                  context.outgoingSongID
                    == self.currentSong?.id else {
                return
            }
            self.autoMixTransitionKind = plan.kind
            self.autoMixIncomingSongName =
                context.incomingSong.name
            self.autoMixTransitionProgress = 0
        }
        autoMixCoordinator.onTransitionProgress = {
            [weak self] progress in
            guard let self,
                  self.autoMixTransitionProgress != nil else {
                return
            }
            self.autoMixTransitionProgress = progress
        }
        autoMixCoordinator.onTransitionCompleted = {
            [weak self] context in
            self?.completeAutoMixTransition(
                context: context
            )
        }
    }

    private func bindRemoteCommands() {
        nowPlayingSession.onPlay = { [weak self] in
            guard let self else { return }
            if self.engine.hasCurrentItem {
                self.engine.play()
            } else {
                Task { @MainActor in await self.retry() }
            }
        }
        nowPlayingSession.onPause = { [weak self] in
            self?.engine.pause()
        }
        nowPlayingSession.onNext = { [weak self] in
            Task { @MainActor in await self?.next() }
        }
        nowPlayingSession.onPrevious = { [weak self] in
            Task { @MainActor in await self?.previous() }
        }
        nowPlayingSession.onSeek = { [weak self] position in
            self?.seek(to: position)
        }
    }

    private func updateNowPlayingState(
        forceNowPlayingLyrics: Bool = false,
        forceLyricsLiveActivity: Bool = false
    ) {
        updateNowPlayingLyricMetadata(
            force: forceNowPlayingLyrics
        )
        updateLyricsLiveActivity(force: forceLyricsLiveActivity)
        nowPlayingSession.updatePlayback(
            position: progress,
            duration: duration,
            isPlaying: isPlaying
        )
    }

    private func updateNowPlayingLyricMetadata(
        force: Bool = false
    ) {
        guard let song = currentSong else { return }
        let lyrics = nowPlayingLyricsSongID == song.id
            ? nowPlayingLyrics
            : []
        let highlightedLyricID = settings.systemNowPlayingLyricsEnabled
            ? LyricPlaybackTimeline.position(
                at: estimatedProgress() + settings.lyricsAdvanceTime,
                in: lyrics
            ).highlightedLyricID
            : nil
        guard force
                || highlightedLyricID
                    != publishedNowPlayingLyricID else {
            return
        }

        let currentLyric = highlightedLyricID.flatMap { lyricID in
            lyrics.first(where: { $0.id == lyricID })
        }
        publishedNowPlayingLyricID = highlightedLyricID
        nowPlayingSession.updateCurrentLyric(
            currentLyric?.text,
            for: song,
            lyricsDisplaySettings: nowPlayingLyricsDisplaySettings
        )
    }

    private func updateLyricsLiveActivity(force: Bool = false) {
        guard let song = currentSong,
              shouldPresentLyricsLiveActivity else {
            publishLyricsLiveActivity(
                .inactive,
                snapshot: nil,
                force: force
            )
            return
        }
        guard settings.lyricsLiveActivityEnabled else {
            publishLyricsLiveActivity(
                .inactive,
                snapshot: nil,
                force: force
            )
            return
        }

        let lyrics = nowPlayingLyricsSongID == song.id
            ? nowPlayingLyrics
            : []
        let adjustedProgress =
            estimatedProgress() + settings.lyricsAdvanceTime
        let position = LyricPlaybackTimeline.position(
            at: adjustedProgress,
            in: lyrics
        )
        let currentLyricIndex = position.highlightedLyricID.flatMap {
            lyricID in
            lyrics.firstIndex(where: { $0.id == lyricID })
        }
        let currentLyric = currentLyricIndex.map { lyrics[$0] }
        let nextLyric: LyricLine? = if let currentLyricIndex {
            lyrics.indices.contains(currentLyricIndex + 1)
                ? lyrics[currentLyricIndex + 1]
                : nil
        } else {
            lyrics.first
        }
        let preferences = LyricsLiveActivityPreferences(
            settings: settings
        )
        let displayText = LyricsLiveActivityFormatter.text(
            songTitle: song.name,
            songArtist: song.artistText,
            currentLyric: currentLyric?.text,
            preferences: preferences
        )
        let artworkURL = preferences.showsArtwork
            ? song.album?.artworkURL
            : nil
        let compactScrollDistance =
            lyricsLiveActivityCompactScrollDistance(
                text: displayText.compact,
                currentLyric: currentLyric,
                nextTransitionTime: position.nextTransitionTime,
                adjustedProgress: adjustedProgress,
                preferences: preferences
            )
        let signature = LyricsLiveActivityPublicationSignature(
            songID: song.id,
            currentLyricID: currentLyric?.id,
            nextLyricID: preferences.showsNextLyric
                ? nextLyric?.id
                : nil,
            isPlaying: isPlaying,
            title: displayText.title,
            subtitle: displayText.subtitle,
            compactText: displayText.compact,
            compactScrollDistancePoints:
                Int(compactScrollDistance.rounded()),
            artworkURL: artworkURL,
            preferences: preferences,
            durationMilliseconds: Int((duration * 1_000).rounded())
        )
        let snapshot = LyricsLiveActivitySnapshot(
            songID: song.id,
            title: displayText.title,
            subtitle: displayText.subtitle,
            compactText: displayText.compact,
            compactScrollDistance: compactScrollDistance,
            nextLyric: preferences.showsNextLyric
                ? nextLyric?.text
                : nil,
            artworkURL: artworkURL,
            presentation: preferences.presentation,
            isPlaying: isPlaying,
            playbackPosition: estimatedProgress(),
            duration: duration,
            staleDate: nil
        )
        publishLyricsLiveActivity(
            .content(signature),
            snapshot: snapshot,
            force: force
        )
    }

    private var shouldPresentLyricsLiveActivity: Bool {
        isPlaying || (isLoading && currentLoadShouldAutoplay)
    }

    private func publishLyricsLiveActivity(
        _ publication: LyricsLiveActivityPublication,
        snapshot: LyricsLiveActivitySnapshot?,
        force: Bool
    ) {
        guard force || publication != publishedLyricsLiveActivity else {
            return
        }
        publishedLyricsLiveActivity = publication
        lyricsLiveActivityController.synchronize(with: snapshot)
    }

    private func lyricsLiveActivityCompactScrollDistance(
        text: String,
        currentLyric: LyricLine?,
        nextTransitionTime: TimeInterval?,
        adjustedProgress: TimeInterval,
        preferences: LyricsLiveActivityPreferences
    ) -> Double {
        let pointSize = preferences.compactTextSize.pointSize
        guard preferences.scrollsCompactText,
              LyricsLiveActivityCompactLayout.requiresScrolling(
                text: text,
                pointSize: pointSize
              )
        else {
            return 0
        }

        guard let currentLyric else { return 0 }
        let startTime = currentLyric.time
        let elapsed = max(adjustedProgress - startTime, 0)
        let scrollDistance =
            LyricsLiveActivityCompactLayout
                .scrollDistanceToRevealEnd(
                    text: text,
                    pointSize: pointSize
                )
        guard scrollDistance > 0 else { return 0 }

        let configuredPause = max(
            preferences.scrollPause,
            0
        )
        let lineEndTime = nextTransitionTime
            ?? currentLyric.duration.map {
                currentLyric.time + $0
            }
        let timing: (pause: TimeInterval, speed: Double) = {
            guard let lineEndTime else {
                return (
                    configuredPause,
                    max(preferences.scrollSpeed, 1)
                )
            }

            let lineDuration = max(
                lineEndTime - currentLyric.time,
                0.25
            )
            let pause = min(
                configuredPause,
                lineDuration * 0.2
            )
            // ActivityKit updates are delivered asynchronously. Keep the
            // completed tail visible long enough for the last page to arrive
            // before the lyric transition.
            let endingHold = min(
                1.25,
                lineDuration * 0.25
            )
            let availableTravelTime = max(
                lineDuration - pause - endingHold,
                0.25
            )
            let requiredSpeed =
                scrollDistance / availableTravelTime
            return (
                pause,
                max(
                    max(preferences.scrollSpeed, requiredSpeed),
                    1
                )
            )
        }()

        let travelDistance = min(
            max(elapsed - timing.pause, 0) * timing.speed,
            scrollDistance
        )
        return travelDistance.rounded()
    }

    private var nowPlayingLyricsDisplaySettings:
        NowPlayingLyricsDisplaySettings {
        NowPlayingLyricsDisplaySettings(
            isEnabled: settings.systemNowPlayingLyricsEnabled,
            titleFormat: settings.systemNowPlayingLyricsTitleFormat,
            subtitleFormat: settings.systemNowPlayingLyricsSubtitleFormat
        )
    }

    private func recordCurrentPlayback(completed: Bool = false) {
        guard hasRecordedCurrentStart, let currentSong else { return }
        historyRecorder.recordPlaybackDuration(
            song: currentSong,
            sourceID: historySourceID,
            playbackTime: estimatedProgress(),
            completed: completed
        )
    }

    private func recordCurrentPlaybackStartIfNeeded() {
        guard !hasRecordedCurrentStart, let currentSong else { return }
        hasRecordedCurrentStart = true
        historyRecorder.recordRecentPlayback(
            song: currentSong,
            sourceID: historySourceID
        )
        downloads.recordPlayback(currentSong)
    }

    private func persistSnapshot() {
        guard !queue.isEmpty else {
            persistence.clear()
            return
        }
        persistence.save(
            PlaybackSnapshot(
                queue: queue,
                currentIndex: currentIndex,
                progress: progress,
                repeatMode: repeatMode.rawValue,
                isShuffled: isShuffled,
                shuffledOrder: playbackQueue.persistedShuffleOrder,
                volume: volume,
                historySourceID: historySourceID,
                autoplayEnabled: isAutoplayEnabled,
                autoMixEnabled: isAutoMixEnabled,
                queueModeIndicator: queueModeIndicator?.rawValue
            )
        )
    }

    private func updateQueueModeIndicator(
        preferred: QueuePlaybackModeIndicator? = nil
    ) {
        if let preferred, isModeActive(preferred) {
            queueModeIndicator = preferred
            return
        }

        if repeatMode == .one {
            queueModeIndicator = .repeatOne
        } else if repeatMode == .all {
            queueModeIndicator = .repeatAll
        } else if isShuffled {
            queueModeIndicator = .shuffle
        } else if isAutoplayEnabled {
            queueModeIndicator = .autoplay
        } else if isAutoMixEnabled {
            queueModeIndicator = .autoMix
        } else {
            queueModeIndicator = nil
        }
    }

    private func isModeActive(
        _ mode: QueuePlaybackModeIndicator
    ) -> Bool {
        switch mode {
        case .shuffle:
            isShuffled
        case .repeatAll:
            repeatMode == .all
        case .repeatOne:
            repeatMode == .one
        case .autoplay:
            isAutoplayEnabled
        case .autoMix:
            isAutoMixEnabled
        }
    }

    private func appendAutoplayRecommendationsIfNeeded() async {
        guard isAutoplayEnabled,
              !isLoadingAutoplayRecommendations,
              playbackQueue.upcomingIndices(wraps: false).isEmpty,
              let currentSong else {
            return
        }

        isLoadingAutoplayRecommendations = true
        defer { isLoadingAutoplayRecommendations = false }

        do {
            let recommendations = try await api.similarSongs(
                id: currentSong.id
            )
            guard isAutoplayEnabled else { return }
            let existingSongIDs = Set(queue.map(\.id))
            let newSongs = recommendations.filter {
                !existingSongIDs.contains($0.id)
            }
            playbackQueue.append(
                contentsOf: Array(newSongs.prefix(25))
            )
            persistSnapshot()
        } catch is CancellationError {
            return
        } catch {
            return
        }
    }

    private func prepareAutoMixIfNeeded() {
        let nextSong = upcomingQueueIndices.first.flatMap {
            queue.indices.contains($0)
                ? queue[$0]
                : nil
        }
        autoMixCoordinator.prepareIfNeeded(
            isEnabled: isAutoMixEnabled,
            isPlaying: isPlaying,
            repeatsCurrentSong: repeatMode == .one,
            outgoingSong: currentSong,
            outgoingSource: currentPlaybackSource,
            outgoingSourceIsDownloaded:
                isUsingDownloadedSource,
            outgoingDuration: duration,
            outgoingProgress: estimatedProgress(),
            incomingSong: nextSong,
            configuration: settings.autoMix.configuration
        )
    }

    private func cancelAutoMixPreparation() {
        autoMixTransitionProgress = nil
        autoMixTransitionKind = nil
        autoMixIncomingSongName = nil
        autoMixCoordinator.cancel()
    }

    private func completeAutoMixTransition(
        context: PreparedAutoMixContext
    ) {
        guard context.outgoingSongID == currentSong?.id else {
            cancelAutoMixPreparation()
            return
        }

        recordCurrentPlayback(completed: true)
        guard playbackQueue.move(
            by: 1,
            wraps: repeatMode == .all
        ),
              playbackQueue.currentSong?.id
                == context.incomingSong.id else {
            cancelAutoMixPreparation()
            return
        }

        loadGeneration += 1
        currentSong = context.incomingSong
        currentPlaybackSource = context.source
        isUsingDownloadedSource =
            context.sourceIsDownloaded
        currentLoadShouldAutoplay = true
        isResolvingSource = false
        isLoading = engine.state == .loading
        isPlaying = engine.state == .playing
        playbackIssue = nil
        hasRecordedCurrentStart = false
        lastProgressUpdateDate = Date()
        lastPersistedSecond = Int(progress)
        nowPlayingLyricsSongID = nil
        nowPlayingLyrics = []
        publishedNowPlayingLyricID = nil
        publishedLyricsLiveActivity = nil

        autoMixTransitionProgress = nil
        autoMixTransitionKind = nil
        autoMixIncomingSongName = nil

        nowPlayingSession.setSong(
            context.incomingSong,
            duration: duration,
            queueIndex: currentIndex,
            queueCount: queue.count,
            lyricsDisplaySettings:
                nowPlayingLyricsDisplaySettings
        )
        if isPlaying {
            recordCurrentPlaybackStartIfNeeded()
        }
        updateNowPlayingState(
            forceNowPlayingLyrics: true,
            forceLyricsLiveActivity: true
        )
        persistSnapshot()
        prepareAutoMixIfNeeded()
    }
}
