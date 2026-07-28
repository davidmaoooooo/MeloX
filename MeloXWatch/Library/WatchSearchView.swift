import SwiftUI

struct WatchSearchView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator

    let api: WatchNeteaseAPI

    @State private var query = ""
    @State private var phase: WatchPagePhase<[WatchSong]> = .idle

    var body: some View {
        Group {
            switch phase {
            case .idle:
                ContentUnavailableView(
                    "搜索网易云音乐",
                    systemImage: "magnifyingglass",
                    description: Text("输入歌曲、歌手或专辑名称。")
                )
            case .loading:
                ProgressView("正在搜索")
            case .failed(let message):
                ContentUnavailableView(
                    "搜索失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            case .loaded(let songs):
                if songs.isEmpty {
                    ContentUnavailableView.search(text: query)
                } else {
                    List(songs) { song in
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
        .navigationTitle("搜索")
        .searchable(text: $query, prompt: "歌曲、歌手或专辑")
        .onSubmit(of: .search) {
            Task { await search() }
        }
    }

    private func search() async {
        let keywords = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !keywords.isEmpty else {
            phase = .idle
            return
        }
        phase = .loading
        do {
            phase = .loaded(try await api.searchSongs(keywords))
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}

struct WatchSongLabel: View {
    let song: WatchSong

    var body: some View {
        HStack(spacing: 8) {
            AsyncImage(url: song.album?.artworkURL) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    Image(systemName: "music.note")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.quaternary)
                }
            }
            .frame(width: 34, height: 34)
            .clipShape(.rect(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(song.name)
                    .font(.body)
                    .lineLimit(1)
                Text(song.artistText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}
