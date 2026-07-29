import Foundation

enum AppTab: String, CaseIterable, Identifiable {
    case home
    case explore
    case library
    case librarySongs
    case libraryPlaylists
    case libraryPodcasts
    case libraryDownloads
    case libraryCloud
    case libraryHistory
    case search

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "首页"
        case .explore: "发现"
        case .library: "音乐库"
        case .librarySongs: "收藏歌曲"
        case .libraryPlaylists: "收藏歌单"
        case .libraryPodcasts: "订阅播客"
        case .libraryDownloads: "下载"
        case .libraryCloud: "云盘"
        case .libraryHistory: "最近播放"
        case .search: "搜索"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .explore: "safari"
        case .library: "music.note.list"
        case .librarySongs: "heart"
        case .libraryPlaylists: "music.note.list"
        case .libraryPodcasts: "mic"
        case .libraryDownloads: "arrow.down.circle"
        case .libraryCloud: "icloud"
        case .libraryHistory: "clock"
        case .search: "magnifyingglass"
        }
    }

    var libraryPage: LibraryPage? {
        switch self {
        case .librarySongs: .songs
        case .libraryPlaylists: .playlists
        case .libraryPodcasts: .podcasts
        case .libraryDownloads: .downloads
        case .libraryCloud: .cloud
        case .libraryHistory: .history
        case .home, .explore, .library, .search:
            nil
        }
    }

    init(libraryPage: LibraryPage) {
        switch libraryPage {
        case .songs:
            self = .librarySongs
        case .playlists:
            self = .libraryPlaylists
        case .podcasts:
            self = .libraryPodcasts
        case .downloads:
            self = .libraryDownloads
        case .cloud:
            self = .libraryCloud
        case .history:
            self = .libraryHistory
        }
    }
}

enum LibraryPage: String, CaseIterable, Identifiable {
    case songs
    case playlists
    case podcasts
    case downloads
    case cloud
    case history

    var id: String { rawValue }

    var title: String {
        switch self {
        case .songs: "歌曲"
        case .playlists: "歌单"
        case .podcasts: "播客"
        case .downloads: "下载"
        case .cloud: "云盘"
        case .history: "历史"
        }
    }

    var systemImage: String {
        switch self {
        case .songs: "music.note"
        case .playlists: "music.note.list"
        case .podcasts: "mic"
        case .downloads: "arrow.down.circle"
        case .cloud: "icloud"
        case .history: "clock"
        }
    }
}
