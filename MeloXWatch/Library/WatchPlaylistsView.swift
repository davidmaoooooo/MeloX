import SwiftUI

struct WatchPlaylistsView: View {
    @EnvironmentObject private var account: WatchAccountStore

    let api: WatchNeteaseAPI

    @State private var phase: WatchPagePhase<[WatchPlaylist]> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                ProgressView("正在载入歌单")
            case .failed(let message):
                ContentUnavailableView(
                    "无法载入歌单",
                    systemImage: "music.note.list",
                    description: Text(message)
                )
            case .loaded(let playlists):
                List(playlists) { playlist in
                    NavigationLink {
                        WatchPlaylistDetailView(
                            api: api,
                            playlist: playlist
                        )
                    } label: {
                        HStack(spacing: 8) {
                            AsyncImage(url: playlist.artworkURL) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFill()
                                } else {
                                    Image(systemName: "music.note.list")
                                        .frame(
                                            maxWidth: .infinity,
                                            maxHeight: .infinity
                                        )
                                        .background(.quaternary)
                                }
                            }
                            .frame(width: 36, height: 36)
                            .clipShape(.rect(cornerRadius: 8))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(playlist.name).lineLimit(2)
                                Text("\(playlist.trackCount) 首")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("我的歌单")
        .task {
            await load()
        }
    }

    private func load() async {
        guard account.isLoggedIn else {
            phase = .failed("请先登录网易云音乐。")
            return
        }
        phase = .loading
        do {
            let profile: WatchAccountProfile
            if let existingProfile = account.profile {
                profile = existingProfile
            } else {
                profile = try await api.accountProfile()
            }
            account.updateProfile(profile)
            phase = .loaded(
                try await api.userPlaylists(userID: profile.userID)
            )
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

private struct WatchPlaylistDetailView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator

    let api: WatchNeteaseAPI
    let playlist: WatchPlaylist

    @State private var phase: WatchPagePhase<[WatchSong]> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                ProgressView("正在载入歌曲")
            case .failed(let message):
                ContentUnavailableView(
                    "无法载入歌单",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded(let songs):
                List {
                    Button {
                        Task {
                            guard let first = songs.first else { return }
                            await coordinator.play(first, in: songs)
                        }
                    } label: {
                        Label("播放全部", systemImage: "play.fill")
                    }

                    ForEach(songs) { song in
                        Button {
                            Task {
                                await coordinator.play(song, in: songs)
                            }
                        } label: {
                            WatchSongLabel(song: song)
                        }
                    }
                }
            }
        }
        .navigationTitle(playlist.name)
        .task {
            phase = .loading
            do {
                phase = .loaded(
                    try await api.playlist(id: playlist.id).tracks
                )
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }
}
