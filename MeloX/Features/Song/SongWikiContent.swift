import SwiftUI

struct SongWikiContent: View {
    let song: Song
    let wiki: SongWiki

    var body: some View {
        List {
            songSummary
            memorySection
            tagSection
            attributeSection

            ForEach(wiki.associationGroups) { group in
                associationSection(group)
            }

            reviewSection
            similarSongsSection
            relatedPlaylistsSection
            contributionSection
        }
        .listStyle(.insetGrouped)
    }

    private var songSummary: some View {
        Section {
            HStack(spacing: 12) {
                ArtworkImage(
                    url: song.album?.artworkURL,
                    cornerRadius: 8
                )
                .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 3) {
                    Text(song.name)
                        .font(.headline)
                        .lineLimit(2)

                    if !song.artistText.isEmpty {
                        Text(song.artistText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    @ViewBuilder
    private var memorySection: some View {
        if !wiki.memories.isEmpty {
            Section("回忆坐标") {
                ForEach(wiki.memories) { memory in
                    LabeledContent(memory.title) {
                        Text(memory.value)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var tagSection: some View {
        if !wiki.tagGroups.isEmpty {
            Section("歌曲标签") {
                ForEach(wiki.tagGroups) { group in
                    LabeledContent(group.title) {
                        Text(group.values.joined(separator: "、"))
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var attributeSection: some View {
        if !wiki.attributes.isEmpty {
            Section("基础信息") {
                ForEach(wiki.attributes) { attribute in
                    LabeledContent(attribute.title) {
                        Text(attribute.value)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
        }
    }

    private func associationSection(
        _ group: SongWikiAssociationGroup
    ) -> some View {
        Section {
            ForEach(group.details) { detail in
                VStack(alignment: .leading, spacing: 4) {
                    if let title = detail.title {
                        Text(title)
                            .font(.body)
                    }
                    if let subtitle = detail.subtitle {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let body = detail.body {
                        Text(body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            HStack {
                Text(group.title)
                Spacer()
                if let countText = group.countText {
                    Text(countText)
                }
            }
        }
    }

    @ViewBuilder
    private var reviewSection: some View {
        if !wiki.reviews.isEmpty {
            Section("精选乐评") {
                ForEach(wiki.reviews) { review in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(review.body)
                            .fixedSize(horizontal: false, vertical: true)
                        if let attribution = review.attribution {
                            Text(attribution)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var similarSongsSection: some View {
        if !wiki.similarSongs.isEmpty {
            Section("相似歌曲") {
                ForEach(wiki.similarSongs) { reference in
                    NavigationLink {
                        SongWikiRelatedSongDestination(
                            reference: reference
                        )
                    } label: {
                        HStack(spacing: 12) {
                            ArtworkImage(
                                url: reference.artworkURL,
                                cornerRadius: 6
                            )
                            .frame(width: 46, height: 46)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(reference.title)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)

                                if let artist = reference.artist {
                                    Text(artist)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                if let note = reference.note {
                                    Text(note)
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var relatedPlaylistsSection: some View {
        if !wiki.relatedPlaylists.isEmpty {
            Section("相关歌单") {
                ForEach(wiki.relatedPlaylists) { reference in
                    let route = MusicRoute.playlist(
                        reference.playlist
                    )
                    NavigationLink(value: route) {
                        HStack(spacing: 12) {
                            ArtworkImage(
                                url: reference.artworkURL,
                                cornerRadius: 6
                            )
                            .frame(width: 46, height: 46)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(reference.title)
                                    .foregroundStyle(.primary)
                                    .lineLimit(2)

                                if reference.playCount > 0 {
                                    Text(
                                        "\(reference.playCount.formatted()) 次播放"
                                    )
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                    .musicMatchedTransitionSource(for: route)
                }
            }
        }
    }

    @ViewBuilder
    private var contributionSection: some View {
        if let url = wiki.contributionURL {
            Section("更多") {
                Link(destination: url) {
                    Label(
                        "参与百科共建",
                        systemImage: "square.and.pencil"
                    )
                }
            }
        }
    }
}

private struct SongWikiRelatedSongDestination: View {
    @Environment(NeteaseAPI.self) private var api

    let reference: SongWikiSongReference

    @State private var song: Song?
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0

    var body: some View {
        Group {
            if let song {
                SongDetailView(song: song)
            } else {
                switch phase {
                case .loading:
                    ProgressView("正在载入歌曲")
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                case .failed(let message):
                    ConnectionUnavailableView(message: message) {
                        reloadToken += 1
                    }
                case .loaded:
                    ContentUnavailableView(
                        "歌曲资料不可用",
                        systemImage: "music.note"
                    )
                }
            }
        }
        .navigationTitle(reference.title)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reloadToken) {
            await load()
        }
    }

    private func load() async {
        phase = .loading
        do {
            let details = try await api.songDetails(ids: [reference.id])
            try Task.checkCancellation()
            guard let loadedSong = details.first else {
                throw APIError.invalidResponse
            }
            song = loadedSong
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
