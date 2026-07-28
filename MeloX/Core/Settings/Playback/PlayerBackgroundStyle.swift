import Foundation

enum PlayerBackgroundStyle: String, CaseIterable, Identifiable {
    case flowingLight
    case blurredArtwork

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flowingLight:
            "流动光影"
        case .blurredArtwork:
            "模糊封面"
        }
    }
}
