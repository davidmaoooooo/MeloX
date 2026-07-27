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
            settings.lyricsLiveActivityEnabled,
        ]
        .filter { $0 }
        .count

        return enabledCount == 0 ? "均已关闭" : "\(enabledCount) 项开启"
    }

    var body: some View {
        List {
            if showsAccount {
                SettingsAccountSection()
            }

            ForEach(visibleSections) { section in
                Section(section.title) {
                    ForEach(section.items, id: \.route) { item in
                        NavigationLink(value: item.route) {
                            HStack(spacing: 12) {
                                Label {
                                    VStack(
                                        alignment: .leading,
                                        spacing: 3
                                    ) {
                                        Text(item.title)

                                        Text(item.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(
                                                horizontal: false,
                                                vertical: true
                                            )
                                    }
                                } icon: {
                                    Image(systemName: item.systemImage)
                                }

                                Spacer(minLength: 8)

                                if let value = value(for: item.route) {
                                    Text(value)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }

            if showsReset {
                Section {
                    Button(
                        "恢复播放器默认设置",
                        systemImage: "arrow.counterclockwise",
                        role: .destructive
                    ) {
                        showsResetConfirmation = true
                    }
                    .disabled(isResettingSettings)
                } header: {
                    Text("还原")
                } footer: {
                    Text("重置播放、歌词、均衡器、自动混音和扩展歌词显示，不会删除账号、下载或音乐数据。")
                }
            }

            if !showsAccount && visibleSections.isEmpty && !showsReset {
                ContentUnavailableView(
                    "没有找到设置",
                    systemImage: "magnifyingglass",
                    description: Text("换个关键词再试。")
                )
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
        .searchable(text: $searchText, prompt: "搜索设置")
        .navigationDestination(for: SettingsRoute.self) { route in
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
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                }
            case .privateMessages:
                NeteasePrivateMessagesView()
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
            case .content:
                ContentSettingsView()
            case .downloads:
                DownloadsView()
            case .skylineLyrics:
                SkylineLyricsSettingsView()
            case .floatingLyrics:
                FloatingLyricsSettingsView()
            case .about:
                AboutView()
            }
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
        case .general:
            settings.appearance.title
        case .about:
            Bundle.main.appVersion
        case .accountHome,
             .privateMessages,
             .playerAppearance,
             .content,
             .skylineLyrics,
             .floatingLyrics:
            nil
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
