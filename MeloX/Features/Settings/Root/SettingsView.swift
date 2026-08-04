import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings
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

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
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
        .navigationTitle("MeloX")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索设置")
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                SettingsHomeToolbarTitle()
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("关闭")
                .accessibilityHint("关闭账号与设置")
            }
        }
        .navigationDestination(for: SettingsRoute.self) { route in
            destination(for: route)
                .toolbar(.visible, for: .navigationBar)
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
            Text(
                AppFeatureAvailability.downloads
                    ? "这会覆盖播放、歌词与扩展显示的自定义参数，但不会影响账号、下载和音乐数据。"
                    : "这会覆盖播放、歌词与扩展显示的自定义参数，但不会影响账号和音乐数据。"
            )
        }
    }

    @ViewBuilder
    private var settingsContent: some View {
        Group {
            if showsAccount {
                SettingsAccountSection()
            }

            ForEach(visibleSections) { section in
                SettingsHomeSectionCard(section: section)
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
        case .storage:
            StorageManagementView()
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
