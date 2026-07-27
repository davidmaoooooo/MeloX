import SwiftUI
import UIKit

struct LyricsNotificationSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player
    @Environment(LyricsNotificationController.self)
    private var notifications
    @Environment(\.openURL) private var openURL

    private var permissionStatus:
        LyricsNotificationAuthorizationStatus
    {
        notifications.authorizationStatus
    }

    var body: some View {
        @Bindable var preferences =
            settings.lyricsNotifications
        let deliveryPreferences =
            LyricsNotificationDeliveryPreferences(
                preferences: preferences
            )
        let contentPreferences =
            LyricsNotificationContentPreferences(
                preferences: preferences
            )

        Form {
            Section {
                LabeledContent("通知权限") {
                    Label(
                        permissionStatus.title,
                        systemImage:
                            permissionStatus.systemImage
                    )
                    .foregroundStyle(
                        permissionStatus == .denied
                            ? .red
                            : .secondary
                    )
                }

                if permissionStatus == .denied {
                    Button(
                        "打开系统通知设置",
                        systemImage: "gear"
                    ) {
                        openNotificationSettings()
                    }
                }
            } header: {
                Text("权限")
            } footer: {
                Text("MeloX 只申请横幅通知权限，不申请提示音权限。")
            }

            Section {
                LabeledContent("标题格式") {
                    formatField(
                        "标题格式",
                        text: $preferences.titleFormat
                    )
                }

                Toggle(
                    "显示副标题",
                    isOn: $preferences.showsSubtitle
                )

                if preferences.showsSubtitle {
                    LabeledContent("副标题格式") {
                        formatField(
                            "副标题格式",
                            text:
                                $preferences.subtitleFormat
                        )
                    }
                }

                Toggle(
                    "显示歌曲封面",
                    isOn: $preferences.showsArtwork
                )

                Picker(
                    "正文内容",
                    selection:
                        $preferences.supplementaryContent
                ) {
                    ForEach(
                        LyricsNotificationSupplementaryContent
                            .allCases
                    ) { content in
                        Text(content.title).tag(content)
                    }
                }

                Toggle(
                    "无歌词时显示歌曲信息",
                    isOn:
                        $preferences
                            .showsTrackInfoWhenLyricsUnavailable
                )
            } header: {
                Text("通知内容")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("标题与副标题支持 {歌词}、{歌名}、{作者} 占位符；翻译或下一句不可用时会自动省略。")
                    Text("系统仍会显示 MeloX 应用图标；歌曲封面将作为通知图片附件，加载失败时自动使用纯文字通知。")
                }
            }

            Section {
                Toggle(
                    "在 MeloX 前台弹出",
                    isOn:
                        $preferences.showsInForeground
                )

                Toggle(
                    "在后台播放时弹出",
                    isOn:
                        $preferences.showsInBackground
                )

                if !preferences.showsInForeground
                    && !preferences.showsInBackground {
                    Label(
                        "当前不会在任何场景显示通知歌词",
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                }
            } header: {
                Text("显示场景")
            }

            Section {
                Toggle(
                    "暂停时撤回通知",
                    isOn:
                        $preferences.removesWhenPaused
                )
            } header: {
                Text("通知行为")
            } footer: {
                Text("每次歌词更新都会先撤回上一条，再发布新的静音横幅；通知中心始终只保留最新歌词。")
            }

            Section {
                Button(
                    "发送测试通知",
                    systemImage: "bell.badge"
                ) {
                    presentPreview()
                }
                .disabled(
                    notifications.isRequestingAuthorization
                )
            } footer: {
                if let error =
                    notifications.lastErrorDescription {
                    Text(error)
                        .foregroundStyle(.red)
                } else {
                    Text("测试通知使用当前歌曲与歌词；没有正在播放的歌曲时会使用示例内容。")
                }
            }
        }
        .navigationTitle("通知歌词")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await notifications.refreshAuthorizationStatus()
        }
        .onChange(of: deliveryPreferences) {
            player.refreshLyricsNotification()
        }
        .onChange(of: contentPreferences) {
            player.applyLyricsNotificationPreference()
        }
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
            .submitLabel(.done)
            .onSubmit {
                player.applyLyricsNotificationPreference()
            }
    }

    private func presentPreview() {
        Task { @MainActor in
            guard await notifications
                .requestAuthorization() else {
                return
            }
            player.presentLyricsNotificationPreview()
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
}

private struct LyricsNotificationContentPreferences:
    Equatable
{
    let showsSubtitle: Bool
    let showsArtwork: Bool
    let supplementaryContent:
        LyricsNotificationSupplementaryContent

    init(preferences: LyricsNotificationPreferences) {
        showsSubtitle = preferences.showsSubtitle
        showsArtwork = preferences.showsArtwork
        supplementaryContent =
            preferences.supplementaryContent
    }
}

private struct LyricsNotificationDeliveryPreferences:
    Equatable
{
    let showsTrackInfoWhenLyricsUnavailable: Bool
    let showsInForeground: Bool
    let showsInBackground: Bool
    let removesWhenPaused: Bool

    init(preferences: LyricsNotificationPreferences) {
        showsTrackInfoWhenLyricsUnavailable =
            preferences.showsTrackInfoWhenLyricsUnavailable
        showsInForeground =
            preferences.showsInForeground
        showsInBackground =
            preferences.showsInBackground
        removesWhenPaused =
            preferences.removesWhenPaused
    }
}

private extension LyricsNotificationAuthorizationStatus {
    var title: String {
        switch self {
        case .notDetermined:
            "尚未请求"
        case .denied:
            "系统已关闭"
        case .authorized:
            "已允许"
        case .provisional:
            "临时允许"
        case .ephemeral:
            "本次允许"
        }
    }

    var systemImage: String {
        switch self {
        case .notDetermined:
            "questionmark.circle"
        case .denied:
            "bell.slash"
        case .authorized, .provisional, .ephemeral:
            "checkmark.circle"
        }
    }
}
