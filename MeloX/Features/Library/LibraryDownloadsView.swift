import SwiftUI

struct LibraryDownloadsView: View {
    let searchQuery: String

    @Environment(DownloadStore.self) private var downloads
    @Environment(PlayerStore.self) private var player

    var body: some View {
        List {
            if !isSearching {
                NavigationLink {
                    DownloadsView()
                } label: {
                    HStack {
                        Label("下载管理", systemImage: "arrow.down.circle")
                        Spacer()
                        Text(downloadManagementValue)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !activeDownloadSongs.isEmpty {
                Section("正在下载") {
                    ForEach(activeDownloadSongs) { song in
                        TrackRowView(song: song, showsArtwork: true)
                            .swipeActions {
                                Button(role: .destructive) {
                                    downloads.cancel(songID: song.id)
                                } label: {
                                    Label("取消", systemImage: "xmark")
                                }
                            }
                    }
                }
            }

            if !filteredDownloadedSongs.isEmpty {
                Button {
                    Task { await player.playAll(filteredDownloadedSongs) }
                } label: {
                    Label(
                        isSearching ? "播放搜索结果" : "播放全部",
                        systemImage: "play.fill"
                    )
                }
            }

            ForEach(filteredDownloads) { download in
                Button {
                    Task {
                        await player.play(
                            download.song,
                            in: filteredDownloadedSongs
                        )
                    }
                } label: {
                    TrackRowView(song: download.song, showsArtwork: true)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button(role: .destructive) {
                        downloads.remove(songID: download.id)
                    } label: {
                        Label("删除下载", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .overlay {
            if filteredDownloads.isEmpty,
               activeDownloadSongs.isEmpty {
                if isSearching {
                    ContentUnavailableView.search(
                        text: normalizedSearchQuery
                    )
                } else {
                    ContentUnavailableView(
                        "还没有下载歌曲",
                        systemImage: "arrow.down.circle",
                        description: Text(
                            "在歌曲的更多操作菜单中选择“下载歌曲”。"
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

    private var activeDownloadSongs: [Song] {
        filterMusicCollectionTracks(
            Array(downloads.activeSongs.values),
            query: normalizedSearchQuery
        ).sorted {
            $0.name.localizedCompare($1.name) == .orderedAscending
        }
    }

    private var filteredDownloads: [DownloadedSong] {
        let songIDs = Set(
            filterMusicCollectionTracks(
                downloads.downloadedSongs,
                query: normalizedSearchQuery
            ).map(\.id)
        )
        return downloads.downloads.filter { songIDs.contains($0.id) }
    }

    private var filteredDownloadedSongs: [Song] {
        filteredDownloads.map(\.song)
    }

    private var downloadManagementValue: String {
        if !downloads.activeDownloads.isEmpty {
            return "\(downloads.activeDownloads.count) 项进行中"
        }
        return downloads.totalByteCount.formatted(.byteCount(style: .file))
    }
}
