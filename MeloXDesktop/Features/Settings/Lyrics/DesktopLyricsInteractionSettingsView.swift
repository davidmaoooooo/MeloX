import SwiftUI

struct DesktopLyricsInteractionSettingsView: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        ScrollView {
            Form {
                Section("浏览与跳转") {
                    Toggle(
                        "单击歌词跳转",
                        isOn: $settings.lyricsTapToSeek
                    )
                    Toggle(
                        "自动跟随当前歌词",
                        isOn: $settings.lyricsAutoFollow
                    )
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
