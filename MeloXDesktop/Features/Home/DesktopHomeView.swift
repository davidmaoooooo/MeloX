import SwiftUI

struct DesktopHomeView: View {
    @Environment(DesktopAppModel.self) private var model

    private enum Metrics {
        static let horizontalPadding: CGFloat = 52
        static let heroColumns = 3
        static let heroSpacing: CGFloat = 20
        static let mediaColumns = 4
        static let mediaSpacing: CGFloat = 24

        static func cardWidth(
            containerWidth: CGFloat,
            reservedTrailingWidth: CGFloat,
            columnCount: Int,
            spacing: CGFloat
        ) -> CGFloat {
            let usableWidth = max(
                containerWidth
                    - reservedTrailingWidth
                    - horizontalPadding * 2,
                0
            )
            let totalSpacing = spacing * CGFloat(max(columnCount - 1, 0))
            let rawWidth = (usableWidth - totalSpacing)
                / CGFloat(columnCount)
            return max(rawWidth.rounded(.down), 1)
        }
    }

    var body: some View {
        GeometryReader { proxy in
            let isInspectorPresented = model.ui.inspector != nil
            let reservedTrailingWidth = isInspectorPresented
                ? DesktopMainWindowMetrics.playerSidePanelWidth
                : 0
            let heroCardWidth = Metrics.cardWidth(
                containerWidth: proxy.size.width,
                reservedTrailingWidth: reservedTrailingWidth,
                columnCount: Metrics.heroColumns,
                spacing: Metrics.heroSpacing
            )
            let mediaCardWidth = Metrics.cardWidth(
                containerWidth: proxy.size.width,
                reservedTrailingWidth: reservedTrailingWidth,
                columnCount: Metrics.mediaColumns,
                spacing: Metrics.mediaSpacing
            )

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 32) {
                    Text("主页")
                        .font(.system(size: 46, weight: .bold))

                    DesktopHomeQuickActionsView(
                        cardWidth: heroCardWidth,
                        spacing: Metrics.heroSpacing,
                        visibleItemCount: Metrics.heroColumns,
                        trailingOverlayInset: reservedTrailingWidth
                    )

                    heroSection(
                        cardWidth: heroCardWidth,
                        trailingOverlayInset: reservedTrailingWidth
                    )

                    if !recentSongs.isEmpty {
                        songCardSection(
                            title: "最近播放",
                            songs: Array(recentSongs.prefix(8)),
                            cardWidth: mediaCardWidth,
                            trailingOverlayInset: reservedTrailingWidth
                        )
                    }

                    if !model.home.recommendedPlaylists.isEmpty {
                        playlistSection(
                            cardWidth: mediaCardWidth,
                            trailingOverlayInset: reservedTrailingWidth
                        )
                    }

                    if !model.home.newAlbums.isEmpty {
                        albumSection(
                            cardWidth: mediaCardWidth,
                            trailingOverlayInset: reservedTrailingWidth
                        )
                    }

                    if !model.home.podcastPrograms.isEmpty {
                        podcastProgramSection(
                            cardWidth: mediaCardWidth,
                            trailingOverlayInset: reservedTrailingWidth
                        )
                    }

                    if case .failed(let message) = model.home.phase {
                        ContentUnavailableView(
                            "无法载入主页",
                            systemImage: "wifi.exclamationmark",
                            description: Text(message)
                        )
                        .frame(maxWidth: .infinity, minHeight: 320)
                    }
                }
                .padding(.horizontal, Metrics.horizontalPadding)
                .padding(.top, 22)
                .padding(.bottom, 34)
            }
        }
        .navigationTitle("")
        .task { await model.home.load() }
    }

    @ViewBuilder
    private func heroSection(
        cardWidth: CGFloat,
        trailingOverlayInset: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DesktopSectionHeader(title: "推荐歌单")

            if model.home.recommendedPlaylists.isEmpty {
                if model.home.phase == .loading {
                    HStack {
                        Spacer()
                        Label(
                            "正在载入为你准备的内容…",
                            systemImage: "sparkles"
                        )
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .frame(height: 270)
                }
            } else {
                DesktopHomePagingShelf(
                    items: Array(model.home.recommendedPlaylists.prefix(7)),
                    cardWidth: cardWidth,
                    spacing: Metrics.heroSpacing,
                    visibleItemCount: Metrics.heroColumns,
                    trailingOverlayInset: trailingOverlayInset
                ) { playlist in
                    DesktopHeroCard(
                        title: playlist.name,
                        subtitle: playlist.creator?.nickname,
                        eyebrow: playlist.copywriter ?? "专属推荐",
                        artworkURL: playlist.artworkURL,
                        playCount: playlist.playCount,
                        showsPlayCount: model.settings.showPlayCount
                    ) {
                        model.ui.navigate(to: .playlist(playlist.id))
                    }
                }
            }
        }
    }

    private var recentSongs: [Song] {
        model.library.recentSongs.isEmpty
            ? model.home.newSongs
            : model.library.recentSongs
    }

    private func songCardSection(
        title: String,
        songs: [Song],
        cardWidth: CGFloat,
        trailingOverlayInset: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DesktopSectionHeader(title: title)
            DesktopHomePagingShelf(
                items: songs,
                cardWidth: cardWidth,
                spacing: Metrics.mediaSpacing,
                visibleItemCount: Metrics.mediaColumns,
                trailingOverlayInset: trailingOverlayInset
            ) { song in
                DesktopMediaCard(
                    title: song.name,
                    subtitle: song.artistText,
                    artworkURL: song.album?.artworkURL,
                    action: { model.ui.navigate(to: .song(song.id)) },
                    playAction: {
                        Task { await model.player.play(song, in: songs) }
                    }
                )
            }
        }
    }

    private func playlistSection(
        cardWidth: CGFloat,
        trailingOverlayInset: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DesktopSectionHeader(
                title: "为你推荐",
                trailingTitle: "查看全部"
            ) {
                model.ui.selection = .playlists
            }
            DesktopHomePagingShelf(
                items: Array(model.home.recommendedPlaylists.prefix(12)),
                cardWidth: cardWidth,
                spacing: Metrics.mediaSpacing,
                visibleItemCount: Metrics.mediaColumns,
                trailingOverlayInset: trailingOverlayInset
            ) { playlist in
                DesktopMediaCard(
                    title: playlist.name,
                    subtitle: playlist.creator?.nickname ?? playlist.copywriter,
                    artworkURL: playlist.artworkURL,
                    playCount: playlist.playCount,
                    showsPlayCount: model.settings.showPlayCount,
                    action: { model.ui.navigate(to: .playlist(playlist.id)) },
                    playAction: { play(playlist) }
                )
            }
        }
    }

    private func albumSection(
        cardWidth: CGFloat,
        trailingOverlayInset: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DesktopSectionHeader(
                title: "新专辑",
                trailingTitle: "查看全部"
            ) {
                model.ui.selection = .discovery
            }
            DesktopHomePagingShelf(
                items: Array(model.home.newAlbums.prefix(12)),
                cardWidth: cardWidth,
                spacing: Metrics.mediaSpacing,
                visibleItemCount: Metrics.mediaColumns,
                trailingOverlayInset: trailingOverlayInset
            ) { album in
                DesktopMediaCard(
                    title: album.name,
                    subtitle: album.artistText,
                    artworkURL: album.artworkURL,
                    action: { model.ui.navigate(to: .album(album.id)) },
                    playAction: { play(album) }
                )
            }
        }
    }

    private func podcastProgramSection(
        cardWidth: CGFloat,
        trailingOverlayInset: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            DesktopSectionHeader(
                title: "推荐播客",
                trailingTitle: "广播"
            ) {
                model.ui.selection = .radio
            }
            DesktopHomePagingShelf(
                items: Array(model.home.podcastPrograms.prefix(8)),
                cardWidth: cardWidth,
                spacing: Metrics.mediaSpacing,
                visibleItemCount: Metrics.mediaColumns,
                trailingOverlayInset: trailingOverlayInset
            ) { program in
                DesktopMediaCard(
                    title: program.name,
                    subtitle: program.radio.name,
                    artworkURL: program.artworkURL,
                    action: { model.ui.navigate(to: .podcast(program.radio.id)) },
                    playAction: program.playbackSong.map { song in
                        { Task { await model.player.play(song) } }
                    }
                )
            }
        }
    }

    private func play(_ playlist: Playlist) {
        Task {
            guard let detail = try? await model.api.playlist(
                id: playlist.id,
                trackLimit: 100
            ) else { return }
            await model.player.playAll(detail.tracks, sourceID: detail.id)
        }
    }

    private func play(_ album: Album) {
        Task {
            guard let detail = try? await model.api.album(id: album.id) else { return }
            await model.player.playAll(detail.1, sourceID: album.id)
        }
    }
}
