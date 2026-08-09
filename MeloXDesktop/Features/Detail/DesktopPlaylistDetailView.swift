import SwiftUI

struct DesktopPlaylistDetailView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let playlistID: Int

    @State private var playlist: Playlist?
    @State private var songs: [Song] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let playlist {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 34) {
                        DesktopCollectionHeader(
                            artworkURL: playlist.artworkURL,
                            kind: playlist.isOfficialToplist ? "排行榜" : "播放列表",
                            title: playlist.name,
                            subtitle: playlist.creator?.nickname,
                            metadata: metadata(for: playlist),
                            description: playlist.playlistDescription,
                            songs: songs,
                            sourceID: playlist.id,
                            isFavorite: model.library.contains(playlist: playlist),
                            favoriteAction: {
                                model.library.toggle(playlist: playlist)
                            },
                            shareURL: URL(
                                string: "https://music.163.com/#/playlist?id=\(playlist.id)"
                            )
                        )

                        Divider()
                        DesktopCollectionTrackList(songs: songs, sourceID: playlist.id)
                    }
                    .padding(.horizontal, 42)
                    .padding(.vertical, 34)
                }
            } else if isLoading {
                DesktopDetailLoadingView(message: "正在载入播放列表…")
            } else {
                DesktopDetailErrorView(message: errorMessage ?? "未知错误") {
                    Task { await load() }
                }
            }
        }
        .navigationTitle(playlist?.name ?? "播放列表")
        .task(id: playlistID) { await load() }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.30),
            value: isLoading
        )
    }

    private func metadata(for playlist: Playlist) -> String {
        var parts = ["\(playlist.trackCount) 首歌曲"]
        if model.settings.showPlayCount {
            parts.append("\(playlist.playCount.formatted()) 次播放")
        }
        return parts.joined(separator: " · ")
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            var detail = try await model.api.playlist(id: playlistID, trackLimit: 100)
            var loadedSongs = detail.tracks
            if detail.trackIDs.count > loadedSongs.count {
                let ids = detail.trackIDs.map(\.id)
                var offset = loadedSongs.count
                while offset < ids.count {
                    let page = try await model.api.songDetailsPage(ids: ids, offset: offset)
                    loadedSongs.append(contentsOf: page.songs)
                    guard page.nextOffset > offset else { break }
                    offset = page.nextOffset
                }
            }
            detail.tracks = loadedSongs
            playlist = detail
            songs = loadedSongs
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
