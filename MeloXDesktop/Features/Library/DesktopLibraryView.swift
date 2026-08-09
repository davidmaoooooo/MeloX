import SwiftUI
import UniformTypeIdentifiers

struct DesktopLibraryView: View {
    @Environment(DesktopAppModel.self) private var model
    let section: DesktopSection

    @State private var showsImporter = false

    private let columns = [
        GridItem(.adaptive(minimum: 145, maximum: 205), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    Text(section.title)
                        .font(.system(size: 32, weight: .bold))
                    Spacer()
                    headerActions
                }

                content
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
        }
        .navigationTitle(section.title)
        .task {
            await model.library.refresh()
            if section == .cloud {
                await model.cloud.refresh()
            }
        }
        .fileImporter(
            isPresented: $showsImporter,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result,
                  let url = urls.first else { return }
            Task {
                let accessed = url.startAccessingSecurityScopedResource()
                defer {
                    if accessed { url.stopAccessingSecurityScopedResource() }
                }
                await model.cloud.upload(fileAt: url)
            }
        }
    }

    @ViewBuilder
    private var headerActions: some View {
        switch section {
        case .songs:
            Button("播放全部", systemImage: "play.fill") {
                Task { await model.player.playAll(model.library.favoriteSongs) }
            }
            .disabled(model.library.favoriteSongs.isEmpty)
        case .downloads:
            Button("播放全部", systemImage: "play.fill") {
                Task { await model.player.playAll(model.downloads.downloadedSongs) }
            }
            .disabled(model.downloads.downloadedSongs.isEmpty)
        case .cloud:
            Button("上传音乐", systemImage: "plus") { showsImporter = true }
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch section {
        case .recent:
            songList(model.library.recentSongs)
        case .songs:
            songList(model.library.favoriteSongs)
        case .downloads:
            songList(model.downloads.downloadedSongs)
        case .cloud:
            cloudList
        case .playlists:
            playlistGrid
        case .podcasts:
            podcastGrid
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private func songList(_ songs: [Song]) -> some View {
        if songs.isEmpty {
            libraryEmptyView
        } else {
            LazyVStack(spacing: 2) {
                ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                    DesktopTrackRow(
                        song: song,
                        index: index,
                        songs: songs,
                        showsArtwork: true
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var playlistGrid: some View {
        let playlists = model.library.favoritePlaylists
        if playlists.isEmpty {
            libraryEmptyView
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(playlists) { playlist in
                    DesktopMediaCard(
                        title: playlist.name,
                        subtitle: playlist.creator?.nickname,
                        artworkURL: playlist.artworkURL,
                        playCount: playlist.playCount,
                        showsPlayCount: model.settings.showPlayCount,
                        action: { model.ui.navigate(to: .playlist(playlist.id)) },
                        playAction: { play(playlist) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var podcastGrid: some View {
        let podcasts = model.library.subscribedPodcasts
        if podcasts.isEmpty {
            libraryEmptyView
        } else {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(podcasts) { podcast in
                    DesktopMediaCard(
                        title: podcast.name,
                        subtitle: podcast.subtitle,
                        artworkURL: podcast.artworkURL,
                        action: { model.ui.navigate(to: .podcast(podcast.id)) }
                    )
                }
            }
        }
    }

    @ViewBuilder
    private var cloudList: some View {
        if model.cloud.isUploading {
            ProgressView("正在上传音乐…")
        }
        if model.cloud.items.isEmpty {
            libraryEmptyView
        } else {
            LazyVStack(spacing: 2) {
                ForEach(Array(model.cloud.items.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 0) {
                        DesktopTrackRow(
                            song: item.simpleSong,
                            index: index,
                            songs: model.cloud.songs,
                            showsArtwork: true
                        )
                        Button(role: .destructive) {
                            Task { await model.cloud.delete(item) }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 8)
                    }
                    .task { await model.cloud.loadMoreIfNeeded(after: item) }
                }
            }
        }
    }

    private var libraryEmptyView: some View {
        ContentUnavailableView {
            Label(
                model.library.isLoggedIn ? "这里还没有内容" : "登录后查看完整资料库",
                systemImage: section.systemImage
            )
        } description: {
            Text(model.library.isLoggedIn ? "在 MeloX 中收藏、播放或下载内容后会显示在这里。" : "使用网易云音乐账户同步收藏、播客和云盘。")
        } actions: {
            if !model.library.isLoggedIn {
                Button("登录") { model.ui.sheet = .login }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 340)
    }

    private func play(_ playlist: Playlist) {
        Task {
            guard let detail = try? await model.api.playlist(id: playlist.id) else { return }
            await model.player.playAll(detail.tracks, sourceID: playlist.id)
        }
    }
}
