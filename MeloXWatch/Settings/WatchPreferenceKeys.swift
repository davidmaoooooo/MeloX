import Foundation

enum WatchPreferenceKey {
    static let streamingQuality = "melox.watch.streamingQuality"
    static let autoPlaySelection = "melox.watch.autoPlaySelection"
    static let previousButtonBehavior = "melox.watch.previousButtonBehavior"
    static let restoresLastSession = "melox.watch.restoresLastSession"
    static let resumesAfterInterruption = "melox.watch.resumesAfterInterruption"
    static let volume = "melox.watch.volume"

    static let showsTranslation = "melox.watch.showsTranslation"
    static let showsRomanization = "melox.watch.showsRomanization"
    static let wordByWord = "melox.watch.wordByWord"
    static let lyricGlow = "melox.watch.lyricGlow"
    static let lyricGlowIntensity = "melox.watch.lyricGlowIntensity"
    static let lyricAdvanceTime = "melox.watch.lyricAdvanceTime"
    static let lyricBlurIntensity = "melox.watch.lyricBlurIntensity"
    static let lyricDistanceBlurScale = "melox.watch.lyricDistanceBlurScale"
    static let lyricCurrentLineScale = "melox.watch.lyricCurrentLineScale"
    static let lyricHighRefreshRate = "melox.watch.lyricHighRefreshRate"
    static let lyricDimAmount = "melox.watch.lyricDimAmount"
    static let lyricFocusPosition = "melox.watch.lyricFocusPosition"
    static let lyricUniformBrowsingDimming =
        "melox.watch.lyricUniformBrowsingDimming"
    static let lyricRomanizationFontScale =
        "melox.watch.lyricRomanizationFontScale"
    static let lyricRomanizationOpacity =
        "melox.watch.lyricRomanizationOpacity"
    static let lyricLiftMode = "melox.watch.lyricLiftMode"
    static let lyricLongToneDetectionMode =
        "melox.watch.lyricLongToneDetectionMode"
    static let lyricLongToneDurationThreshold =
        "melox.watch.lyricLongToneDurationThreshold"
    static let lyricLongToneExpansionAmount =
        "melox.watch.lyricLongToneExpansionAmount"

    static let shrinksPausedArtwork = "melox.watch.shrinksPausedArtwork"
    static let showsArtist = "melox.watch.showsArtist"
    static let playerBackgroundBlur = "melox.watch.playerBackgroundBlur"
    static let playerBackgroundDim = "melox.watch.playerBackgroundDim"
    static let playerBackgroundSaturation =
        "melox.watch.playerBackgroundSaturation"
}

enum WatchStreamingQuality: String, CaseIterable, Identifiable {
    case standard
    case high
    case lossless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: "标准"
        case .high: "高品质"
        case .lossless: "无损"
        }
    }

    var bitrate: Int {
        switch self {
        case .standard: 128_000
        case .high: 320_000
        case .lossless: 999_000
        }
    }
}

enum WatchPreviousButtonBehavior: String, CaseIterable, Identifiable {
    case restartAfterFiveSeconds
    case alwaysPrevious

    var id: String { rawValue }

    var title: String {
        switch self {
        case .restartAfterFiveSeconds: "超过 5 秒回到开头"
        case .alwaysPrevious: "始终播放上一首"
        }
    }
}

enum WatchLyricsRefreshRate: String, CaseIterable, Identifiable {
    case smooth
    case powerSaving

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smooth: "流畅"
        case .powerSaving: "省电"
        }
    }

    var minimumInterval: TimeInterval {
        switch self {
        case .smooth: 1.0 / 60.0
        case .powerSaving: 1.0 / 30.0
        }
    }
}

enum WatchLyricTimingMode:
    String,
    CaseIterable,
    Identifiable,
    Sendable
{
    case word
    case character

    var id: String { rawValue }

    var liftTitle: String {
        switch self {
        case .word: "按词抬升"
        case .character: "按字抬升"
        }
    }

    var detectionTitle: String {
        switch self {
        case .word: "按词识别"
        case .character: "按字识别"
        }
    }
}

enum WatchPreferenceDefaults {
    static func register() {
        UserDefaults.standard.register(
            defaults: [
                WatchPreferenceKey.streamingQuality:
                    WatchStreamingQuality.high.rawValue,
                WatchPreferenceKey.autoPlaySelection: true,
                WatchPreferenceKey.previousButtonBehavior:
                    WatchPreviousButtonBehavior.restartAfterFiveSeconds.rawValue,
                WatchPreferenceKey.restoresLastSession: true,
                WatchPreferenceKey.resumesAfterInterruption: true,
                WatchPreferenceKey.volume: 1.0,
                WatchPreferenceKey.showsTranslation: true,
                WatchPreferenceKey.showsRomanization: false,
                WatchPreferenceKey.wordByWord: true,
                WatchPreferenceKey.lyricGlow: true,
                WatchPreferenceKey.lyricGlowIntensity: 1.0,
                WatchPreferenceKey.lyricAdvanceTime: 0.2,
                WatchPreferenceKey.lyricBlurIntensity: 0.8,
                WatchPreferenceKey.lyricDistanceBlurScale: 1.05,
                WatchPreferenceKey.lyricCurrentLineScale: 1.02,
                WatchPreferenceKey.lyricHighRefreshRate:
                    WatchLyricsRefreshRate.smooth.rawValue,
                WatchPreferenceKey.lyricDimAmount: 1.0,
                WatchPreferenceKey.lyricFocusPosition: 0.25,
                WatchPreferenceKey.lyricUniformBrowsingDimming: true,
                WatchPreferenceKey.lyricRomanizationFontScale: 0.65,
                WatchPreferenceKey.lyricRomanizationOpacity: 0.9,
                WatchPreferenceKey.lyricLiftMode:
                    WatchLyricTimingMode.character.rawValue,
                WatchPreferenceKey.lyricLongToneDetectionMode:
                    WatchLyricTimingMode.character.rawValue,
                WatchPreferenceKey.lyricLongToneDurationThreshold: 0.95,
                WatchPreferenceKey.lyricLongToneExpansionAmount: 0.05,
                WatchPreferenceKey.shrinksPausedArtwork: false,
                WatchPreferenceKey.showsArtist: true,
                WatchPreferenceKey.playerBackgroundBlur: 18.0,
                WatchPreferenceKey.playerBackgroundDim: 0.62,
                WatchPreferenceKey.playerBackgroundSaturation: 1.15
            ]
        )
    }
}
