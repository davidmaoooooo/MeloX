import SwiftUI

struct DesktopLyricsAppearanceSettingsView: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        ScrollView {
            Form {
                Section("基础排版") {
                    LabeledContent(
                        "样式",
                        value: LyricsStyle.appleMusic.title
                    )

                    HStack {
                        Text("字体大小")
                        Slider(
                            value: $settings.lyricsFontSize,
                            in: AppSettings.desktopLyricsFontSizeRange,
                            step: 1
                        )
                        Text("\(Int(settings.lyricsFontSize.rounded())) 磅")
                            .monospacedDigit()
                            .frame(width: 62, alignment: .trailing)
                    }

                    Picker(
                        "字体粗细",
                        selection: $settings.lyricsFontWeight
                    ) {
                        ForEach(LyricsFontWeight.allCases) { weight in
                            Text(weight.title).tag(weight)
                        }
                    }
                }

                Section("Apple Music 布局") {
                    Toggle(
                        "显示等待倒计时",
                        isOn: $settings.lyricsInterludeCountdownEnabled
                    )

                    HStack {
                        Text("当前歌词大小")
                        Slider(
                            value: $settings.lyricsCurrentLineScale,
                            in: AppSettings.lyricsCurrentLineScaleRange,
                            step: 0.01
                        )
                        Text(
                            "\(Int((settings.lyricsCurrentLineScale * 100).rounded()))%"
                        )
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    }

                    HStack {
                        Text("歌词行距")
                        Slider(
                            value: $settings.lyricsLineSpacing,
                            in: AppSettings.desktopLyricsLineSpacingRange,
                            step: 1
                        )
                        Text("\(Int(settings.lyricsLineSpacing.rounded()))")
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                    }

                    HStack {
                        Text("焦点垂直位置")
                        Slider(
                            value: $settings.lyricsFocusPosition,
                            in: AppSettings.lyricsFocusPositionRange,
                            step: 0.01
                        )
                        Text(
                            "\(Int((settings.lyricsFocusPosition * 100).rounded()))%"
                        )
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    }
                }

                Section("焦点与模糊") {
                    HStack {
                        Text("基础模糊强度")
                        Slider(
                            value: $settings.lyricsBlurIntensity,
                            in: AppSettings.lyricsBlurIntensityRange,
                            step: 0.1
                        )
                        Text(
                            settings.lyricsBlurIntensity.formatted(
                                .number.precision(.fractionLength(1))
                            )
                        )
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    }

                    HStack {
                        Text("逐句模糊加强")
                        Slider(
                            value: $settings.lyricsDistanceBlurScale,
                            in: AppSettings.lyricsDistanceBlurScaleRange,
                            step: 0.05
                        )
                        Text(
                            "\(Int((settings.lyricsDistanceBlurScale * 100).rounded()))%"
                        )
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    }

                    HStack {
                        Text("非焦点歌词变暗")
                        Slider(
                            value: $settings.lyricsDimAmount,
                            in: 0...1,
                            step: 0.1
                        )
                        Text(
                            "\(Int((settings.lyricsDimAmount * 100).rounded()))%"
                        )
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    }
                }
            }
            .formStyle(.columns)
            .padding()
        }
        .scrollIndicators(.automatic)
    }
}
