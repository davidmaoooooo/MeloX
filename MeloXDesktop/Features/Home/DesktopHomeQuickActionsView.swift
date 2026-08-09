import SwiftUI

enum DesktopHomeQuickAction: String, CaseIterable, Identifiable {
    case dailySongs
    case heartMode
    case privateRoaming
    case hotSongs
    case privateRadar
    case similarSongs

    var id: Self { self }

    var title: String {
        switch self {
        case .dailySongs: "每日推荐"
        case .hotSongs: "热歌榜"
        case .heartMode: "心动模式"
        case .privateRadar: "私人雷达"
        case .privateRoaming: "私人漫游"
        case .similarSongs: "相似歌曲"
        }
    }

    var subtitle: String {
        switch self {
        case .dailySongs: "每天为你更新"
        case .hotSongs: "全站热门歌曲"
        case .heartMode: "喜欢与惊喜交替"
        case .privateRadar: "发现合口味的歌单"
        case .privateRoaming: "漫游到新的好音乐"
        case .similarSongs: "从当前歌曲出发"
        }
    }

    var eyebrow: String {
        switch self {
        case .dailySongs: "每日更新"
        case .heartMode: "专属心情好歌"
        case .privateRoaming: "探索新鲜好音乐"
        case .hotSongs: "全站实时热度"
        case .privateRadar: "持续发现"
        case .similarSongs: "从正在播放出发"
        }
    }

    var systemImage: String {
        switch self {
        case .dailySongs: "calendar"
        case .hotSongs: "flame.fill"
        case .heartMode: "heart.fill"
        case .privateRadar: "dot.radiowaves.left.and.right"
        case .privateRoaming: "figure.walk.motion"
        case .similarSongs: "music.note.list"
        }
    }

    var tint: Color {
        switch self {
        case .dailySongs: .red
        case .hotSongs: .orange
        case .heartMode: .pink
        case .privateRadar: .purple
        case .privateRoaming: .blue
        case .similarSongs: .teal
        }
    }

    var backgroundColors: [Color] {
        switch self {
        case .dailySongs:
            [.indigo, .blue, .mint]
        case .heartMode:
            [.orange, .red]
        case .privateRoaming:
            [.black, .indigo, .gray]
        case .hotSongs:
            [.red, .orange]
        case .privateRadar:
            [.purple, .blue]
        case .similarSongs:
            [.teal, .indigo]
        }
    }

    var startsPlayback: Bool {
        switch self {
        case .heartMode:
            true
        case .dailySongs, .hotSongs, .privateRadar, .privateRoaming,
             .similarSongs:
            false
        }
    }
}

struct DesktopHomeQuickActionsView: View {
    @Environment(DesktopAppModel.self) private var model

    let cardWidth: CGFloat
    let spacing: CGFloat
    let visibleItemCount: Int
    let trailingOverlayInset: CGFloat

    @State private var activeAction: DesktopHomeQuickAction?
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DesktopSectionHeader(title: "专属精选推荐")

            DesktopHomePagingShelf(
                items: DesktopHomeQuickAction.allCases,
                cardWidth: cardWidth,
                spacing: spacing,
                visibleItemCount: visibleItemCount,
                trailingOverlayInset: trailingOverlayInset
            ) { action in
                DesktopHomeQuickActionButton(
                    action: action,
                    artworkURL: artworkURL(for: action),
                    width: cardWidth,
                    height: cardWidth * 4 / 3,
                    isActive: activeAction == action,
                    isDisabled: activeAction != nil
                ) {
                    perform(action)
                }
            }
        }
        .alert(
            "无法完成操作",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("好") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "请稍后重试。")
        }
    }

    private func perform(_ action: DesktopHomeQuickAction) {
        switch action {
        case .dailySongs:
            model.ui.navigate(to: .dailySongs)
        case .hotSongs:
            if let playlist = hotSongsChart {
                model.ui.navigate(to: .playlist(playlist.id))
            } else {
                model.ui.selection = .discovery
            }
        case .privateRadar:
            guard presentLoginIfNeeded() else { return }
            guard let playlist = privateRadarPlaylist else {
                errorMessage = "当前推荐中没有可用的私人雷达歌单。"
                return
            }
            model.ui.navigate(to: .playlist(playlist.id))
        case .heartMode:
            guard presentLoginIfNeeded() else { return }
            startPlayback(action)
        case .privateRoaming:
            guard presentLoginIfNeeded() else { return }
            model.ui.navigate(to: .privateRoaming)
        case .similarSongs:
            guard let currentSong = model.player.currentSong,
                  !currentSong.isPodcastProgram else {
                errorMessage = DesktopHomePlaybackActionError.songRequired
                    .localizedDescription
                return
            }
            model.ui.navigate(to: .similarSongs(currentSong.id))
        }
    }

    private func presentLoginIfNeeded() -> Bool {
        guard model.library.isLoggedIn else {
            model.ui.sheet = .login
            return false
        }
        return true
    }

    private func startPlayback(_ action: DesktopHomeQuickAction) {
        guard activeAction == nil else { return }
        activeAction = action
        errorMessage = nil

        Task { @MainActor in
            defer { activeAction = nil }
            do {
                switch action {
                case .heartMode:
                    try await startHeartMode()
                case .dailySongs, .hotSongs, .privateRadar, .privateRoaming,
                     .similarSongs:
                    break
                }
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func startHeartMode() async throws {
        guard let playlistID = model.library.likedPlaylistID,
              let seedSongID = model.library.randomHeartModeSeedSongID() else {
            throw DesktopHomePlaybackActionError.noLikedSongs
        }
        try await model.player.playHeartMode(
            playlistID: playlistID,
            seedSongID: seedSongID
        )
    }

    private var hotSongsChart: Playlist? {
        model.home.toplists.first { $0.name.contains("热歌榜") }
            ?? model.home.toplists.first { $0.id == 3_778_678 }
    }

    private var privateRadarPlaylist: Playlist? {
        model.home.privateRadarPlaylist
            ?? model.library.favoritePlaylists.first {
                $0.name.localizedCaseInsensitiveContains("雷达")
            }
            ?? model.home.recommendedPlaylists.first {
                $0.name.localizedCaseInsensitiveContains("雷达")
            }
    }

    private func artworkURL(
        for action: DesktopHomeQuickAction
    ) -> URL? {
        switch action {
        case .dailySongs, .heartMode:
            nil
        case .privateRoaming:
            model.home.privateRadarPlaylist?.artworkURL
                ?? model.home.recommendedPlaylists.first?.artworkURL
        case .hotSongs:
            hotSongsChart?.artworkURL
        case .privateRadar:
            privateRadarPlaylist?.artworkURL
        case .similarSongs:
            model.player.currentSong?.album?.artworkURL
        }
    }
}

private struct DesktopHomeQuickActionButton: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let action: DesktopHomeQuickAction
    let artworkURL: URL?
    let width: CGFloat
    let height: CGFloat
    let isActive: Bool
    let isDisabled: Bool
    let perform: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: perform) {
            ZStack(alignment: .bottomLeading) {
                background

                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Spacer()
                        Label("MeloX", systemImage: "music.note")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VStack(alignment: .leading, spacing: 5) {
                        Text(action.eyebrow)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.68))

                        Text(action.title)
                            .font(.system(size: 25, weight: .bold))
                            .foregroundStyle(.white)

                        Text(action.subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.92))
                            .lineLimit(2)
                    }
                }
                .padding(24)
                .frame(width: width, height: height)

                if isActive {
                    Image(systemName: "waveform")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.primary)
                        .padding(18)
                        .background(.regularMaterial, in: .circle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityLabel("正在启动\(action.title)")
                }
            }
            .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: 15, style: .continuous))
            .contentShape(.rect(cornerRadius: 15, style: .continuous))
            .shadow(
                color: .black.opacity(isHovered ? 0.22 : 0.10),
                radius: isHovered ? 18 : 6,
                y: isHovered ? 9 : 3
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(
            action.startsPlayback
                ? "开始播放\(action.title)"
                : "打开\(action.title)"
        )
        .accessibilityHint(
            action.startsPlayback
                ? "开始播放\(action.title)"
                : "打开\(action.title)"
        )
        .scaleEffect(isHovered && !isDisabled ? 1.012 : 1)
        .onHover { isHovered = $0 }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.16),
            value: isHovered
        )
    }

    private var background: some View {
        ZStack {
            if let artworkURL {
                DesktopArtworkView(
                    url: artworkURL,
                    cornerRadius: 0
                )
                .frame(width: width, height: height)
                .clipped()
            } else {
                LinearGradient(
                    colors: action.backgroundColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: action.systemImage)
                    .font(.system(size: min(height * 0.34, 150)))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white.opacity(0.22))
                    .offset(y: -height * 0.08)
            }

            LinearGradient(
                colors: [
                    action.tint.opacity(artworkURL == nil ? 0.06 : 0.24),
                    .clear,
                    .black.opacity(0.78),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: width, height: height)
        .clipped()
    }
}

private enum DesktopHomePlaybackActionError: LocalizedError {
    case noLikedSongs
    case songRequired

    var errorDescription: String? {
        switch self {
        case .noLikedSongs:
            "请先收藏一些歌曲，等待“我喜欢的音乐”同步后再试。"
        case .songRequired:
            "请先播放一首普通歌曲，再打开相似歌曲。"
        }
    }
}
