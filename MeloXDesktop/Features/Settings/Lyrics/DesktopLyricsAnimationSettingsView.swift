import SwiftUI

struct DesktopLyricsAnimationSettingsView: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        @Bindable var settings = model.settings

        ScrollView {
            Form {
                Section("性能") {
                    Picker(
                        "刷新频率",
                        selection: $settings.lyricsRefreshRate
                    ) {
                        ForEach(LyricsRefreshRate.allCases) { rate in
                            Text(rate.title).tag(rate)
                        }
                    }
                }

                Section("移动与追赶") {
                    HStack {
                        Text("基础拖尾延迟")
                        Slider(
                            value: $settings.lyricsFocusCascadeDelay,
                            in: AppSettings.lyricsFocusCascadeDelayRange,
                            step: 0.001
                        )
                        Text(
                            "\(Int((settings.lyricsFocusCascadeDelay * 1_000).rounded())) ms"
                        )
                        .monospacedDigit()
                        .frame(width: 62, alignment: .trailing)
                    }

                    HStack {
                        Text("逐句拖尾增量")
                        Slider(
                            value:
                                $settings.lyricsFocusCascadeDelayIncrease,
                            in:
                                AppSettings
                                    .lyricsFocusCascadeDelayIncreaseRange,
                            step: 0.001
                        )
                        Text(
                            "\(Int((settings.lyricsFocusCascadeDelayIncrease * 1_000).rounded())) ms"
                        )
                        .monospacedDigit()
                        .frame(width: 62, alignment: .trailing)
                    }

                    HStack {
                        Text("后续歌词启动延迟")
                        Slider(
                            value:
                                $settings
                                    .lyricsFocusCascadeFollowingDelay,
                            in:
                                AppSettings
                                    .lyricsFocusCascadeFollowingDelayRange,
                            step: 0.001
                        )
                        Text(
                            "\(Int((settings.lyricsFocusCascadeFollowingDelay * 1_000).rounded())) ms"
                        )
                        .monospacedDigit()
                        .frame(width: 62, alignment: .trailing)
                    }

                    HStack {
                        Text("拖尾追赶节奏")
                        Slider(
                            value:
                                $settings.lyricsFocusCascadeCatchUpRatio,
                            in:
                                AppSettings
                                    .lyricsFocusCascadeCatchUpRatioRange,
                            step: 0.01
                        )
                        Text(
                            "\(Int((settings.lyricsFocusCascadeCatchUpRatio * 100).rounded()))%"
                        )
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    }

                    HStack {
                        Text("追赶速度梯度")
                        Slider(
                            value:
                                $settings
                                    .lyricsFocusCascadeChaseSpeedGradient,
                            in:
                                AppSettings
                                    .lyricsFocusCascadeChaseSpeedGradientRange,
                            step: 0.01
                        )
                        Text(
                            "\(Int((settings.lyricsFocusCascadeChaseSpeedGradient * 100).rounded()))%"
                        )
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                    }

                    HStack {
                        Text("位移收束时长")
                        Slider(
                            value:
                                $settings.lyricsFocusCascadeDuration,
                            in:
                                AppSettings
                                    .lyricsFocusCascadeDurationRange,
                            step: 0.01
                        )
                        Text(
                            "\(settings.lyricsFocusCascadeDuration, specifier: "%.2f") s"
                        )
                        .monospacedDigit()
                        .frame(width: 62, alignment: .trailing)
                    }

                    HStack {
                        Text("瞬移阈值")
                        Slider(
                            value: $settings.lyricsFocusSnapThreshold,
                            in: AppSettings.lyricsFocusSnapThresholdRange,
                            step: 0.001
                        )
                        Text(
                            "\(Int((settings.lyricsFocusSnapThreshold * 1_000).rounded())) ms"
                        )
                        .monospacedDigit()
                        .frame(width: 62, alignment: .trailing)
                    }
                }

                Section("回弹与焦点") {
                    Toggle(
                        "启用位移回弹",
                        isOn:
                            $settings.lyricsFocusCascadeBounceEnabled
                    )
                    if settings.lyricsFocusCascadeBounceEnabled {
                        HStack {
                            Text("最大回弹弹性")
                            Slider(
                                value:
                                    $settings.lyricsFocusCascadeBounce,
                                in:
                                    AppSettings
                                        .lyricsFocusCascadeBounceRange,
                                step: 0.01
                            )
                            Text(
                                "\(Int((settings.lyricsFocusCascadeBounce * 100).rounded()))%"
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }

                        HStack {
                            Text("回弹强度梯度")
                            Slider(
                                value:
                                    $settings
                                        .lyricsFocusCascadeBounceGradient,
                                in:
                                    AppSettings
                                        .lyricsFocusCascadeBounceGradientRange,
                                step: 0.01
                            )
                            Text(
                                "\(Int((settings.lyricsFocusCascadeBounceGradient * 100).rounded()))%"
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }
                    }

                    Toggle(
                        "启用当前句回弹",
                        isOn: $settings.lyricsFocusScaleBounceEnabled
                    )
                    if settings.lyricsFocusScaleBounceEnabled {
                        HStack {
                            Text("当前句回弹时长")
                            Slider(
                                value:
                                    $settings
                                        .lyricsFocusScaleBounceDuration,
                                in:
                                    AppSettings
                                        .lyricsFocusScaleBounceDurationRange,
                                step: 0.01
                            )
                            Text(
                                "\(settings.lyricsFocusScaleBounceDuration, specifier: "%.2f") s"
                            )
                            .monospacedDigit()
                            .frame(width: 62, alignment: .trailing)
                        }

                        HStack {
                            Text("当前句回弹弹性")
                            Slider(
                                value:
                                    $settings.lyricsFocusScaleBounce,
                                in:
                                    AppSettings
                                        .lyricsFocusScaleBounceRange,
                                step: 0.01
                            )
                            Text(
                                "\(Int((settings.lyricsFocusScaleBounce * 100).rounded()))%"
                            )
                            .monospacedDigit()
                            .frame(width: 48, alignment: .trailing)
                        }
                    }

                    HStack {
                        Text("焦点颜色提前")
                        Slider(
                            value: $settings.lyricsFocusColorLeadTime,
                            in:
                                AppSettings
                                    .lyricsFocusColorLeadTimeRange,
                            step: 0.005
                        )
                        Text(
                            "\(Int((settings.lyricsFocusColorLeadTime * 1_000).rounded())) ms"
                        )
                        .monospacedDigit()
                        .frame(width: 68, alignment: .trailing)
                    }
                }
            }
            .formStyle(.columns)
            .padding()
        }
        .scrollIndicators(.automatic)
    }
}
