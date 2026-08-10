import SwiftUI

struct DesktopPodcastCategoryView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let categoryID: Int
    let title: String

    @State private var podcasts: [Podcast] = []
    @State private var nextOffset = 0
    @State private var hasMore = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 145, maximum: 205), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(.system(size: 32, weight: .bold))
                    Spacer()
                    if !podcasts.isEmpty {
                        Text("\(podcasts.count) 个播客")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                    }
                }

                content
            }
            .padding(.horizontal, 34)
            .padding(.vertical, 28)
        }
        .navigationTitle(title)
        .desktopLoadingStatus(
            "正在载入\(title)…",
            isPresented: isLoading
        )
        .task(id: categoryID) {
            await reload()
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.28),
            value: podcasts.count
        )
    }

    @ViewBuilder
    private var content: some View {
        if podcasts.isEmpty, isLoading {
            Color.clear
                .frame(maxWidth: .infinity, minHeight: 320)
        } else if podcasts.isEmpty, let errorMessage {
            ContentUnavailableView {
                Label("无法载入播客", systemImage: "wifi.exclamationmark")
            } description: {
                Text(errorMessage)
            } actions: {
                Button("重试") { Task { await reload() } }
            }
            .frame(maxWidth: .infinity, minHeight: 320)
        } else if podcasts.isEmpty {
            ContentUnavailableView(
                "暂无播客",
                systemImage: "dot.radiowaves.left.and.right",
                description: Text("这个类别暂时没有可展示的节目。")
            )
            .frame(maxWidth: .infinity, minHeight: 320)
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 24) {
                ForEach(podcasts) { podcast in
                    DesktopMediaCard(
                        title: podcast.name,
                        subtitle: podcast.subtitle,
                        artworkURL: podcast.artworkURL,
                        action: {
                            model.ui.navigate(to: .podcast(podcast.id))
                        }
                    )
                }
            }

            paginationFooter
        }
    }

    @ViewBuilder
    private var paginationFooter: some View {
        if isLoading {
            Color.clear
                .frame(height: 37)
        } else if let errorMessage, !podcasts.isEmpty {
            Button("继续载入", systemImage: "arrow.clockwise") {
                Task { await loadNextPage() }
            }
            .help(errorMessage)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        } else if hasMore {
            Color.clear
                .frame(height: 1)
                .task { await loadNextPage() }
        }
    }

    private func reload() async {
        podcasts = []
        nextOffset = 0
        hasMore = true
        errorMessage = nil
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard !isLoading, hasMore else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let page = try await model.api.podcasts(
                categoryID: categoryID,
                offset: nextOffset,
                limit: 30
            )
            try Task.checkCancellation()

            var knownIDs = Set(podcasts.map(\.id))
            podcasts.append(
                contentsOf: page.podcasts.filter {
                    knownIDs.insert($0.id).inserted
                }
            )
            nextOffset += page.podcasts.count
            hasMore = page.hasMore && !page.podcasts.isEmpty
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
