import SwiftUI
import UniformTypeIdentifiers

struct CloudMusicView: View {
    let searchQuery: String

    @Environment(CloudMusicStore.self) private var cloud
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    @State private var showsFileImporter = false
    @State private var pendingDeletion: CloudSong?
    @State private var searchReloadToken = 0
    @State private var searchPreparationID: UUID?

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showsFileImporter = true
                    } label: {
                        if cloud.isUploading {
                            ProgressView()
                        } else {
                            Label("上传音乐", systemImage: "square.and.arrow.up")
                        }
                    }
                    .disabled(cloud.isUploading)
                    .accessibilityLabel(cloud.isUploading ? "正在上传音乐" : "上传音乐")
                }
            }
            .fileImporter(
                isPresented: $showsFileImporter,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await cloud.upload(fileAt: url) }
                case .failure(let error):
                    cloud.reportImportError(error)
                }
            }
            .confirmationDialog(
                "从音乐云盘删除？",
                isPresented: Binding(
                    get: { pendingDeletion != nil },
                    set: { isPresented in
                        if !isPresented { pendingDeletion = nil }
                    }
                ),
                titleVisibility: .visible,
                presenting: pendingDeletion
            ) { item in
                Button("删除“\(item.songName)”", role: .destructive) {
                    Task { await cloud.delete(item) }
                }
                Button("取消", role: .cancel) {}
            } message: { _ in
                Text("此操作会同时从网易云音乐账号中删除该云盘歌曲。")
            }
            .alert(
                "音乐云盘操作失败",
                isPresented: Binding(
                    get: { cloud.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented { cloud.clearError() }
                    }
                )
            ) {
                Button("好", role: .cancel) {
                    cloud.clearError()
                }
            } message: {
                Text(cloud.errorMessage ?? "未知错误")
            }
            .task(id: settings.cookie) {
                await cloud.refresh()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch cloud.phase {
        case .loading where cloud.items.isEmpty:
            ProgressView("正在读取音乐云盘")
        case .failed(let message) where cloud.items.isEmpty:
            ConnectionUnavailableView(message: message) {
                Task { await cloud.refresh(force: true) }
            }
        default:
            cloudList
        }
    }

    private var cloudList: some View {
        List {
            if cloud.isUploading {
                HStack(spacing: 12) {
                    ProgressView()
                    Text("正在上传音乐，请保持 MeloX 在前台")
                        .foregroundStyle(.secondary)
                }
            }

            if !displayedItems.isEmpty {
                Section {
                    Button {
                        Task { await player.playAll(displayedSongs) }
                    } label: {
                        Label(
                            isSearching ? "播放搜索结果" : "播放全部",
                            systemImage: "play.fill"
                        )
                    }
                } header: {
                    if isSearching {
                        Text("\(displayedItems.count) 个搜索结果")
                    } else if let quota = cloud.quotaDescription {
                        Text(quota)
                    } else {
                        Text("共 \(cloud.totalCount) 首歌曲")
                    }
                }
            }

            ForEach(displayedItems) { item in
                Button {
                    Task {
                        await player.play(
                            item.simpleSong,
                            in: displayedSongs
                        )
                    }
                } label: {
                    TrackRowView(song: item.simpleSong, showsArtwork: true)
                }
                .buttonStyle(.plain)
                .disabled(cloud.isDeleting(item))
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        pendingDeletion = item
                    } label: {
                        Label("从云盘删除", systemImage: "trash")
                    }
                }
                .task {
                    await cloud.loadMoreIfNeeded(after: item)
                }
            }

            paginationFooter
        }
        .listStyle(.plain)
        .refreshable {
            await cloud.refresh(force: true)
            if isSearching {
                await prepareSearchResults(debounced: false)
            }
        }
        .overlay {
            if displayedItems.isEmpty,
               !cloud.isUploading,
               !isPreparingSearchResults,
               !hasSearchLoadFailure {
                if isSearching {
                    ContentUnavailableView.search(
                        text: normalizedSearchQuery
                    )
                } else {
                    ContentUnavailableView {
                        Label(
                            "音乐云盘是空的",
                            systemImage: "externaldrive"
                        )
                    } description: {
                        Text(
                            "上传本地音频后，可在所有网易云音乐客户端中播放。"
                        )
                    } actions: {
                        Button("上传音乐") {
                            showsFileImporter = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .task(
            id: CloudMusicSearchRequest(
                query: normalizedSearchQuery,
                reloadToken: searchReloadToken
            )
        ) {
            await prepareSearchResults(debounced: true)
        }
    }

    private var normalizedSearchQuery: String {
        normalizedLibrarySearchQuery(searchQuery)
    }

    private var isSearching: Bool {
        !normalizedSearchQuery.isEmpty
    }

    private var displayedItems: [CloudSong] {
        filterCloudSongs(cloud.items, query: normalizedSearchQuery)
    }

    private var displayedSongs: [Song] {
        displayedItems.map(\.simpleSong)
    }

    private var isPreparingSearchResults: Bool {
        searchPreparationID != nil
    }

    private var hasSearchLoadFailure: Bool {
        isSearching && cloud.loadMoreError != nil && cloud.hasMore
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if isSearching, isPreparingSearchResults {
            HStack(spacing: 8) {
                ProgressView()
                Text("正在搜索全部云盘歌曲")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .listRowSeparator(.hidden)
        } else if let failureMessage = cloud.loadMoreError,
                  cloud.hasMore {
            VStack(spacing: 8) {
                Text(failureMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button(isSearching ? "重新搜索" : "重新加载") {
                    if isSearching {
                        searchReloadToken += 1
                    } else {
                        Task { await cloud.loadMore() }
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .listRowSeparator(.hidden)
        } else if !isSearching, cloud.isLoadingMore {
            HStack {
                Spacer()
                ProgressView("正在加载更多")
                Spacer()
            }
        }
    }

    private func prepareSearchResults(debounced: Bool) async {
        guard isSearching else {
            searchPreparationID = nil
            return
        }

        guard cloud.hasMore else { return }

        let preparationID = UUID()
        searchPreparationID = preparationID
        defer {
            if searchPreparationID == preparationID {
                searchPreparationID = nil
            }
        }

        if debounced {
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return
            }
        }

        guard !Task.isCancelled else { return }
        await cloud.loadRemaining()
    }
}

private struct CloudMusicSearchRequest: Hashable {
    let query: String
    let reloadToken: Int
}
