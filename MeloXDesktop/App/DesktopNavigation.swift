import Foundation
import Observation

enum DesktopSection: String, CaseIterable, Identifiable, Hashable {
    case search
    case home
    case discovery
    case radio
    case recent
    case songs
    case playlists
    case podcasts
    case downloads
    case cloud
    case messages

    var id: Self { self }

    var title: String {
        switch self {
        case .search: "搜索"
        case .home: "主页"
        case .discovery: "新发现"
        case .radio: "广播"
        case .recent: "最近播放"
        case .songs: "收藏歌曲"
        case .playlists: "收藏歌单"
        case .podcasts: "订阅播客"
        case .downloads: "下载"
        case .cloud: "云盘"
        case .messages: "消息"
        }
    }

    var systemImage: String {
        switch self {
        case .search: "magnifyingglass"
        case .home: "house"
        case .discovery: "square.grid.2x2"
        case .radio: "dot.radiowaves.left.and.right"
        case .recent: "clock"
        case .songs: "heart"
        case .playlists: "music.note.list"
        case .podcasts: "mic"
        case .downloads: "arrow.down.circle"
        case .cloud: "icloud"
        case .messages: "bubble.left.and.bubble.right"
        }
    }
}

enum DesktopRoute: Hashable {
    case album(Int)
    case artist(Int)
    case dailySongs
    case privateRoaming
    case playlist(Int)
    case podcast(Int)
    case podcastCategory(id: Int, title: String)
    case section(DesktopSection)
    case similarSongs(Int)
    case song(Int)
}

enum DesktopInspector: String, CaseIterable, Identifiable, Hashable {
    case lyrics
    case queue

    var id: Self { self }
}

enum DesktopSheet: Identifiable {
    case onboarding
    case account
    case login
    case recognition
    case listenTogether
    case listenTogetherInvitation(NeteaseListenTogetherLink)
    case sleepTimer
    case beatNetDebug

    var id: String {
        switch self {
        case .onboarding: "onboarding"
        case .account: "account"
        case .login: "login"
        case .recognition: "recognition"
        case .listenTogether: "listen-together"
        case .listenTogetherInvitation(let invitation):
            "listen-together-\(invitation.id)"
        case .sleepTimer: "sleep-timer"
        case .beatNetDebug: "beatnet-debug"
        }
    }
}

@MainActor
@Observable
final class DesktopUIState {
    var selection: DesktopSection = .home {
        didSet { path.removeAll() }
    }
    var path: [DesktopRoute] = []
    var inspector: DesktopInspector?
    private(set) var retainedInspector: DesktopInspector = .lyrics
    var sheet: DesktopSheet?
    var isSearchPresented = false
    var isPlayerHovered = false
    var isPlayerProgressHovered = false
    var isNowPlayingPresented = false

    func navigate(to route: DesktopRoute) {
        path.append(route)
    }

    func toggleInspector(_ requested: DesktopInspector) {
        if inspector == requested {
            inspector = nil
        } else {
            retainedInspector = requested
            inspector = requested
        }
    }
}
