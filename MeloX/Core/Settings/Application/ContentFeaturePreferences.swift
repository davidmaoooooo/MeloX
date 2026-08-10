import Foundation
import Observation

enum ContentFeature: String, CaseIterable, Identifiable {
    case podcasts
    case downloads
    case cloudMusic
    case listeningHistory

    var id: Self { self }

    var title: String {
        switch self {
        case .podcasts: "播客与广播"
        case .downloads: "下载"
        case .cloudMusic: "音乐云盘"
        case .listeningHistory: "最近播放"
        }
    }

    var detail: String {
        switch self {
        case .podcasts: "播客发现、推荐、搜索与订阅内容"
        case .downloads: "本地下载入口与下载资料库"
        case .cloudMusic: "网易云音乐云盘入口与云盘内容"
        case .listeningHistory: "本机及账号播放记录入口"
        }
    }

    var systemImage: String {
        switch self {
        case .podcasts: "dot.radiowaves.left.and.right"
        case .downloads: "arrow.down.circle"
        case .cloudMusic: "icloud"
        case .listeningHistory: "clock"
        }
    }

    static var availableCases: [ContentFeature] {
        allCases.filter {
            $0 != .downloads || AppFeatureAvailability.downloads
        }
    }
}

@MainActor
@Observable
final class ContentFeaturePreferences {
    private enum Key {
        static let disabledFeatures =
            "melox.contentFeatures.disabledFeatures"
    }

    private(set) var disabledFeatures: Set<ContentFeature> {
        didSet {
            defaults.set(
                disabledFeatures.map(\.rawValue).sorted(),
                forKey: Key.disabledFeatures
            )
        }
    }

    @ObservationIgnored
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        disabledFeatures = Set(
            (defaults.array(forKey: Key.disabledFeatures) as? [String])?
                .compactMap(ContentFeature.init(rawValue:)) ?? []
        )
    }

    func isEnabled(_ feature: ContentFeature) -> Bool {
        ContentFeature.availableCases.contains(feature)
            && !disabledFeatures.contains(feature)
    }

    func setEnabled(_ isEnabled: Bool, for feature: ContentFeature) {
        guard ContentFeature.availableCases.contains(feature) else { return }
        if isEnabled {
            disabledFeatures.remove(feature)
        } else {
            disabledFeatures.insert(feature)
        }
    }
}
