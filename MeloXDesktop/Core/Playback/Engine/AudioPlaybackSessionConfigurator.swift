import AVFoundation

@MainActor
enum AudioPlaybackSessionConfigurator {
    static func activate() throws {
        // macOS owns the output route and audio-session lifetime. Preparing an
        // AVPlayer is sufficient and deliberately avoids iOS AVAudioSession
        // compatibility code in the desktop target.
    }
}
