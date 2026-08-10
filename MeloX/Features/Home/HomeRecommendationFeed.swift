import Foundation

enum HomeRecommendationContent {
    case playlists([Playlist])
    case songs([Song])
    case podcastPrograms([PodcastProgram])

    var isEmpty: Bool {
        switch self {
        case .playlists(let playlists):
            playlists.isEmpty
        case .songs(let songs):
            songs.isEmpty
        case .podcastPrograms(let programs):
            programs.isEmpty
        }
    }

    init?(block: HomePageBlock) {
        if !block.playlists.isEmpty {
            self = .playlists(block.playlists)
        } else if !block.songs.isEmpty {
            self = .songs(block.songs)
        } else if !block.podcastPrograms.isEmpty {
            self = .podcastPrograms(block.podcastPrograms)
        } else {
            return nil
        }
    }
}

struct HomeRecommendationFallback {
    let title: String
    let content: HomeRecommendationContent
}

struct HomeRecommendationSection: Identifiable {
    let slot: HomeRecommendationSlot
    let title: String
    let content: HomeRecommendationContent

    var id: HomeRecommendationSlot { slot }

    init?(
        slot: HomeRecommendationSlot,
        block: HomePageBlock
    ) {
        guard let content = HomeRecommendationContent(block: block)
        else {
            return nil
        }
        self.slot = slot
        title = slot.title(for: block)
        self.content = content
    }

    init?(
        slot: HomeRecommendationSlot,
        fallback: HomeRecommendationFallback
    ) {
        guard !fallback.content.isEmpty else { return nil }
        self.slot = slot
        title = fallback.title
        content = fallback.content
    }
}

enum HomeRecommendationSlot: Int, CaseIterable, Identifiable {
    case recommendedPlaylists
    case recentlyTrending
    case tailoredRecommendation
    case charts
    case personalPlaylists
    case radarPlaylists
    case regionalHits
    case likedSongRoaming
    case likedSongRecommendations
    case listenedPodcastRecommendations

    var id: Int { rawValue }

    var fallbackTitle: String {
        switch self {
        case .recommendedPlaylists:
            "推荐歌单"
        case .recentlyTrending:
            "近期云村热播"
        case .tailoredRecommendation:
            "根据你的喜好为你推荐"
        case .charts:
            "排行榜"
        case .personalPlaylists:
            "你的歌单"
        case .radarPlaylists:
            "你的雷达歌单"
        case .regionalHits:
            "你所在地区最近的热门歌曲"
        case .likedSongRoaming:
            "从你喜欢的歌开始漫游"
        case .likedSongRecommendations:
            "根据你喜爱的歌曲推荐"
        case .listenedPodcastRecommendations:
            "根据你听过的热门节目推荐"
        }
    }

    func title(for block: HomePageBlock) -> String {
        guard let sectionTitle = block.sectionTitle else {
            return fallbackTitle
        }
        switch self {
        case .tailoredRecommendation,
             .personalPlaylists,
             .radarPlaylists,
             .regionalHits:
            return sectionTitle
        case .recommendedPlaylists:
            return sectionTitle == "推荐歌单"
                ? sectionTitle
                : fallbackTitle
        case .recentlyTrending:
            return sectionTitle.contains("近期云村热播")
                ? sectionTitle
                : fallbackTitle
        case .charts,
             .likedSongRoaming,
             .likedSongRecommendations,
             .listenedPodcastRecommendations:
            return fallbackTitle
        }
    }
}

struct HomeRecommendationFeed {
    let sections: [HomeRecommendationSection]

    init(
        blocks: [HomePageBlock],
        fallbacks: [
            HomeRecommendationSlot: HomeRecommendationFallback
        ] = [:],
        includesPodcasts: Bool = true
    ) {
        var blocksBySlot: [
            HomeRecommendationSlot: HomePageBlock
        ] = [:]

        for block in blocks {
            guard HomeRecommendationContent(block: block) != nil,
                  let slot = Self.slot(for: block),
                  blocksBySlot[slot] == nil else {
                continue
            }
            blocksBySlot[slot] = block
        }

        let availableSlots = HomeRecommendationSlot.allCases.filter {
            includesPodcasts
                || $0 != .listenedPodcastRecommendations
        }
        sections = availableSlots.compactMap {
            slot in
            if let block = blocksBySlot[slot],
               let section = HomeRecommendationSection(
                   slot: slot,
                   block: block
               ) {
                return section
            }
            guard let fallback = fallbacks[slot] else {
                return nil
            }
            return HomeRecommendationSection(
                slot: slot,
                fallback: fallback
            )
        }
    }

    func contains(_ slot: HomeRecommendationSlot) -> Bool {
        sections.contains { $0.slot == slot }
    }

    var firstRadarPlaylist: Playlist? {
        guard let section = sections.first(
            where: { $0.slot == .radarPlaylists }
        ), case .playlists(let playlists) = section.content else {
            return nil
        }
        return playlists.first
    }

    private static func slot(
        for block: HomePageBlock
    ) -> HomeRecommendationSlot? {
        let code = block.blockCode.uppercased()
        let title = normalized(block.title)

        if code == "HOMEPAGE_BLOCK_PLAYLIST_RCMD"
            || title == "推荐歌单" {
            return .recommendedPlaylists
        }
        if title.contains("近期云村热播") {
            return .recentlyTrending
        }
        if code.contains("TOPLIST")
            || code.contains("RANK")
            || title == "排行榜" {
            return .charts
        }
        if code == "HOMEPAGE_BLOCK_MGC_PLAYLIST"
            || title.contains("雷达歌单") {
            return .radarPlaylists
        }
        if title.contains("最近的热门歌曲") {
            return .regionalHits
        }
        if title.contains("从你喜欢的歌开始漫游") {
            return .likedSongRoaming
        }
        if title.contains("根据你喜爱的歌曲推荐") {
            return .likedSongRecommendations
        }
        if code == "HOMEPAGE_VOICELIST_RCMD"
            || title.contains("根据你听过的热门节目推荐") {
            return .listenedPodcastRecommendations
        }
        if title.hasSuffix("的歌单"), title != "推荐歌单" {
            return .personalPlaylists
        }
        if title.hasPrefix("根据"), title.hasSuffix("为你推荐") {
            return .tailoredRecommendation
        }
        if code == "HOMEPAGE_BLOCK_STYLE_RCMD" {
            return .recentlyTrending
        }
        return nil
    }

    private static func normalized(_ value: String?) -> String {
        value?
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined()
            ?? ""
    }
}
