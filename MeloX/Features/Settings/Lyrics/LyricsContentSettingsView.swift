import SwiftUI

struct LyricsContentSettingsView: View {
    @Environment(AppSettings.self) private var settings

    private var usesWordByWordPresentation: Bool {
        settings.lyricsWordByWord || settings.lyricsPseudoWordByWord
    }

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle(
                    "显示发音（罗马音）",
                    isOn: $settings.lyricsRomanizationEnabled
                )

                Toggle(
                    "显示歌词翻译",
                    isOn: $settings.lyricsTranslationEnabled
                )

                if settings.lyricsStyle == .appleMusic,
                   settings.lyricsRomanizationEnabled {
                    Picker(
                        "罗马音显示范围",
                        selection:
                            $settings
                                .lyricsRomanizationDisplayMode
                    ) {
                        ForEach(
                            LyricsTranslationDisplayMode.allCases
                        ) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }

                if settings.lyricsStyle == .appleMusic,
                   settings.lyricsTranslationEnabled {
                    Picker(
                        "翻译显示范围",
                        selection:
                            $settings
                                .lyricsTranslationDisplayMode
                    ) {
                        ForEach(
                            LyricsTranslationDisplayMode.allCases
                        ) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                }
            } header: {
                Text("翻译与发音")
            } footer: {
                Text("使用网易云提供的 yromalrc/romalrc 与 ytlrc/tlyric；Apple Music 样式会将小号罗马音对齐在对应原文下方，翻译显示在整行下方。")
            }

            if settings.lyricsRomanizationEnabled {
                Section {
                    valueSlider(
                        title: "罗马音大小",
                        value: $settings.lyricsRomanizationFontScale,
                        range: 0.5...0.8,
                        step: 0.05,
                        valueText:
                            "\(Int(settings.lyricsRomanizationFontScale * 100))%"
                    )

                    valueSlider(
                        title: "罗马音亮度",
                        value: $settings.lyricsRomanizationOpacity,
                        range: 0.4...0.9,
                        step: 0.05,
                        valueText:
                            "\(Int(settings.lyricsRomanizationOpacity * 100))%"
                    )
                } header: {
                    Text("罗马音样式")
                }
            }

            if settings.lyricsTranslationEnabled {
                Section {
                    valueSlider(
                        title: "翻译歌词大小",
                        value: $settings.lyricsTranslationFontScale,
                        range: 0.5...0.8,
                        step: 0.05,
                        valueText:
                            "\(Int(settings.lyricsTranslationFontScale * 100))%"
                    )

                    valueSlider(
                        title: "翻译歌词亮度",
                        value: $settings.lyricsTranslationOpacity,
                        range: 0.4...0.9,
                        step: 0.05,
                        valueText:
                            "\(Int(settings.lyricsTranslationOpacity * 100))%"
                    )
                } header: {
                    Text("翻译样式")
                }
            }

            Section {
                Toggle(
                    "使用官方逐字歌词",
                    isOn: $settings.lyricsWordByWord
                )

                Toggle(
                    "无 YRC 时启用伪逐字",
                    isOn: $settings.lyricsPseudoWordByWord
                )
            } header: {
                Text("逐字歌词")
            } footer: {
                Text("官方逐字歌词使用 YRC 时间轴；伪逐字仅在没有 YRC 时按行时长估算，准确度较低。")
            }

            if usesWordByWordPresentation {
                Section {
                    Picker(
                        "抬升方式",
                        selection: $settings.lyricsLiftMode
                    ) {
                        ForEach(LyricsLiftMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    valueSlider(
                        title: "高光渐变宽度",
                        value: $settings.lyricsHighlightGradientWidth,
                        range:
                            AppSettings
                                .lyricsHighlightGradientWidthRange,
                        step: 0.1,
                        valueText:
                            "\(settings.lyricsHighlightGradientWidth.formatted(.number.precision(.fractionLength(1)))) 个字宽"
                    )

                    valueSlider(
                        title: "渐变削减程度",
                        value:
                            $settings
                                .lyricsHighlightGradientReduction,
                        range:
                            AppSettings
                                .lyricsHighlightGradientReductionRange,
                        step: 0.05,
                        valueText: settings
                            .lyricsHighlightGradientReduction
                            .formatted(
                                .percent.precision(
                                    .fractionLength(0)
                                )
                            )
                    )
                } header: {
                    Text("高光")
                } footer: {
                    Text("抬升方式只改变按字或按词分组，不改变高光时间；渐变宽度和削减程度共同控制过渡范围。")
                }

                Section {
                    Picker(
                        "长音识别方式",
                        selection:
                            $settings
                                .lyricsLongSyllableDetectionMode
                    ) {
                        ForEach(
                            LyricsLongSyllableDetectionMode.allCases
                        ) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    valueSlider(
                        title: "长音判定阈值",
                        value:
                            $settings
                                .lyricsLongSyllableDurationThreshold,
                        range:
                            AppSettings
                                .lyricsLongSyllableDurationThresholdRange,
                        step: 0.05,
                        valueText:
                            "\(settings.lyricsLongSyllableDurationThreshold.formatted(.number.precision(.fractionLength(2)))) 秒"
                    )

                    valueSlider(
                        title: "长音膨胀大小",
                        value: $settings.lyricsLongToneExpansionAmount,
                        range:
                            AppSettings
                                .lyricsLongToneExpansionAmountRange,
                        step: 0.01,
                        valueText: settings
                            .lyricsLongToneExpansionAmount
                            .formatted(
                                .percent.precision(
                                    .fractionLength(0)
                                )
                            )
                    )

                    Toggle(
                        "逐字歌词光效",
                        isOn: $settings.lyricsGlowEnabled
                    )

                    if settings.lyricsGlowEnabled {
                        Toggle(
                            "仅长音显示辉光",
                            isOn:
                                $settings
                                    .lyricsGlowLongSyllablesOnly
                        )

                        valueSlider(
                            title: "逐字光效强度",
                            value: $settings.lyricsGlowIntensity,
                            range: 0.4...1.6,
                            step: 0.1,
                            valueText:
                                settings.lyricsGlowIntensity.formatted(
                                    .number.precision(
                                        .fractionLength(1)
                                    )
                                )
                        )
                    }
                } header: {
                    Text("长音与光效")
                } footer: {
                    Text("达到阈值的原文字或词会依次膨胀；罗马音只同步逐字白色渐变，不参与辉光、模糊、抬升或长音膨胀。")
                }
            }
        }
        .navigationTitle("翻译与逐字")
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
