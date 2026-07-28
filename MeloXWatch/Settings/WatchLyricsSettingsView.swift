import SwiftUI

struct WatchLyricsSettingsView: View {
    @AppStorage(WatchPreferenceKey.showsTranslation)
    private var showsTranslation = true
    @AppStorage(WatchPreferenceKey.showsRomanization)
    private var showsRomanization = false
    @AppStorage(WatchPreferenceKey.wordByWord)
    private var wordByWord = true
    @AppStorage(WatchPreferenceKey.lyricGlow)
    private var lyricGlow = true
    @AppStorage(WatchPreferenceKey.lyricGlowIntensity)
    private var glowIntensity = 1.0
    @AppStorage(WatchPreferenceKey.lyricAdvanceTime)
    private var advanceTime = 0.2
    @AppStorage(WatchPreferenceKey.lyricBlurIntensity)
    private var blurIntensity = 0.8
    @AppStorage(WatchPreferenceKey.lyricDistanceBlurScale)
    private var distanceBlurScale = 1.05
    @AppStorage(WatchPreferenceKey.lyricCurrentLineScale)
    private var currentLineScale = 1.02
    @AppStorage(WatchPreferenceKey.lyricHighRefreshRate)
    private var refreshRateRawValue = WatchLyricsRefreshRate.smooth.rawValue
    @AppStorage(WatchPreferenceKey.lyricDimAmount)
    private var dimAmount = 1.0
    @AppStorage(WatchPreferenceKey.lyricFocusPosition)
    private var focusPosition = 0.25
    @AppStorage(WatchPreferenceKey.lyricUniformBrowsingDimming)
    private var usesUniformBrowsingDimming = true
    @AppStorage(WatchPreferenceKey.lyricRomanizationFontScale)
    private var romanizationFontScale = 0.65
    @AppStorage(WatchPreferenceKey.lyricRomanizationOpacity)
    private var romanizationOpacity = 0.9
    @AppStorage(WatchPreferenceKey.lyricLiftMode)
    private var liftModeRawValue = WatchLyricTimingMode.character.rawValue
    @AppStorage(WatchPreferenceKey.lyricLongToneDetectionMode)
    private var longToneDetectionModeRawValue =
        WatchLyricTimingMode.character.rawValue
    @AppStorage(WatchPreferenceKey.lyricLongToneDurationThreshold)
    private var longToneDurationThreshold = 0.95
    @AppStorage(WatchPreferenceKey.lyricLongToneExpansionAmount)
    private var longToneExpansionAmount = 0.05

    var body: some View {
        Form {
            Section("内容") {
                Toggle("逐字高亮", isOn: $wordByWord)
                Toggle("显示翻译", isOn: $showsTranslation)
                Toggle("显示罗马音", isOn: $showsRomanization)

                LabeledContent(
                    "注音大小",
                    value: romanizationFontScale.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                Slider(value: $romanizationFontScale, in: 0.45...0.85)
                    .disabled(!showsRomanization)
                    .accessibilityLabel("注音大小")

                LabeledContent(
                    "注音亮度",
                    value: romanizationOpacity.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                Slider(value: $romanizationOpacity, in: 0.4...1)
                    .disabled(!showsRomanization)
                    .accessibilityLabel("注音亮度")
            }

            Section {
                Picker("逐字动效", selection: $refreshRateRawValue) {
                    ForEach(WatchLyricsRefreshRate.allCases) { rate in
                        Text(rate.title).tag(rate.rawValue)
                    }
                }
            } header: {
                Text("刷新率")
            } footer: {
                Text("“流畅”使用最高 60 帧连续进度，“省电”限制为 30 帧。")
            }

            Section("辉光") {
                Toggle("歌词辉光", isOn: $lyricGlow)

                LabeledContent(
                    "辉光强度",
                    value: glowIntensity.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                Slider(value: $glowIntensity, in: 0...1.5)
                    .disabled(!lyricGlow)
                    .accessibilityLabel("辉光强度")
            }

            Section("渐进模糊") {
                LabeledContent(
                    "模糊强度",
                    value: blurIntensity.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                Slider(value: $blurIntensity, in: 0...1.5)
                    .accessibilityLabel("模糊强度")

                LabeledContent(
                    "距离增幅",
                    value: distanceBlurScale.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                Slider(value: $distanceBlurScale, in: 0...1.5)
                    .accessibilityLabel("距离模糊增幅")

                LabeledContent(
                    "非焦点变暗",
                    value: dimAmount.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                Slider(value: $dimAmount, in: 0...1)
                    .accessibilityLabel("非焦点歌词变暗")

                Toggle(
                    "浏览时统一变暗",
                    isOn: $usesUniformBrowsingDimming
                )
            }

            Section("时序与焦点") {
                LabeledContent(
                    "歌词提前",
                    value:
                        advanceTime.formatted(
                            .number.precision(.fractionLength(2))
                        )
                        + " 秒"
                )
                Slider(value: $advanceTime, in: -0.5...0.8, step: 0.05)
                    .accessibilityLabel("歌词提前时间")

                LabeledContent(
                    "当前行缩放",
                    value: currentLineScale.formatted(
                        .number.precision(.fractionLength(2))
                    )
                )
                Slider(value: $currentLineScale, in: 1...1.15)
                    .accessibilityLabel("当前行缩放")

                LabeledContent(
                    "焦点位置",
                    value:
                        "顶部 "
                        + focusPosition.formatted(
                            .percent.precision(.fractionLength(0))
                        )
                )
                Slider(value: $focusPosition, in: 0.12...0.5)
                    .accessibilityLabel("歌词焦点垂直位置")
            }

            Section("逐字动态") {
                Picker("抬升方式", selection: $liftModeRawValue) {
                    ForEach(WatchLyricTimingMode.allCases) { mode in
                        Text(mode.liftTitle).tag(mode.rawValue)
                    }
                }

                Picker(
                    "长音识别",
                    selection: $longToneDetectionModeRawValue
                ) {
                    ForEach(WatchLyricTimingMode.allCases) { mode in
                        Text(mode.detectionTitle).tag(mode.rawValue)
                    }
                }

                LabeledContent(
                    "长音阈值",
                    value:
                        longToneDurationThreshold.formatted(
                            .number.precision(.fractionLength(2))
                        )
                        + " 秒"
                )
                Slider(
                    value: $longToneDurationThreshold,
                    in: 0.3...1.5,
                    step: 0.05
                )
                .accessibilityLabel("长音判定阈值")

                LabeledContent(
                    "膨胀大小",
                    value: longToneExpansionAmount.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                Slider(
                    value: $longToneExpansionAmount,
                    in: 0...0.15,
                    step: 0.01
                )
                .accessibilityLabel("长音膨胀大小")
            }
        }
        .navigationTitle("歌词动效")
    }
}
