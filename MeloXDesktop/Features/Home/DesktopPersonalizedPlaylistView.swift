import SwiftUI

enum DesktopPersonalizedPlaylistKind: Hashable {
    case dailySongs
    case privateRoaming
    case similarSongs(seedSongID: Int)

    var title: String {
        switch self {
        case .dailySongs: "每日推荐"
        case .privateRoaming: "私人漫游"
        case .similarSongs: "相似歌曲"
        }
    }

    var systemImage: String {
        switch self {
        case .dailySongs: "calendar"
        case .privateRoaming: "figure.walk.motion"
        case .similarSongs: "music.note.list"
        }
    }

    var tint: Color {
        switch self {
        case .dailySongs: .red
        case .privateRoaming: .blue
        case .similarSongs: .teal
        }
    }

    var requiresLogin: Bool {
        switch self {
        case .dailySongs, .privateRoaming: true
        case .similarSongs: false
        }
    }

    var loadingMessage: String {
        switch self {
        case .dailySongs: "正在载入每日推荐…"
        case .privateRoaming: "正在准备私人漫游…"
        case .similarSongs: "正在查找相似歌曲…"
        }
    }

    var emptyDescription: String {
        switch self {
        case .dailySongs:
            "稍后再试，或使用“换一批”重新请求。"
        case .privateRoaming:
            "网易云音乐暂时没有返回新的漫游歌曲。"
        case .similarSongs:
            "网易云音乐暂时没有找到与当前歌曲相似的内容。"
        }
    }
}

struct DesktopPersonalizedPlaylistView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let kind: DesktopPersonalizedPlaylistKind

    @State private var songs: [Song] = []
    @State private var seedSong: Song?
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var isRefreshing = false
    @State private var refreshErrorMessage: String?

    var body: some View {
        Group {
            if kind.requiresLogin, !model.library.isLoggedIn {
                loginRequiredView
            } else {
                content
            }
        }
        .navigationTitle(kind.title)
        .task(id: loadRequest) {
            await load()
        }
        .alert(
            "无法换一批",
            isPresented: Binding(
                get: { refreshErrorMessage != nil },
                set: { if !$0 { refreshErrorMessage = nil } }
            )
        ) {
            Button("好") { refreshErrorMessage = nil }
        } message: {
            Text(refreshErrorMessage ?? "请稍后重试。")
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.30),
            value: phase
        )
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .loading:
            DesktopDetailLoadingView(message: kind.loadingMessage)
        case .failed(let message):
            DesktopDetailErrorView(message: message) {
                reloadToken += 1
            }
        case .loaded:
            playlistContent
        }
    }

    private var playlistContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 34) {
                DesktopCollectionHeader(
                    artworkURL: artworkURL,
                    kind: "播放列表",
                    title: kind.title,
                    subtitle: subtitle,
                    metadata: metadata,
                    description: collectionDescription,
                    songs: songs,
                    sourceID: nil,
                    artworkSystemImage: artworkURL == nil
                        ? kind.systemImage
                        : nil,
                    artworkTint: kind.tint,
                    supplementaryAction: supplementaryAction
                )

                Divider()

                if songs.isEmpty {
                    ContentUnavailableView(
                        "暂无\(kind.title)",
                        systemImage: kind.systemImage,
                        description: Text(kind.emptyDescription)
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else {
                    DesktopCollectionTrackList(
                        songs: songs,
                        sourceID: nil
                    )
                }
            }
            .padding(.horizontal, 42)
            .padding(.vertical, 34)
        }
    }

    private var loginRequiredView: some View {
        ContentUnavailableView {
            Label(
                "登录后查看\(kind.title)",
                systemImage: "person.crop.circle.badge.exclamationmark"
            )
        } description: {
            Text("该播放列表由网易云音乐根据你的账号偏好生成。")
        } actions: {
            Button("登录网易云音乐") {
                model.ui.sheet = .login
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var artworkURL: URL? {
        switch kind {
        case .dailySongs:
            nil
        case .privateRoaming:
            model.home.privateRadarPlaylist?.artworkURL
                ?? model.home.recommendedPlaylists.first?.artworkURL
        case .similarSongs:
            seedSong?.album?.artworkURL
        }
    }

    private var subtitle: String? {
        switch kind {
        case .dailySongs, .privateRoaming:
            "网易云音乐"
        case .similarSongs:
            if let seedSong {
                "基于《\(seedSong.name)》"
            } else {
                "从当前歌曲出发"
            }
        }
    }

    private var metadata: String {
        switch kind {
        case .dailySongs:
            "\(songs.count) 首歌曲 · \(todayText)"
        case .privateRoaming:
            "\(songs.count) 首歌曲 · 专属推荐"
        case .similarSongs:
            "\(songs.count) 首歌曲"
        }
    }

    private var collectionDescription: String? {
        switch kind {
        case .dailySongs:
            return "根据你的音乐口味生成，每日更新。"
        case .privateRoaming:
            return "探索你可能喜欢、但还没有听过的音乐。"
        case .similarSongs:
            guard let seedSong else {
                return "从正在播放的歌曲出发，发现风格相近的音乐。"
            }
            return "从 \(seedSong.artistText) 的《\(seedSong.name)》出发，发现风格相近的音乐。"
        }
    }

    private var supplementaryAction: DesktopCollectionSupplementaryAction? {
        guard case .dailySongs = kind else { return nil }
        return DesktopCollectionSupplementaryAction(
            title: isRefreshing ? "更换中" : "换一批",
            systemImage: "arrow.triangle.2.circlepath",
            isRunning: isRefreshing,
            isDisabled: phase != .loaded,
            action: {
                Task { await refresh() }
            }
        )
    }

    private var todayText: String {
        Date.now.formatted(date: .long, time: .omitted)
    }

    private var loadRequest: DesktopPersonalizedPlaylistLoadRequest {
        DesktopPersonalizedPlaylistLoadRequest(
            kind: kind,
            accountToken: model.settings.cookie.hashValue,
            reloadToken: reloadToken
        )
    }

    private func load() async {
        guard !kind.requiresLogin || model.library.isLoggedIn else {
            songs = []
            phase = .loaded
            return
        }

        phase = .loading
        do {
            let loadedSongs = try await fetchSongs(afresh: false)
            try Task.checkCancellation()
            guard !loadedSongs.isEmpty else {
                throw DesktopPersonalizedPlaylistError.emptyRecommendations(
                    kind.title
                )
            }
            songs = loadedSongs
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled else { return }
            phase = .failed(error.localizedDescription)
        }
    }

    private func refresh() async {
        guard !isRefreshing, case .dailySongs = kind else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let refreshedSongs = try await fetchSongs(afresh: true)
            try Task.checkCancellation()
            guard !refreshedSongs.isEmpty else {
                throw DesktopPersonalizedPlaylistError.emptyRecommendations(
                    kind.title
                )
            }
            songs = refreshedSongs
        } catch is CancellationError {
            return
        } catch {
            refreshErrorMessage = error.localizedDescription
        }
    }

    private func fetchSongs(afresh: Bool) async throws -> [Song] {
        switch kind {
        case .dailySongs:
            return try await model.api.dailySongs(afresh: afresh)
        case .privateRoaming:
            return try await model.api.personalFM(
                mode: .explore,
                limit: 30
            )
        case .similarSongs(let seedSongID):
            if seedSong?.id != seedSongID {
                seedSong = model.player.currentSong?.id == seedSongID
                    ? model.player.currentSong
                    : try await model.api.songDetails(ids: [seedSongID]).first
            }
            return try await model.api.similarSongs(
                id: seedSongID,
                limit: 50
            )
        }
    }
}

private struct DesktopPersonalizedPlaylistLoadRequest: Hashable {
    let kind: DesktopPersonalizedPlaylistKind
    let accountToken: Int
    let reloadToken: Int
}

private enum DesktopPersonalizedPlaylistError: LocalizedError {
    case emptyRecommendations(String)

    var errorDescription: String? {
        switch self {
        case .emptyRecommendations(let title):
            "网易云音乐暂时没有返回可用的\(title)歌曲。"
        }
    }
}
