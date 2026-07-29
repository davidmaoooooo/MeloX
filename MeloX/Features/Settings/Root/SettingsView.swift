import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DownloadStore.self) private var downloads
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerStore.self) private var player

    @State private var searchText = ""
    @State private var showsResetConfirmation = false
    @State private var isResettingSettings = false

    private var visibleSections: [SettingsCatalogSection] {
        SettingsCatalog.filteredSections(matching: searchText)
    }

    private var showsAccount: Bool {
        SettingsCatalog.matchesAccount(searchText)
    }

    private var showsReset: Bool {
        SettingsCatalog.matchesReset(searchText)
    }

    private var systemPlaybackSummary: String {
        let enabledCount = [
            settings.systemNowPlayingLyricsEnabled,
            settings.lyricsNotifications.isEnabled,
            settings.lyricsLiveActivityEnabled,
        ]
        .filter { $0 }
        .count

        return enabledCount == 0 ? "均已关闭" : "\(enabledCount) 项开启"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                SettingsHomeHeader()
                    .padding(.bottom, 8)

                settingsContent
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 88)
        }
        .background(
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()
        )
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索设置")
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: SettingsRoute.self) { route in
            destination(for: route)
        }
        .confirmationDialog(
            "恢复播放器默认设置？",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("恢复默认设置", role: .destructive) {
                resetPlayerSettings()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("这会覆盖播放、歌词与扩展显示的自定义参数，但不会影响账号、下载和音乐数据。")
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        Group {
            if showsAccount {
                SettingsAccountSection()
            }

            ForEach(visibleSections) { section in
                SettingsHomeSectionCard(
                    section: section,
                    value: value(for:)
                )
            }

            if showsReset {
                SettingsHomeResetCard(
                    isResetting: isResettingSettings
                ) {
                    showsResetConfirmation = true
                }
            }

            if !showsAccount && visibleSections.isEmpty && !showsReset {
                ContentUnavailableView(
                    "没有找到设置",
                    systemImage: "magnifyingglass",
                    description: Text("换个关键词再试。")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
            }
        }
    }

    @ViewBuilder
    private func destination(
        for route: SettingsRoute
    ) -> some View {
        switch route {
        case .accountHome:
            if let profile = library.profile {
                AccountHomeView(
                    initialProfile: profile,
                    initialDetail: library.accountDetail,
                    initialPlaylists: library.favoritePlaylists
                )
            } else {
                ContentUnavailableView(
                    "账号信息不可用",
                    systemImage:
                        "person.crop.circle.badge.exclamationmark"
                )
            }
        case .playback:
            PlaybackSettingsView()
        case .playerAppearance:
            PlayerAppearanceSettingsView()
        case .lyrics:
            LyricsSettingsView()
        case .systemPlayback:
            SystemPlaybackSettingsView()
        case .general:
            GeneralSettingsView()
        case .tabLayout:
            TabLayoutSettingsView()
        case .content:
            ContentSettingsView()
        case .downloads:
            DownloadsView()
        case .skylineLyrics:
            SkylineLyricsSettingsView()
        case .floatingLyrics:
            FloatingLyricsSettingsView()
        case .developer:
            DeveloperSettingsView()
        case .about:
            AboutView()
        }
    }

    private func value(for route: SettingsRoute) -> String? {
        switch route {
        case .playback:
            settings.quality.title
        case .lyrics:
            settings.lyricsStyle.title
        case .systemPlayback:
            systemPlaybackSummary
        case .downloads:
            downloads.totalByteCount.formatted(.byteCount(style: .file))
        case .tabLayout:
            "\(settings.visibleTabs.count) 个标签页"
        case .general:
            settings.appearance.title
        case .developer:
            developerSettingsSummary
        case .about:
            Bundle.main.appVersion
        case .accountHome,
             .playerAppearance,
             .content,
             .skylineLyrics,
             .floatingLyrics:
            nil
        }
    }

    private var developerSettingsSummary: String {
        settings.beatNetDebugEnabled
            ? "调试面板已开启"
            : "调试面板已关闭"
    }

    private func resetPlayerSettings() {
        guard !isResettingSettings else { return }
        isResettingSettings = true

        Task { @MainActor in
            await PlayerSettingsResetter.reset(
                settings: settings,
                player: player
            )
            isResettingSettings = false
        }
    }
}
