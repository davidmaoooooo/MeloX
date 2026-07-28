import SwiftUI

struct WatchDailySongsView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator
    @EnvironmentObject private var account: WatchAccountStore

    let api: WatchNeteaseAPI

    @State private var phase: WatchPagePhase<[WatchSong]> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle, .loading:
                ProgressView("正在载入")
            case .failed(let message):
                ContentUnavailableView(
                    "无法载入每日推荐",
                    systemImage: "calendar.badge.exclamationmark",
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
                    .disabled(songs.isEmpty)

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
        .navigationTitle("每日推荐")
        .task {
            await load()
        }
    }

    private func load() async {
        guard account.isLoggedIn else {
            phase = .failed("请先同步 iPhone 登录，或在手表上使用二维码登录。")
            return
        }
        phase = .loading
        do {
            phase = .loaded(try await api.dailySongs())
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
