import SwiftUI

struct LyricsLiveActivitySettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    var body: some View {
        @Bindable var settings = settings
        let preferences = LyricsLiveActivityPreferences(
            settings: settings
        )

        Form {
            Section {
                LabeledContent("主标题格式") {
                    formatField(
                        "主标题格式",
                        text: $settings.lyricsLiveActivityTitleFormat
                    )
                }

                LabeledContent("副标题格式") {
                    formatField(
                        "副标题格式",
                        text:
                            $settings
                                .lyricsLiveActivitySubtitleFormat
                    )
                }

                LabeledContent("缩起歌词格式") {
                    formatField(
                        "缩起歌词格式",
                        text:
                            $settings
                                .lyricsLiveActivityCompactFormat
                    )
                }
            } header: {
                Text("文字格式")
            } footer: {
                Text("可使用 {歌词}、{歌名}、{作者} 占位符；留空时会自动回退。")
            }

            Section {
                Toggle(
                    "显示封面",
                    isOn:
                        $settings
                            .lyricsLiveActivityShowsArtwork
                )

                Picker(
                    "歌词字号",
                    selection:
                        $settings
                            .lyricsLiveActivityCompactTextSize
                ) {
                    ForEach(
                        LyricsLiveActivityCompactTextSize.allCases
                    ) { size in
                        Text(size.title).tag(size)
                    }
                }

                Toggle(
                    "长歌词自动滚动",
                    isOn:
                        $settings
                            .lyricsLiveActivityScrollsCompactText
                )

                if settings.lyricsLiveActivityScrollsCompactText {
                    valueSlider(
                        title: "滚动速度",
                        value:
                            $settings
                                .lyricsLiveActivityScrollSpeed,
                        range:
                            AppSettings
                                .lyricsLiveActivityScrollSpeedRange,
                        step: 1,
                        valueText:
                            "\(Int(settings.lyricsLiveActivityScrollSpeed.rounded())) 点/秒"
                    )

                    valueSlider(
                        title: "开始停顿",
                        value:
                            $settings
                                .lyricsLiveActivityScrollPause,
                        range:
                            AppSettings
                                .lyricsLiveActivityScrollPauseRange,
                        step: 0.1,
                        valueText: String(
                            format: "%.1f 秒",
                            settings.lyricsLiveActivityScrollPause
                        )
                    )
                }
            } header: {
                Text("缩起显示")
            } footer: {
                Text("空间不足时由播放进度推动歌词依次经过左右区域；若设定速度无法在下一句前显示完整，本句会自动提速。")
            }

            Section {
                Toggle(
                    "显示下一句",
                    isOn:
                        $settings
                            .lyricsLiveActivityShowsNextLyric
                )
                Toggle(
                    "显示播放进度",
                    isOn:
                        $settings
                            .lyricsLiveActivityShowsProgress
                )
            } header: {
                Text("展开与锁定屏幕")
            }
        }
        .navigationTitle("实时活动歌词")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: preferences) {
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

    private func valueSlider(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent(title, value: valueText)
            Slider(value: value, in: range, step: step)
                .accessibilityLabel(title)
                .accessibilityValue(valueText)
        }
    }
}

private extension LyricsLiveActivityCompactTextSize {
    var title: String {
        switch self {
        case .small: "小"
        case .standard: "标准"
        case .large: "大"
        }
    }
}
