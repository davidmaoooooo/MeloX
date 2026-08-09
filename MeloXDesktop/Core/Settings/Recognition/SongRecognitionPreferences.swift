import Foundation
import Observation

enum SongRecognitionDuration: Int, CaseIterable, Identifiable {
    case quick = 3
    case balanced = 6
    case extended = 9
    case continuous = 0

    var id: Int { rawValue }

    var maximumDuration: Int? {
        isContinuous ? nil : rawValue
    }

    var isContinuous: Bool {
        self == .continuous
    }

    var title: String {
        switch self {
        case .quick:
            "3 秒"
        case .balanced:
            "6 秒"
        case .extended:
            "9 秒"
        case .continuous:
            "持续识别"
        }
    }

    var detail: String {
        switch self {
        case .quick:
            "更快"
        case .balanced:
            "推荐"
        case .extended:
            "嘈杂环境"
        case .continuous:
            "始终不停"
        }
    }
}

@MainActor
@Observable
final class SongRecognitionPreferences {
    private enum Key {
        static let duration = "songRecognition.duration"
    }

    var duration: SongRecognitionDuration {
        didSet {
            defaults.set(duration.rawValue, forKey: Key.duration)
        }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if defaults.object(forKey: Key.duration) != nil {
            duration =
                SongRecognitionDuration(
                    rawValue: defaults.integer(
                        forKey: Key.duration
                    )
                )
                ?? .balanced
        } else {
            duration = .balanced
        }
    }
}
