@preconcurrency import AVFoundation

@MainActor
enum AudioSpatializationPolicy {
    static func apply(
        _ mode: SpatialAudioMode,
        to item: AVPlayerItem
    ) {
        item.allowedAudioSpatializationFormats = allowedFormats(
            for: mode
        )
    }

    private static func allowedFormats(
        for mode: SpatialAudioMode
    ) -> AVAudioSpatializationFormats {
        switch mode {
        case .automatic:
            .monoStereoAndMultichannel
        case .multichannelOnly:
            .multichannel
        case .disabled:
            []
        }
    }
}
