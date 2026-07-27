import SwiftUI

struct SystemPlaybackSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

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
        .navigationTitle("锁定屏幕与实时活动")
        .navigationBarTitleDisplayMode(.inline)
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
