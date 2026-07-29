import SwiftUI

struct SubscribedPodcastsView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        List {
            if library.subscribedPodcastTotalCount > 0 {
                Text(
                    "\(library.subscribedPodcastTotalCount) 个订阅播客"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .listRowSeparator(.hidden)
            }

            ForEach(library.subscribedPodcasts) { podcast in
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

            if library.hasMoreSubscribedPodcasts {
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
        }
        .overlay {
            if library.subscribedPodcasts.isEmpty,
               !library.hasMoreSubscribedPodcasts {
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
}
