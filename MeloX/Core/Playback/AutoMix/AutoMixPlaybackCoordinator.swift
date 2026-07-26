import Foundation

nonisolated struct PreparedAutoMixContext {
    let outgoingSongID: Int
    let incomingSong: Song
    let source: PlaybackSource
    let sourceIsDownloaded: Bool
}

@MainActor
final class AutoMixPlaybackCoordinator {
    var onTransitionBegan:
        ((PreparedAutoMixContext, AutoMixTransitionPlan) -> Void)?
    var onTransitionProgress: ((Double) -> Void)?
    var onTransitionCompleted:
        ((PreparedAutoMixContext) -> Void)?

    private struct Attempt: Equatable {
        let outgoingSongID: Int
        let incomingSongID: Int
    }

    private let api: NeteaseAPI
    private let downloads: DownloadStore
    private let engine: AudioPlaybackEngine
    private let analyzer = AutoMixAudioAnalyzer()

    private var preparationTask: Task<Void, Never>?
    private var preparationGeneration = 0
    private var attempt: Attempt?
    private var preparedContext: PreparedAutoMixContext?
    private var transitionHasBegun = false

    init(
        api: NeteaseAPI,
        downloads: DownloadStore,
        engine: AudioPlaybackEngine
    ) {
        self.api = api
        self.downloads = downloads
        self.engine = engine
        bindEngine()
    }

    func prepareIfNeeded(
        isEnabled: Bool,
        isPlaying: Bool,
        repeatsCurrentSong: Bool,
        outgoingSong: Song?,
        outgoingSource: PlaybackSource?,
        outgoingSourceIsDownloaded: Bool,
        outgoingDuration: TimeInterval,
        outgoingProgress: TimeInterval,
        incomingSong: Song?,
        configuration: AutoMixConfiguration
    ) {
        guard isEnabled,
              isPlaying,
              !repeatsCurrentSong,
              preparationTask == nil,
              preparedContext == nil,
              !engine.hasPreparedAutoMix,
              !transitionHasBegun,
              let outgoingSong,
              let outgoingSource,
              let incomingSong else {
            return
        }

        let nextAttempt = Attempt(
            outgoingSongID: outgoingSong.id,
            incomingSongID: incomingSong.id
        )
        guard attempt != nextAttempt else { return }

        let outgoingDuration = max(
            outgoingDuration,
            TimeInterval(outgoingSong.durationMS) / 1_000
        )
        let remaining = max(
            outgoingDuration - outgoingProgress,
            0
        )
        guard remaining <= configuration.preloadLeadTime else {
            return
        }

        attempt = nextAttempt
        preparationGeneration += 1
        let generation = preparationGeneration
        preparationTask = Task {
            @MainActor [weak self] in
            guard let self else { return }
            defer {
                if generation == self.preparationGeneration {
                    self.preparationTask = nil
                }
            }

            do {
                let incomingSource =
                    try await self.resolvePlaybackSource(
                        for: incomingSong
                    )
                try Task.checkCancellation()

                let analysis = await self.analysis(
                    configuration: configuration,
                    outgoingSong: outgoingSong,
                    outgoingSource: outgoingSource,
                    outgoingSourceIsDownloaded:
                        outgoingSourceIsDownloaded,
                    outgoingDuration: outgoingDuration,
                    incomingSong: incomingSong,
                    incomingSource: incomingSource
                )
                try Task.checkCancellation()

                guard generation == self.preparationGeneration else {
                    return
                }
                guard let plan =
                        AutoMixTransitionPlanner.makePlan(
                            configuration: configuration,
                            outgoingDuration: outgoingDuration,
                            incomingDuration:
                                Self.duration(
                                    of: incomingSong
                                ),
                            analysis: analysis
                        ) else {
                    return
                }

                let context = PreparedAutoMixContext(
                    outgoingSongID: outgoingSong.id,
                    incomingSong: incomingSong,
                    source: incomingSource.source,
                    sourceIsDownloaded:
                        incomingSource.isDownloaded
                )
                self.preparedContext = context
                await self.engine.prepareAutoMix(
                    incomingSource.source,
                    identifier: incomingSong.id,
                    plan: plan
                )
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    func cancel() {
        preparationGeneration += 1
        preparationTask?.cancel()
        preparationTask = nil
        attempt = nil
        preparedContext = nil
        transitionHasBegun = false
        engine.cancelAutoMix()
    }

    private func analysis(
        configuration: AutoMixConfiguration,
        outgoingSong: Song,
        outgoingSource: PlaybackSource,
        outgoingSourceIsDownloaded: Bool,
        outgoingDuration: TimeInterval,
        incomingSong: Song,
        incomingSource: (
            source: PlaybackSource,
            isDownloaded: Bool
        )
    ) async -> AutoMixPairAnalysis? {
        guard configuration.mode == .smart,
              configuration.analyzesStreamingTracks
                || (
                    outgoingSourceIsDownloaded
                        && incomingSource.isDownloaded
                ) else {
            return nil
        }
        return try? await analyzer.analyzePair(
            outgoing: AutoMixAnalysisRequest(
                songID: outgoingSong.id,
                source: outgoingSource,
                duration: outgoingDuration,
                isDownloaded:
                    outgoingSourceIsDownloaded
            ),
            incoming: AutoMixAnalysisRequest(
                songID: incomingSong.id,
                source: incomingSource.source,
                duration: Self.duration(of: incomingSong),
                isDownloaded:
                    incomingSource.isDownloaded
            )
        )
    }

    private func resolvePlaybackSource(
        for song: Song
    ) async throws -> (
        source: PlaybackSource,
        isDownloaded: Bool
    ) {
        if let source = downloads.localPlaybackSource(
            songID: song.id
        ) {
            return (source, true)
        }
        return (
            try await api.playbackSource(id: song.id),
            false
        )
    }

    private func bindEngine() {
        engine.onAutoMixTransitionBegan = {
            [weak self] identifier, plan in
            guard let self,
                  let context = self.preparedContext,
                  context.incomingSong.id
                    == identifier else {
                return
            }
            self.transitionHasBegun = true
            self.onTransitionBegan?(context, plan)
        }
        engine.onAutoMixTransitionProgress = {
            [weak self] progress in
            guard let self,
                  self.transitionHasBegun else {
                return
            }
            self.onTransitionProgress?(
                min(max(progress, 0), 1)
            )
        }
        engine.onAutoMixTransitionCompleted = {
            [weak self] identifier in
            guard let self,
                  let context = self.preparedContext,
                  context.incomingSong.id
                    == identifier else {
                return
            }
            self.preparationTask = nil
            self.attempt = nil
            self.preparedContext = nil
            self.transitionHasBegun = false
            self.onTransitionCompleted?(context)
        }
        engine.onAutoMixPreparationFailed = {
            [weak self] identifier, _ in
            self?.handlePreparationFailure(
                incomingSongID: identifier
            )
        }
    }

    private func handlePreparationFailure(
        incomingSongID: Int
    ) {
        guard let context = preparedContext,
              context.incomingSong.id
                == incomingSongID else {
            return
        }
        preparedContext = nil
        transitionHasBegun = false
        guard context.sourceIsDownloaded else {
            return
        }
        downloads.discardInvalidDownload(
            songID: incomingSongID
        )
        attempt = nil
    }

    private static func duration(
        of song: Song
    ) -> TimeInterval {
        TimeInterval(song.durationMS) / 1_000
    }
}
