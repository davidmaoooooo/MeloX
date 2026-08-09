import SwiftUI

struct DailySongsView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library

    @State private var songs: [Song] = []
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var isRefreshing = false
    @State private var refreshErrorMessage: String?

    var body: some View {
        Group {
            switch phase {
            case .loading:
                ProgressView("正在载入每日推荐")
            case .failed(let message):
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }
            case .loaded:
                List {
                    Section {
                        HStack {
                            Button {
                                Task { await player.playAll(songs) }
                            } label: {
                                Label("播放全部", systemImage: "play.fill")
                                    .font(.headline)
                            }
                            .buttonStyle(.plain)
                            .disabled(songs.isEmpty)

                            Spacer()

                            Button {
                                Task { await refresh() }
                            } label: {
                                HStack(spacing: 6) {
                                    if isRefreshing {
                                        ProgressView()
                                            .controlSize(.small)
                                    } else {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                    }

                                    Text(isRefreshing ? "更换中" : "换一批")
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(isRefreshing)
                            .accessibilityLabel(
                                isRefreshing
                                    ? "正在更换每日推荐"
                                    : "换一批每日推荐"
                            )
                            .accessibilityHint("请求一组新的每日推荐歌曲")
                        }
                    }
                    ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
                        Button {
                            Task { await player.play(song, in: songs) }
                        } label: {
                            TrackRowView(song: song, index: index, showsArtwork: true)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button {
                                library.toggle(song: song)
                            } label: {
                                Label("收藏", systemImage: library.contains(song: song) ? "heart.slash" : "heart")
                            }
                            .tint(.pink)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("每日推荐")
        .task(id: reloadToken) {
            guard phase != .loaded else { return }
            await load()
        }
        .alert(
            "无法换一批",
            isPresented: Binding(
                get: { refreshErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        refreshErrorMessage = nil
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {
                refreshErrorMessage = nil
            }
        } message: {
            Text(refreshErrorMessage ?? "请稍后重试。")
        }
    }

    private func load() async {
        phase = .loading
        do {
            songs = try await api.dailySongs()
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let refreshedSongs = try await api.dailySongs(afresh: true)
            try Task.checkCancellation()
            songs = refreshedSongs
        } catch is CancellationError {
            return
        } catch {
            refreshErrorMessage = error.localizedDescription
        }
    }
}
