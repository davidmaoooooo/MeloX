import SwiftUI

struct DesktopLyricsInteractionSettingsView: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        ScrollView {
            Form {
                Section {
                    Toggle(
                        "单击歌词跳转",
                        isOn: $settings.lyricsTapToSeek
                    )
                    Toggle(
                        "浏览后恢复跟随",
                        isOn: $settings.lyricsAutoFollow
                    )

                    if settings.lyricsAutoFollow {
                        HStack {
                            Text("恢复跟随等待")
                            Slider(
                                value: $settings.lyricsFollowDelay,
                                in: 1...10,
                                step: 1
                            )
                            Text("\(Int(settings.lyricsFollowDelay)) 秒")
                                .monospacedDigit()
                                .frame(width: 60, alignment: .trailing)
                        }
                    }
                } header: {
                    Text("浏览与跳转")
                } footer: {
                    Text("开启自动跟随后，手动浏览结束并等待指定时间，歌词会返回当前播放行。")
                }

                Section("同步") {
                    HStack {
                        Text("歌词提前量")
                        Slider(
                            value: $settings.lyricsAdvanceTime,
                            in: AppSettings.lyricsAdvanceTimeRange,
                            step: 0.1
                        )
                        Text(
                            "\(settings.lyricsAdvanceTime, specifier: "%.1f") s"
                        )
                        .monospacedDigit()
                        .frame(width: 60, alignment: .trailing)
                    }

                    Toggle(
                        "同时应用于逐字歌词",
                        isOn:
                            $settings
                                .lyricsAdvanceTimeAppliesToWordByWord
                    )
                }
            }
            .formStyle(.columns)
            .padding()
        }
        .scrollIndicators(.automatic)
    }
}
