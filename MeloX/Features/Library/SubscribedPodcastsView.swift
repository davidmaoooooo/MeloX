import SwiftUI

struct SubscribedPodcastsView: View {
    let searchQuery: String

    @Environment(LibraryStore.self) private var library

    @State private var searchReloadToken = 0
    @State private var searchPreparationID: UUID?

    var body: some View {
        List {
            if !displayedPodcasts.isEmpty {
                Text(
                    isSearching
                        ? "\(displayedPodcasts.count) 个搜索结果"
                        : "\(library.subscribedPodcastTotalCount) 个订阅播客"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)
            }

            ForEach(displayedPodcasts) { podcast in
                NavigationLink(
                    value: MusicRoute.podcast(podcast)
                ) {
                    PodcastListRow(podcast: podcast)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        library.toggle(podcast: podcast)
                    } label: {
                        Label(
                            "取消订阅",
                            systemImage: "mic.slash"
                        )
                    }
                }
            }

            if isSearching {
                searchPaginationFooter
            } else if library.hasMoreSubscribedPodcasts {
                MusicCollectionPaginationFooter(
                    isLoading:
                        library.isLoadingMoreSubscribedPodcasts,
                    failureMessage:
                        library.subscribedPodcastsLoadMoreError,
                    loadToken:
                        library.subscribedPodcastsNextOffset,
                    loadingTitle: "正在加载更多播客"
                ) {
                    await library.loadMoreSubscribedPodcasts()
                }
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await library.refresh(force: true)
            if isSearching {
                await prepareSearchResults(debounced: false)
            }
        }
        .overlay {
            if displayedPodcasts.isEmpty,
               !isPreparingSearchResults,
               !hasSearchLoadFailure {
                if isSearching {
                    ContentUnavailableView.search(
                        text: normalizedSearchQuery
                    )
                } else if !library.hasMoreSubscribedPodcasts {
                    ContentUnavailableView(
                        "还没有订阅播客",
                        systemImage: "mic",
                        description: Text(
                            "打开播客详情后，轻点订阅按钮。"
                        )
                    )
                }
            }
        }
        .task(
            id: LibraryPodcastSearchRequest(
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

    private var displayedPodcasts: [Podcast] {
        filterLibraryPodcasts(
            library.subscribedPodcasts,
            query: normalizedSearchQuery
        )
    }

    private var isPreparingSearchResults: Bool {
        searchPreparationID != nil
    }

    private var hasSearchLoadFailure: Bool {
        isSearching
            && library.subscribedPodcastsLoadMoreError != nil
            && library.hasMoreSubscribedPodcasts
    }

    @ViewBuilder
    private var searchPaginationFooter: some View {
        if isPreparingSearchResults {
            HStack(spacing: 8) {
                ProgressView()
                Text("正在搜索全部订阅播客")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .listRowSeparator(.hidden)
        } else if let failureMessage =
                    library.subscribedPodcastsLoadMoreError,
                  library.hasMoreSubscribedPodcasts {
            VStack(spacing: 8) {
                Text(failureMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button("重新搜索") {
                    searchReloadToken += 1
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .listRowSeparator(.hidden)
        }
    }

    private func prepareSearchResults(debounced: Bool) async {
        guard isSearching else {
            searchPreparationID = nil
            return
        }

        guard library.hasMoreSubscribedPodcasts else { return }

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
        await library.loadRemainingSubscribedPodcasts()
    }
}

private struct LibraryPodcastSearchRequest: Hashable {
    let query: String
    let reloadToken: Int
}
