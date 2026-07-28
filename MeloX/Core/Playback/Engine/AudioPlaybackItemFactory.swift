@preconcurrency import AVFoundation

@MainActor
final class AudioPlaybackItemFactory {
    private let equalizerProcessor:
        AudioEqualizerProcessor

    init(
        equalizerConfiguration:
            AudioEqualizerConfiguration
    ) {
        equalizerProcessor = AudioEqualizerProcessor(
            configuration: equalizerConfiguration
        )
    }

    func makeItem(
        for source: PlaybackSource,
        preferredForwardBufferDuration: TimeInterval,
        autoMixEqualizerState:
            SharedAutoMixEqualizerState
    ) async -> AVPlayerItem {
        let asset = AVURLAsset(url: source.url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration =
            preferredForwardBufferDuration
        do {
            if let audioTrack = try await asset.loadTracks(
                withMediaType: .audio
            ).first {
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
        return item
    }

    func updateEqualizer(
        _ configuration: AudioEqualizerConfiguration
    ) {
        equalizerProcessor.update(
            configuration: configuration
        )
    }
}
