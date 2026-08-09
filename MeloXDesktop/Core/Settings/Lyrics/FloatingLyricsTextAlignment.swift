import Foundation

enum FloatingLyricsTextAlignment: String, CaseIterable, Identifiable {
    case leading
    case center
    case trailing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leading: "居左"
        case .center: "居中"
        case .trailing: "居右"
        }
    }
}
