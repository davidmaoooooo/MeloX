import SwiftUI

struct PlaylistDetailView: View {
    let id: Int
    private let initialPlaylist: Playlist
    private let prefersToplistLayout: Bool

    @Environment(NeteaseAPI.self) private var api
    @Environment(LibraryStore.self) private var library
    @Environment(DownloadStore.self) private var downloads
    @Environment(\.colorScheme) private var systemColorScheme
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.setTabViewBottomAccessorySuppressed)
    private var setTabViewBottomAccessorySuppressed

    @State private var playlist: Playlist?
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var artworkPalette: ArtworkDetailPalette?
    @State private var blurredBackdropImage: CGImage?
    @State private var searchQuery = ""
    @State private var loadedTrackOffset = 0
    @State private var isLoadingMoreTracks = false
    @State private var loadMoreTracksError: String?
    @State private var downloadCoordinator = PlaylistDownloadCoordinator()

    private let trackPageSize = 100

    init(playlist context: PlaylistRouteContext) {
        let cachedAssets = ArtworkAccentColorProvider.cachedDetailAssets(
            for: context.coverURLString.flatMap(URL.init(string:))
        )
        id = context.id
        initialPlaylist = context.playlistSummary
        prefersToplistLayout = false
        _artworkPalette = State(initialValue: cachedAssets?.palette)
        _blurredBackdropImage = State(
            initialValue: cachedAssets?.blurredBackdropImage
        )
    }

    init(toplist context: PlaylistRouteContext) {
        let cachedAssets = ArtworkAccentColorProvider.cachedDetailAssets(
            for: context.coverURLString.flatMap(URL.init(string:))
        )
        id = context.id
        initialPlaylist = context.playlistSummary
        prefersToplistLayout = true
        _artworkPalette = State(initialValue: cachedAssets?.palette)
        _blurredBackdropImage = State(
            initialValue: cachedAssets?.blurredBackdropImage
        )
    }

    var body: some View {
        PlaylistDetailContent(
            playlist: displayedPlaylist,
            toplistSummary: prefersToplistLayout ? initialPlaylist : nil,
            palette: resolvedPalette,
            blurredBackdropImage: blurredBackdropImage,
            searchQuery: searchQuery,
            isLoading: isInitialLoading,
            failureMessage: initialFailureMessage,
            hasMoreTracks: hasMoreTracks,
            loadedTrackOffset: loadedTrackOffset,
            isLoadingMoreTracks: isLoadingMoreTracks,
            loadMoreTracksError: loadMoreTracksError,
            downloadCoordinator: downloadCoordinator,
            onRetry: { reloadToken += 1 },
            onRefresh: { await load() },
            onLoadMore: { await loadMoreTracks() }
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchQuery,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: Text(prefersToplistLayout ? "在排行榜中搜索" : "在歌单中搜索")
        )
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(interfaceColorScheme, for: .navigationBar, .tabBar)
        .toolbar {
            if downloadCoordinator.isSelecting {
                downloadSelectionToolbar
            } else {
                playlistToolbar(for: displayedPlaylist)
            }
        }
        .toolbarVisibility(
            downloadCoordinator.isSelecting ? .hidden : .automatic,
            for: .tabBar
        )
        .environment(\.colorScheme, interfaceColorScheme)
        .onAppear {
            updateTabViewBottomAccessoryVisibility()
        }
        .onChange(of: downloadCoordinator.isSelecting) {
            updateTabViewBottomAccessoryVisibility()
        }
        .onDisappear {
            setTabViewBottomAccessorySuppressed(false)
        }
        .onChange(of: downloadableSongIDs) { _, songIDs in
            guard downloadCoordinator.isSelecting else { return }
            downloadCoordinator.retainSelection(in: Set(songIDs))
        }
        .task(id: reloadToken) {
            guard playlist == nil else { return }
            await load(waitingForNavigationTransition: true)
        }
        .task(id: artworkURL) {
            let transitionDelay = navigationTransitionDelay()
            defer { transitionDelay.cancel() }

            let loadedAssets = await ArtworkAccentColorProvider.shared.detailAssets(
                for: artworkURL,
                fallbackPrefersDarkAppearance: systemColorScheme == .dark
            )
            guard !Task.isCancelled else { return }
            let backdropAlreadyResolved = blurredBackdropImage != nil
                || loadedAssets.blurredBackdropImage == nil
            if artworkPalette == loadedAssets.palette,
               backdropAlreadyResolved {
                return
            }
            do {
                try await transitionDelay.value
            } catch {
                return
            }
            withAnimation(artworkTransitionAnimation) {
                artworkPalette = loadedAssets.palette
                blurredBackdropImage = loadedAssets.blurredBackdropImage
            }
        }
        .alert(
            "音乐库操作失败",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        library.clearError()
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {
                library.clearError()
            }
        } message: {
            Text(library.errorMessage ?? "未知错误")
        }
        .alert(
            "无法准备下载",
            isPresented: Binding(
                get: { downloadCoordinator.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        downloadCoordinator.clearError()
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {
                downloadCoordinator.clearError()
            }
        } message: {
            Text(downloadCoordinator.errorMessage ?? "无法读取歌单歌曲。")
        }
    }

    private var displayedPlaylist: Playlist {
        playlist ?? initialPlaylist
    }

    private var artworkURL: URL? {
        displayedPlaylist.artworkURL ?? initialPlaylist.artworkURL
    }

    private var resolvedPalette: ArtworkDetailPalette {
        artworkPalette
            ?? .fallback(prefersDarkAppearance: systemColorScheme == .dark)
    }

    private var interfaceColorScheme: ColorScheme {
        resolvedPalette.colorScheme
    }

    private var artworkTransitionAnimation: Animation? {
        accessibilityReduceMotion ? nil : .easeOut(duration: 0.18)
    }

    private var isInitialLoading: Bool {
        guard playlist == nil else { return false }
        if case .loading = phase {
            return true
        }
        return false
    }

    private var initialFailureMessage: String? {
        guard playlist == nil, case .failed(let message) = phase else { return nil }
        return message
    }

    private var hasMoreTracks: Bool {
        guard case .loaded = phase,
              let playlist,
              !playlist.trackIDs.isEmpty else {
            return false
        }
        return loadedTrackOffset < playlist.trackIDs.count
    }

    private var downloadableSongIDs: [Int] {
        let unavailableSongIDs = Set(downloads.downloads.map(\.id))
            .union(downloads.activeDownloads.keys)
        return PlaylistDownloadCoordinator.songIDs(in: displayedPlaylist)
            .filter { !unavailableSongIDs.contains($0) }
    }

    private var selectedDownloadCount: Int {
        downloadCoordinator.selectedSongIDs
            .intersection(downloadableSongIDs)
            .count
    }

    private var hasSelectedAllDownloadableSongs: Bool {
        let downloadableSongIDSet = Set(downloadableSongIDs)
        return !downloadableSongIDSet.isEmpty
            && downloadableSongIDSet.isSubset(
                of: downloadCoordinator.selectedSongIDs
            )
    }

    private func updateTabViewBottomAccessoryVisibility() {
        setTabViewBottomAccessorySuppressed(
            downloadCoordinator.isSelecting
        )
    }

    @ToolbarContentBuilder
    private func playlistToolbar(for playlist: Playlist) -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            if downloadCoordinator.isPreparing {
                ProgressView()
                    .accessibilityLabel(
                        "正在准备下载 \(downloadCoordinator.preparingSongCount) 首歌曲"
                    )
            }

            Menu {
                NeteaseShareMenuContent(resource: .playlist(playlist))
            } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .accessibilityLabel("分享歌单")

            Menu {
                Menu {
                    ForEach(MusicQuality.allCases) { quality in
                        Button(quality.title) {
                            startDownloadAll(quality: quality)
                        }
                    }
                } label: {
                    Label(
                        "下载全部（\(downloadableSongIDs.count) 首）",
                        systemImage: "arrow.down.circle"
                    )
                }
                .disabled(
                    downloadableSongIDs.isEmpty
                        || downloadCoordinator.isPreparing
                )

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        downloadCoordinator.beginSelection()
                    }
                } label: {
                    Label("多选", systemImage: "checklist")
                }
                .disabled(
                    downloadableSongIDs.isEmpty
                        || downloadCoordinator.isPreparing
                )

                Divider()

                Button {
                    library.toggle(playlist: playlist)
                } label: {
                    Label(
                        library.contains(playlist: playlist) ? "取消收藏" : "收藏歌单",
                        systemImage: library.contains(playlist: playlist) ? "checkmark" : "plus"
                    )
                }

                Button {
                    Task { await load() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            } label: {
                Image(systemName: "ellipsis")
            }
            .accessibilityLabel("更多")
        }
        .sharedBackgroundVisibility(.visible)
    }

    @ToolbarContentBuilder
    private var downloadSelectionToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("完成") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    downloadCoordinator.finishSelection()
                }
            }
            .disabled(downloadCoordinator.isPreparing)
        }

        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    downloadCoordinator.toggleAll(
                        songIDs: Set(downloadableSongIDs)
                    )
                }
            } label: {
                Label(
                    hasSelectedAllDownloadableSongs ? "取消全选" : "全选",
                    systemImage: hasSelectedAllDownloadableSongs
                        ? "checkmark.circle.fill"
                        : "checkmark.circle"
                )
            }
            .disabled(
                downloadableSongIDs.isEmpty
                    || downloadCoordinator.isPreparing
            )

            Spacer()

            if downloadCoordinator.isPreparing {
                ProgressView()
                    .accessibilityLabel(
                        "正在准备下载 \(downloadCoordinator.preparingSongCount) 首歌曲"
                    )
            } else {
                Menu {
                    ForEach(MusicQuality.allCases) { quality in
                        Button(quality.title) {
                            startSelectedDownloads(quality: quality)
                        }
                    }
                } label: {
                    Label(
                        "下载 \(selectedDownloadCount) 首",
                        systemImage: "arrow.down.circle"
                    )
                }
                .disabled(selectedDownloadCount == 0)
            }
        }
    }

    private func startDownloadAll(quality: MusicQuality) {
        let playlist = displayedPlaylist
        Task {
            await downloadCoordinator.downloadAll(
                in: playlist,
                quality: quality,
                api: api,
                downloads: downloads
            )
        }
    }

    private func startSelectedDownloads(quality: MusicQuality) {
        let playlist = displayedPlaylist
        Task {
            await downloadCoordinator.downloadSelection(
                in: playlist,
                quality: quality,
                api: api,
                downloads: downloads
            )
        }
    }

    private func load(
        waitingForNavigationTransition: Bool = false
    ) async {
        let transitionDelay = navigationTransitionDelay(
            isEnabled: waitingForNavigationTransition
        )
        defer { transitionDelay.cancel() }

        phase = .loading
        loadedTrackOffset = 0
        loadMoreTracksError = nil
        do {
            let loadedPlaylist = try await api.playlist(
                id: id,
                trackLimit: trackPageSize
            )
            try await transitionDelay.value
            playlist = loadedPlaylist
            loadedTrackOffset = min(
                trackPageSize,
                loadedPlaylist.trackIDs.count
            )
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func loadMoreTracks() async {
        guard let currentPlaylist = playlist,
              !isLoadingMoreTracks,
              loadedTrackOffset < currentPlaylist.trackIDs.count else {
            return
        }

        let requestedOffset = loadedTrackOffset
        let trackIDs = currentPlaylist.trackIDs.map(\.id)
        isLoadingMoreTracks = true
        loadMoreTracksError = nil
        defer {
            isLoadingMoreTracks = false
        }

        do {
            let page = try await api.songDetailsPage(
                ids: trackIDs,
                offset: requestedOffset,
                limit: trackPageSize
            )
            try Task.checkCancellation()
            guard playlist?.id == currentPlaylist.id,
                  loadedTrackOffset == requestedOffset else {
                return
            }

            var updatedPlaylist = playlist ?? currentPlaylist
            var loadedIDs = Set(updatedPlaylist.tracks.map(\.id))
            updatedPlaylist.tracks.append(
                contentsOf: page.songs.filter {
                    loadedIDs.insert($0.id).inserted
                }
            )
            playlist = updatedPlaylist
            loadedTrackOffset = page.nextOffset
        } catch is CancellationError {
            return
        } catch {
            loadMoreTracksError = error.localizedDescription
        }
    }

    private func navigationTransitionDelay(
        isEnabled: Bool = true
    ) -> Task<Void, Error> {
        Task {
            guard isEnabled else { return }
            try await Task.sleep(
                for: MusicNavigationTransitionTiming.settleDelay
            )
        }
    }
}
