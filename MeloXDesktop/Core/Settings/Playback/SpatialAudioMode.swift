import Foundation

enum SpatialAudioMode: String, CaseIterable, Identifiable {
    case automatic
    case multichannelOnly
    case disabled

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            "自动（推荐）"
        case .multichannelOnly:
            "仅多声道"
        case .disabled:
            "关闭"
        }
    }

    var description: String {
        switch self {
        case .automatic:
            "允许 macOS 对立体声和多声道音源使用空间音频。"
        case .multichannelOnly:
            "仅允许具有多声道布局的音源使用空间音频。"
        case .disabled:
            "始终以音源原始声道布局播放，不进行系统空间化。"
        }
    }
}
