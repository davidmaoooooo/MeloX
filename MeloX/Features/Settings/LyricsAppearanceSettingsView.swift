import SwiftUI

struct LyricsAppearanceSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("歌词样式", selection: $settings.lyricsStyle) {
                    ForEach(LyricsStyle.allCases) { style in
                        Label(style.title, systemImage: style.systemImage)
                            .tag(style)
                    }
                }

                if settings.lyricsStyle == .textPV {
                    NavigationLink {
                        TextPVSettingsView()
                    } label: {
                        LabeledContent(
                            "文字PV设置",
                            value: settings.textPV.style.title
                        )
                    }
                }
            } header: {
                Text("样式")
            } footer: {
                Text(settings.lyricsStyle.description)
            }

            Section {
                valueSlider(
                    title: "字体大小",
                    value: $settings.lyricsFontSize,
                    range: 20...36,
                    step: 1,
                    valueText: "\(Int(settings.lyricsFontSize)) 磅"
                )

                Picker(
                    "字体粗细",
                    selection: $settings.lyricsFontWeight
                ) {
                    ForEach(LyricsFontWeight.allCases) { weight in
                        Text(weight.title).tag(weight)
                    }
                }
            } header: {
                Text("基础排版")
            } footer: {
                Text("字号是歌词正文基准，翻译按比例缩放；EVA 与文字PV会保留模板字体。")
            }

            if settings.lyricsStyle == .appleMusic {
                Section {
                    Toggle(
                        "显示等待倒计时",
                        isOn: $settings.lyricsInterludeCountdownEnabled
                    )

                    valueSlider(
                        title: "当前歌词大小",
                        value: $settings.lyricsCurrentLineScale,
                        range: AppSettings.lyricsCurrentLineScaleRange,
                        step: 0.01,
                        valueText:
                            "\(Int((settings.lyricsCurrentLineScale * 100).rounded()))%"
                    )

                    valueSlider(
                        title: "歌词行距",
                        value: $settings.lyricsLineSpacing,
                        range: 12...36,
                        step: 1,
                        valueText: "\(Int(settings.lyricsLineSpacing))"
                    )

                    valueSlider(
                        title: "焦点垂直位置",
                        value: $settings.lyricsFocusPosition,
                        range: AppSettings.lyricsFocusPositionRange,
                        step: 0.01,
                        valueText:
                            "距顶部 \(Int(settings.lyricsFocusPosition * 100))%"
                    )
                } header: {
                    Text("Apple Music 布局")
                } footer: {
                    Text("等待倒计时会出现在首句前，以及精确歌词中较长的演奏空档。")
                }

                Section {
                    valueSlider(
                        title: "基础模糊强度",
                        value: $settings.lyricsBlurIntensity,
                        range: 0...2,
                        step: 0.1,
                        valueText: settings.lyricsBlurIntensity.formatted(
                            .number.precision(.fractionLength(1))
                        )
                    )

                    Toggle(
                        "手动浏览时统一变暗",
                        isOn:
                            $settings
                                .lyricsUsesUniformDimmingWhileBrowsing
                    )

                    valueSlider(
                        title: "默认逐句模糊加强",
                        value: $settings.lyricsDistanceBlurScale,
                        range: AppSettings.lyricsDistanceBlurScaleRange,
                        step: 0.05,
                        valueText:
                            "\(Int((settings.lyricsDistanceBlurScale * 100).rounded()))%"
                    )

                    valueSlider(
                        title: "隐藏 UI 逐句模糊加强",
                        value: $settings.lyricsHiddenInterfaceBlurScale,
                        range: AppSettings.lyricsDistanceBlurScaleRange,
                        step: 0.05,
                        valueText:
                            "\(Int((settings.lyricsHiddenInterfaceBlurScale * 100).rounded()))%"
                    )

                    valueSlider(
                        title: "非焦点歌词变暗",
                        value: $settings.lyricsDimAmount,
                        range: 0...1,
                        step: 0.1,
                        valueText:
                            "\(Int(settings.lyricsDimAmount * 100))%"
                    )
                } header: {
                    Text("Apple Music 焦点")
                } footer: {
                    Text("手动浏览时可保留当前播放句为唯一焦点；恢复跟随后重新应用逐句渐暗和模糊。")
                }
            }
        }
        .navigationTitle("外观与排版")
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
