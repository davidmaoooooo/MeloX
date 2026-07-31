import SwiftUI

struct LibraryPlaylistsView: View {
    let searchQuery: String

    @Environment(LibraryStore.self) private var library

    var body: some View {
        List(displayedPlaylists) { playlist in
            NavigationLink(value: MusicRoute.playlist(playlist)) {
                LibraryPlaylistRow(playlist: playlist)
            }
            .musicMatchedTransitionSource(for: MusicRoute.playlist(playlist))
            .swipeActions(edge: .trailing) {
                if library.canUnsubscribe(playlist) {
                    Button(role: .destructive) {
                        library.toggle(playlist: playlist)
                    } label: {
                        Label("取消收藏", systemImage: "heart.slash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await library.refresh(force: true)
        }
        .overlay {
            if displayedPlaylists.isEmpty {
                if isSearching {
                    ContentUnavailableView.search(
                        text: normalizedSearchQuery
                    )
                } else {
                    ContentUnavailableView(
                        "还没有收藏歌单",
                        systemImage: "music.note.list",
                        description: Text(
                            "打开歌单详情后，轻点收藏按钮。"
                        )
                    )
                }
            }
        }
    }

    private var normalizedSearchQuery: String {
        normalizedLibrarySearchQuery(searchQuery)
    }

    private var isSearching: Bool {
        !normalizedSearchQuery.isEmpty
    }

    private var displayedPlaylists: [Playlist] {
        filterLibraryPlaylists(
            library.favoritePlaylists,
            query: normalizedSearchQuery
        )
    }
}

private struct LibraryPlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: playlist.artworkURL, cornerRadius: 7)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .lineLimit(1)
                Text("\(playlist.trackCount) 首歌曲")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
