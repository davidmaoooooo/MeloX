import AVFoundation

@MainActor
enum AudioPlaybackSessionConfigurator {
    static func activate() throws {
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            try session.setCategory(.playback, mode: .default)
        }
        if !session.supportsMultichannelContent {
            // Unsupported routes can still play a system-provided downmix.
            try? session.setSupportsMultichannelContent(true)
        }
        try session.setActive(true)
    }
}
