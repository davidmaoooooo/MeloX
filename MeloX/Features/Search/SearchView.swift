import SwiftUI

struct SearchView: View {
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(AppSettings.self) private var settings

    @State private var query = ""
    @State private var scope: SearchKind = .songs
    @State private var phase: LoadingPhase = .loaded
    @State private var songs: [Song] = []
    @State private var albums: [Album] = []
    @State private var artists: [Artist] = []
    @State private var playlists: [Playlist] = []
    @State private var podcasts: [Podcast] = []
    @State private var completedRequest: SearchRequest?
    @State private var recognizedLink: NeteaseMusicLink?
    @State private var linkedSong: Song?
    @State private var presentedListenTogetherLink:
        NeteaseListenTogetherLink?

    var body: some View {
        Group {
            if trimmedQuery.isEmpty {
                SearchDiscoveryView()
            } else if let recognizedLink {
                linkResult(for: recognizedLink)
            } else {
                searchResults
            }
        }
        .navigationTitle("搜索")
        .searchable(
            text: $query,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "音乐内容或网易云链接"
        )
        .searchScopes($scope) {
            ForEach(availableSearchKinds) { kind in
                Text(kind.title).tag(kind)
            }
        }
        .overlay {
            if !trimmedQuery.isEmpty, case .failed(let message) = phase {
                ContentUnavailableView(
                    recognizedLink == nil ? "搜索失败" : "无法打开链接",
                    systemImage: recognizedLink == nil
                        ? "exclamationmark.magnifyingglass"
                        : "link.badge.plus",
                    description: Text(message)
                )
            } else if recognizedLink == nil,
                      !trimmedQuery.isEmpty,
                      phase == .loaded,
                      resultIsEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .sheet(item: $presentedListenTogetherLink) { invitation in
            ListenTogetherView(
                invitationText: invitation.invitationText
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert(
            "收藏失败",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { if !$0 { library.clearError() } }
            )
        ) {
            Button("好", role: .cancel) {
                library.clearError()
            }
        } message: {
            Text(library.errorMessage ?? "未知错误")
        }
        .task(id: SearchRequest(query: query, kind: scope)) {
            let request = SearchRequest(query: query, kind: scope)
            guard completedRequest != request else { return }
            await search(request)
        }
        .onChange(
            of: settings.isContentFeatureEnabled(.podcasts)
        ) { _, podcastsEnabled in
            if !podcastsEnabled, scope == .podcasts {
                scope = .songs
            }
        }
    }

    private var availableSearchKinds: [SearchKind] {
        SearchKind.allCases.filter {
            $0 != .podcasts
                || settings.isContentFeatureEnabled(.podcasts)
        }
    }

    private var searchResults: some View {
        List {
            if phase == .loading {
                HStack {
                    Spacer()
                    ProgressView("搜索中")
                    Spacer()
                }
            }

            switch scope {
            case .songs:
                ForEach(songs) { song in
                    Button {
                        Task { await player.play(song, in: songs) }
                    } label: {
                        TrackRowView(song: song, showsArtwork: true)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing) {
                        Button {
                            library.toggle(song: song)
                        } label: {
                            Label(
                                library.contains(song: song) ? "取消收藏" : "收藏",
                                systemImage: library.contains(song: song) ? "heart.slash" : "heart"
                            )
                        }
                        .tint(.pink)
                    }
                }
            case .albums:
                ForEach(albums) { album in
                    NavigationLink(value: MusicRoute.album(album)) {
                        SearchMediaRow(
                            title: album.name,
                            subtitle: album.artistText,
                            artworkURL: album.artworkURL,
                            circular: false
                        )
                    }
                    .musicMatchedTransitionSource(for: MusicRoute.album(album))
                }
            case .artists:
                ForEach(artists) { artist in
                    NavigationLink(value: MusicRoute.artist(artist.id)) {
                        SearchMediaRow(
                            title: artist.name,
                            subtitle: artist.aliases.first,
                            artworkURL: artist.artworkURL,
                            circular: true
                        )
                    }
                    .musicMatchedTransitionSource(for: MusicRoute.artist(artist.id))
                }
            case .playlists:
                ForEach(playlists) { playlist in
                    NavigationLink(value: MusicRoute.playlist(playlist)) {
                        SearchMediaRow(
                            title: playlist.name,
                            subtitle: "\(playlist.trackCount) 首歌曲",
                            artworkURL: playlist.artworkURL,
                            circular: false
                        )
                    }
                    .musicMatchedTransitionSource(for: MusicRoute.playlist(playlist))
                }
            case .podcasts:
                ForEach(podcasts) { podcast in
                    NavigationLink(
                        value: MusicRoute.podcast(podcast)
                    ) {
                        PodcastListRow(podcast: podcast)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func linkResult(for link: NeteaseMusicLink) -> some View {
        switch link {
        case .song:
            List {
                if phase == .loading {
                    HStack {
                        Spacer()
                        ProgressView("正在读取歌曲链接")
                        Spacer()
                    }
                } else if let linkedSong {
                    Section("链接中的歌曲") {
                        NavigationLink(
                            value: MusicRoute.song(linkedSong)
                        ) {
                            TrackRowView(
                                song: linkedSong,
                                showsArtwork: true
                            )
                        }
                        .musicMatchedTransitionSource(
                            for: MusicRoute.song(linkedSong)
                        )
                    }
                }
            }
            .listStyle(.plain)

        case .listenTogether(let invitation):
            ContentUnavailableView {
                Label("一起听邀请", systemImage: "person.2.wave.2")
            } description: {
                Text("已识别网易云音乐一起听分享链接。")
            } actions: {
                Button("查看邀请") {
                    presentedListenTogetherLink = invitation
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var resultIsEmpty: Bool {
        switch scope {
        case .songs: songs.isEmpty
        case .albums: albums.isEmpty
        case .artists: artists.isEmpty
        case .playlists: playlists.isEmpty
        case .podcasts: podcasts.isEmpty
        }
    }

    private func search(_ request: SearchRequest) async {
        let keywords = request.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keywords.isEmpty else {
            clearResults()
            recognizedLink = nil
            linkedSong = nil
            phase = .loaded
            completedRequest = request
            return
        }

        if let link = NeteaseMusicLinkParser.parse(keywords) {
            await resolve(link, for: request)
            return
        }

        recognizedLink = nil
        linkedSong = nil
        phase = .loading
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        do {
            let result = try await api.search(keywords, kind: request.kind)
            guard !Task.isCancelled else { return }
            songs = result.songs ?? []
            albums = result.albums ?? []
            artists = result.artists ?? []
            playlists = result.playlists ?? []
            podcasts = result.podcasts ?? []

            if request.kind == .songs, !songs.isEmpty {
                let details = try? await api.songDetails(ids: songs.map(\.id))
                guard !Task.isCancelled else { return }
                if let details, !details.isEmpty {
                    songs = details
                }
            }
            phase = .loaded
            completedRequest = request
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func resolve(
        _ link: NeteaseMusicLink,
        for request: SearchRequest
    ) async {
        recognizedLink = link
        linkedSong = nil
        clearResults()

        switch link {
        case .song(let id):
            phase = .loading
            do {
                let details = try await api.songDetails(ids: [id])
                try Task.checkCancellation()
                guard let song = details.first else {
                    phase = .failed(
                        "网易云音乐没有返回这首歌曲的信息。"
                    )
                    return
                }
                linkedSong = song
                phase = .loaded
                completedRequest = request
            } catch is CancellationError {
                return
            } catch {
                phase = .failed(error.localizedDescription)
            }

        case .listenTogether:
            phase = .loaded
            completedRequest = request
        }
    }

    private func clearResults() {
        songs = []
        albums = []
        artists = []
        playlists = []
        podcasts = []
    }
}

private struct SearchRequest: Hashable {
    let query: String
    let kind: SearchKind
}

private struct SearchMediaRow: View {
    let title: String
    let subtitle: String?
    let artworkURL: URL?
    let circular: Bool

    var body: some View {
        HStack(spacing: 12) {
            ArtworkImage(url: artworkURL, cornerRadius: circular ? 1_000 : 7)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}
