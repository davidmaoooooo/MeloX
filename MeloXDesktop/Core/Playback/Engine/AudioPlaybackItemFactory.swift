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
        let asset = AVURLAsset(url: source.url)
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
            if let audioTrack = try await asset.loadTracks(
                withMediaType: .audio
            ).first {
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
            // AVPlayerItem reports an actionable error if playback fails.
        }
        return PreparedAudioPlaybackItem(
            item: item,
            timeline: AudioPlaybackMediaTimeline(
                audioTrackTimeRange: audioTrackTimeRange
            )
        )
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
