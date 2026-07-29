import SwiftUI

struct LyricsInteractionSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle(
                    settings.lyricsStyle == .appleMusic
                        ? "单击歌词跳转"
                        : "双击歌词跳转",
                    isOn: $settings.lyricsTapToSeek
                )

                if settings.lyricsStyle == .appleMusic {
                    Toggle(
                        "长按歌词分享",
                        isOn: $settings.lyricsLongPressToShare
                    )
                }

                Toggle(
                    "浏览后恢复跟随",
                    isOn: $settings.lyricsAutoFollow
                )

                if settings.lyricsAutoFollow {
                    valueSlider(
                        title: "恢复跟随等待",
                        value: $settings.lyricsFollowDelay,
                        range: 1...10,
                        step: 1,
                        valueText: "\(Int(settings.lyricsFollowDelay)) 秒"
                    )
                }
            } header: {
                Text("浏览与跳转")
            } footer: {
                Text("开启自动跟随后，手动浏览结束并等待指定时间，歌词会返回当前播放行。")
            }

            Section {
                valueSlider(
                    title: "歌词提前量",
                    value: $settings.lyricsAdvanceTime,
                    range: 0...5,
                    step: 0.1,
                    valueText:
                        "\(settings.lyricsAdvanceTime.formatted(.number.precision(.fractionLength(1)))) 秒"
                )

                Toggle(
                    "同时应用于逐字歌词",
                    isOn:
                        $settings
                            .lyricsAdvanceTimeAppliesToWordByWord
                )
            } header: {
                Text("同步")
            } footer: {
                Text("普通逐行歌词和悬浮歌词会提前显示，不会改变音频进度。开启后，逐字歌词的行切换和逐字高光也会使用相同提前量。")
            }

            if settings.lyricsStyle == .appleMusic {
                Section {
                    valueSlider(
                        title: "控制栏自动隐藏",
                        value:
                            $settings
                                .appleMusicLyricsInterfaceAutoHideDelay,
                        range:
                            AppSettings
                                .appleMusicLyricsInterfaceAutoHideDelayRange,
                        step: 1,
                        valueText:
                            "\(Int(settings.appleMusicLyricsInterfaceAutoHideDelay)) 秒"
                    )

                    valueSlider(
                        title: "滚动隐藏 UI 阈值",
                        value:
                            $settings
                                .appleMusicLyricsScrollHideThreshold,
                        range:
                            AppSettings
                                .appleMusicLyricsScrollHideThresholdRange,
                        step: 10,
                        valueText:
                            "\(Int(settings.appleMusicLyricsScrollHideThreshold)) 点"
                    )
                } header: {
                    Text("Apple Music 界面")
                } footer: {
                    Text("停止操作后控制栏会自动隐藏；向后浏览达到阈值时也会隐藏，往回滚动会立即重新显示。")
                }
            }
        }
        .navigationTitle("交互与同步")
        .navigationBarTitleDisplayMode(.inline)
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
