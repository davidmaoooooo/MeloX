import SwiftUI

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(AppSettings.self) private var settings

    private let fixedPage: LibraryPage?
    private let showsNavigationTitle: Bool

    @State private var section: LibraryPage
    @State private var hasAppliedInitialPage = false
    @State private var showsLogin = false
    @State private var searchQuery = ""

    init(
        fixedPage: LibraryPage? = nil,
        showsNavigationTitle: Bool = true
    ) {
        let resolvedFixedPage = fixedPage.flatMap { page in
            LibraryPage.availableCases.contains(page) ? page : nil
        }
        self.fixedPage = resolvedFixedPage
        self.showsNavigationTitle = showsNavigationTitle
        _section = State(initialValue: resolvedFixedPage ?? .songs)
    }

    private var availablePages: [LibraryPage] {
        fixedPage.map { [$0] } ?? settings.embeddedLibraryPages
    }

    var body: some View {
        VStack(spacing: 0) {
            if fixedPage == nil, availablePages.count > 1 {
                Picker("音乐库分类", selection: $section) {
                    ForEach(availablePages) { item in
                        Text(item.title).tag(item)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.background)
            }

            if availablePages.isEmpty {
                ContentUnavailableView(
                    "音乐库页面均已拆分",
                    systemImage: "rectangle.3.group",
                    description: Text("可在“页面与标签栏”设置中调整页面归属。")
                )
            } else if section == .downloads {
                LibraryDownloadsView(searchQuery: searchQuery)
            } else if !library.isLoggedIn {
                loginUnavailableView
            } else if section == .cloud {
                CloudMusicView(searchQuery: searchQuery)
            } else {
                libraryContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .libraryNavigationTitle(
            fixedPage.map { AppTab(libraryPage: $0).title }
                ?? "音乐库",
            isPresented: showsNavigationTitle
        )
        .librarySearchable(
            text: $searchQuery,
            prompt: searchPrompt,
            isEnabled: canSearchCurrentPage
        )
        .onAppear {
            guard !hasAppliedInitialPage else { return }
            hasAppliedInitialPage = true
            if let fixedPage {
                section = fixedPage
            } else {
                section = availablePages.contains(settings.initialLibraryPage)
                    ? settings.initialLibraryPage
                    : availablePages.first ?? .songs
            }
        }
        .onChange(of: section) { _, page in
            if fixedPage == nil {
                settings.lastLibraryPage = page
            }
        }
        .onChange(of: availablePages) { _, pages in
            guard fixedPage == nil,
                  let firstPage = pages.first,
                  !pages.contains(section) else {
                return
            }
            section = firstPage
        }
        .sheet(isPresented: $showsLogin) {
            NavigationStack {
                NeteaseLoginView()
            }
        }
        .task(id: settings.cookie) {
            await library.refresh()
        }
        .alert(
            "音乐库操作失败",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { presented in
                    if !presented {
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
    }

    private var loginUnavailableView: some View {
        ContentUnavailableView {
            Label("需要登录", systemImage: "person.crop.circle.badge.exclamationmark")
        } description: {
            Text(
                AppFeatureAvailability.downloads
                    ? "登录后可读取收藏歌曲、歌单、订阅播客、音乐云盘和播放记录；已下载歌曲无需登录。"
                    : "登录后可读取收藏歌曲、歌单、订阅播客、音乐云盘和播放记录。"
            )
        } actions: {
            Button("登录网易云音乐") {
                showsLogin = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private var libraryContent: some View {
        switch library.phase {
        case .loading where library.profile == nil:
            ProgressView("正在读取音乐库")
        case .failed(let message) where library.profile == nil:
            ConnectionUnavailableView(message: message) {
                Task { await library.refresh(force: true) }
            }
        default:
            switch section {
            case .songs:
                LibrarySongsView(searchQuery: searchQuery)
            case .playlists:
                LibraryPlaylistsView(searchQuery: searchQuery)
            case .podcasts:
                SubscribedPodcastsView(searchQuery: searchQuery)
            case .downloads:
                LibraryDownloadsView(searchQuery: searchQuery)
            case .cloud:
                CloudMusicView(searchQuery: searchQuery)
            case .history:
                LibraryHistoryView(searchQuery: searchQuery)
            }
        }
    }

    private var canSearchCurrentPage: Bool {
        !availablePages.isEmpty
            && (section == .downloads || library.isLoggedIn)
    }

    private var searchPrompt: String {
        switch section {
        case .songs:
            "在收藏歌曲中搜索"
        case .playlists:
            "在收藏歌单中搜索"
        case .podcasts:
            "在订阅播客中搜索"
        case .downloads:
            AppFeatureAvailability.downloads
                ? "在下载歌曲中搜索"
                : "搜索歌曲"
        case .cloud:
            "在云盘歌曲中搜索"
        case .history:
            "在播放历史中搜索"
        }
    }
}

private extension View {
    @ViewBuilder
    func libraryNavigationTitle(
        _ title: String,
        isPresented: Bool
    ) -> some View {
        if isPresented {
            navigationTitle(title)
        } else {
            self
        }
    }

    @ViewBuilder
    func librarySearchable(
        text: Binding<String>,
        prompt: String,
        isEnabled: Bool
    ) -> some View {
        if isEnabled {
            searchable(
                text: text,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text(prompt)
            )
        } else {
            self
        }
    }
}
