import Foundation

enum FloatingLyricsTextEffect: String, CaseIterable, Identifiable {
    case none
    case shadow
    case glow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: "无"
        case .shadow: "阴影"
        case .glow: "辉光"
        }
    }
}
