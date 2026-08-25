@preconcurrency import AVFoundation

@MainActor
final class AudioPlaybackItemFactory {
    private let equalizerProcessor:
        AudioEqualizerProcessor
    private var spatialAudioMode: SpatialAudioMode

    init(
        equalizerConfiguration:
            AudioEqualizerConfiguration,
        spatialAudioMode: SpatialAudioMode
    ) {
        equalizerProcessor = AudioEqualizerProcessor(
            configuration: equalizerConfiguration
        )
        self.spatialAudioMode = spatialAudioMode
    }

    func makeItem(
        for source: PlaybackSource,
        preferredForwardBufferDuration: TimeInterval,
        autoMixEqualizerState:
            SharedAutoMixEqualizerState
    ) async -> PreparedAudioPlaybackItem {
        NSLog("[MeloXPlayback] makeItem url=%@ format=%@ bitrate=%@", source.url.absoluteString, source.format ?? "nil", source.bitrate.map(String.init) ?? "nil")
        let options: [String: Any]? = source.httpHeaders.isEmpty
            ? nil
            : ["AVURLAssetHTTPHeaderFieldsKey": source.httpHeaders]
        let asset = AVURLAsset(url: source.url, options: options)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration =
            max(
                preferredForwardBufferDuration,
                source.preferredForwardBufferDuration
            )
        AudioSpatializationPolicy.apply(
            spatialAudioMode,
            to: item
        )
        var audioTrackTimeRange: CMTimeRange?
        do {
            if let audioTrack = try await loadAudioTrack(
                from: asset
            ) {
                audioTrackTimeRange = try? await audioTrack.load(
                    .timeRange
                )
                item.audioMix =
                    equalizerProcessor.makeAudioMix(
                        for: audioTrack,
                        autoMixEqualizerState:
                            autoMixEqualizerState
                    )
            }
        } catch {
            NSLog("[MeloXPlayback] asset track load failed url=%@ error=%@", source.url.absoluteString, error.localizedDescription)
        }
        return PreparedAudioPlaybackItem(
            item: item,
            timeline: AudioPlaybackMediaTimeline(
                audioTrackTimeRange: audioTrackTimeRange
            )
        )
    }

    private func loadAudioTrack(
        from asset: AVURLAsset
    ) async throws -> AVAssetTrack? {
        try await withThrowingTaskGroup(
            of: AVAssetTrack?.self
        ) { group in
            group.addTask {
                try await asset.loadTracks(
                    withMediaType: .audio
                ).first
            }
            group.addTask {
                try await Task.sleep(for: .seconds(3))
                throw AudioTrackLoadTimeoutError()
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                return nil
            }
            return result
        }
    }

    func updateEqualizer(
        _ configuration: AudioEqualizerConfiguration
    ) {
        equalizerProcessor.update(
            configuration: configuration
        )
    }

    func updateSpatialAudioMode(_ mode: SpatialAudioMode) {
        spatialAudioMode = mode
    }
}

private struct AudioTrackLoadTimeoutError: LocalizedError {
    var errorDescription: String? {
        "Timed out loading the audio track"
    }
}
