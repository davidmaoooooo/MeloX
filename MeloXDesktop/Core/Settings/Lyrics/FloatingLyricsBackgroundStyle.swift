import Foundation

enum FloatingLyricsBackgroundStyle: String, CaseIterable, Identifiable {
    case transparent
    case material
    case light
    case dark
    case blurredArtwork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .transparent: "透明"
        case .material: "系统材质"
        case .light: "浅色"
        case .dark: "深色"
        case .blurredArtwork: "模糊封面"
        }
    }

    var usesLightForeground: Bool {
        self == .dark || self == .blurredArtwork
    }
}
