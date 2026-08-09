import SwiftUI

struct DesktopPodcastDetailView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let podcastID: Int

    @State private var podcast: Podcast?
    @State private var programs: [PodcastProgram] = []
    @State private var order: PodcastProgramOrder = .newest
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var songs: [Song] { programs.compactMap(\.playbackSong) }

    var body: some View {
        Group {
            if let podcast {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 32) {
                        DesktopCollectionHeader(
                            artworkURL: podcast.artworkURL,
                            kind: "播客",
                            title: podcast.name,
                            subtitle: podcast.host?.nickname,
                            metadata: "\(podcast.programCount) 期 · \(podcast.subscriberCount.formatted()) 位订阅者",
                            description: podcast.podcastDescription,
                            songs: songs,
                            sourceID: podcast.id,
                            isFavorite: model.library.contains(podcast: podcast),
                            favoriteAction: {
                                model.library.toggle(podcast: podcast)
                            },
                            shareURL: URL(
                                string: "https://music.163.com/#/djradio?id=\(podcast.id)"
                            )
                        )

                        HStack {
                            DesktopSectionHeader(title: "节目")
                            Spacer()
                            Picker("顺序", selection: $order) {
                                ForEach(PodcastProgramOrder.allCases) { order in
                                    Text(order.title).tag(order)
                                }
                            }
                            .frame(width: 150)
                            .onChange(of: order) { Task { await loadPrograms() } }
                        }

                        LazyVStack(spacing: 2) {
                            ForEach(Array(programs.enumerated()), id: \.element.id) { index, program in
                                if let song = program.playbackSong {
                                    DesktopTrackRow(
                                        song: song,
                                        index: index,
                                        songs: songs,
                                        sourceID: podcast.id,
                                        showsArtwork: true
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 42)
                    .padding(.vertical, 34)
                }
            } else if isLoading {
                DesktopDetailLoadingView(message: "正在载入播客…")
            } else {
                DesktopDetailErrorView(message: errorMessage ?? "未知错误") {
                    Task { await load() }
                }
            }
        }
        .navigationTitle(podcast?.name ?? "播客")
        .task(id: podcastID) { await load() }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.30),
            value: isLoading
        )
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            podcast = try await model.api.podcast(id: podcastID)
            await loadPrograms()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func loadPrograms() async {
        do {
            var loaded: [PodcastProgram] = []
            var offset = 0
            while true {
                let page = try await model.api.podcastPrograms(
                    radioID: podcastID,
                    offset: offset,
                    limit: 50,
                    ascending: order.ascending
                )
                loaded.append(contentsOf: page.programs)
                guard page.hasMore, !page.programs.isEmpty else { break }
                offset += page.programs.count
            }
            programs = loaded
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
