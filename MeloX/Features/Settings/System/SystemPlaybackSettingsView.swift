import SwiftUI
import UIKit

struct SystemPlaybackSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player
    @Environment(LyricsNotificationController.self)
    private var notifications
    @Environment(\.openURL) private var openURL

    @State private var showsNotificationPermissionAlert =
        false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle(
                    "在系统播放信息中显示歌词",
                    isOn: $settings.systemNowPlayingLyricsEnabled
                )

                if settings.systemNowPlayingLyricsEnabled {
                    LabeledContent("主标题格式") {
                        formatField(
                            "主标题格式",
                            text:
                                $settings
                                    .systemNowPlayingLyricsTitleFormat
                        )
                    }

                    LabeledContent("副标题格式") {
                        formatField(
                            "副标题格式",
                            text:
                                $settings
                                    .systemNowPlayingLyricsSubtitleFormat
                        )
                    }
                }
            } header: {
                Text("系统播放信息")
            } footer: {
                Text("控制中心和锁定屏幕会使用当前歌词更新播放信息；关闭后恢复标准歌名与作者。")
            }

            Section {
                Toggle(
                    "通知歌词",
                    isOn: lyricsNotificationEnabledBinding
                )
                .disabled(
                    notifications.isRequestingAuthorization
                )

                if settings.lyricsNotifications.isEnabled {
                    NavigationLink {
                        LyricsNotificationSettingsView()
                    } label: {
                        Label(
                            "通知歌词设置",
                            systemImage: "bell.badge"
                        )
                    }

                    if notifications.authorizationStatus
                        == .denied {
                        Label(
                            "系统通知权限已关闭",
                            systemImage: "bell.slash.fill"
                        )
                        .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("通知歌词")
            } footer: {
                Text("歌词更新时撤回上一条通知并弹出新的静音横幅；可分别控制前台与后台显示。")
            }

            Section {
                Toggle(
                    "实时活动歌词（实验性）",
                    isOn: $settings.lyricsLiveActivityEnabled
                )

                if settings.lyricsLiveActivityEnabled {
                    NavigationLink {
                        LyricsLiveActivitySettingsView()
                    } label: {
                        Label(
                            "实时活动显示设置",
                            systemImage: "waveform.and.magnifyingglass"
                        )
                    }
                }
            } header: {
                Text("实时活动")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "实验性功能，当前版本仍不稳定。",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)

                    Text("可能出现歌词更新延迟、显示异常，或被系统提前结束；它与系统播放信息可以独立开启。")
                }
            }

            Section {
                Text("文字格式支持 {歌词}、{歌名}、{作者} 占位符；留空时会自动使用默认格式。")
                    .foregroundStyle(.secondary)
            } header: {
                Text("格式说明")
            }
        }
        .navigationTitle("系统歌词显示")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notifications.refreshAuthorizationStatus()
        }
        .onChange(of: settings.systemNowPlayingLyricsEnabled) {
            player.applySystemNowPlayingLyricsPreference()
        }
        .onChange(of: settings.systemNowPlayingLyricsTitleFormat) {
            player.applySystemNowPlayingLyricsPreference()
        }
        .onChange(of: settings.systemNowPlayingLyricsSubtitleFormat) {
            player.applySystemNowPlayingLyricsPreference()
        }
        .onChange(of: settings.lyricsLiveActivityEnabled) {
            player.applyLyricsLiveActivityPreference()
        }
        .alert(
            "无法开启通知歌词",
            isPresented:
                $showsNotificationPermissionAlert
        ) {
            Button("打开系统设置") {
                openNotificationSettings()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("请先在系统设置中允许 MeloX 显示通知。通知歌词始终不会播放提示音。")
        }
    }

    private var lyricsNotificationEnabledBinding:
        Binding<Bool>
    {
        Binding {
            settings.lyricsNotifications.isEnabled
        } set: { isEnabled in
            if !isEnabled {
                settings.lyricsNotifications.isEnabled = false
                player.applyLyricsNotificationPreference()
                return
            }

            Task { @MainActor in
                guard await notifications
                    .requestAuthorization() else {
                    settings.lyricsNotifications.isEnabled =
                        false
                    showsNotificationPermissionAlert = true
                    return
                }
                settings.lyricsNotifications.isEnabled = true
                player.applyLyricsNotificationPreference()
            }
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(
            string:
                UIApplication
                    .openNotificationSettingsURLString
        ) else {
            return
        }
        openURL(url)
    }

    private func formatField(
        _ title: String,
        text: Binding<String>
    ) -> some View {
        TextField(title, text: text)
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
    }
}
