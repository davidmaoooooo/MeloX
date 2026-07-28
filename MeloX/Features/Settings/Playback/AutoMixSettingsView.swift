import SwiftUI

struct AutoMixSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    var body: some View {
        @Bindable var preferences = settings.autoMix

        Form {
            Section {
                Toggle(
                    "自动混音",
                    isOn: Binding(
                        get: { player.isAutoMixEnabled },
                        set: { player.setAutoMixEnabled($0) }
                    )
                )

                Picker("过渡方式", selection: $preferences.mode) {
                    ForEach(AutoMixMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } header: {
                Text("模式")
            } footer: {
                Text(preferences.mode.description)
            }

            if preferences.mode == .smart {
                Section {
                    Picker(
                        "过渡长度",
                        selection: $preferences.transitionBars
                    ) {
                        ForEach(AutoMixTransitionBars.allCases) { bars in
                            Text(bars.title).tag(bars)
                        }
                    }

                    Picker(
                        "上一首结束位置",
                        selection: $preferences.tailCutBars
                    ) {
                        ForEach(AutoMixTailCutBars.allCases) {
                            timing in
                            Text(timing.title).tag(timing)
                        }
                    }

                    Toggle(
                        "匹配歌曲速度",
                        isOn: $preferences.tempoMatchingEnabled
                    )

                    if preferences.tempoMatchingEnabled {
                        valueSlider(
                            title: "最大速度调整",
                            value:
                                $preferences
                                    .maximumTempoAdjustmentPercent,
                            range:
                                AutoMixPreferences
                                    .maximumTempoAdjustmentPercentRange,
                            step: 0.5,
                            valueText:
                                "\(preferences.maximumTempoAdjustmentPercent.formatted(.number.precision(.fractionLength(1))))%"
                        )
                    }

                    Toggle(
                        "跳过安静开头",
                        isOn: $preferences.skipsQuietOpening
                    )

                    valueSlider(
                        title: "最低分析置信度",
                        value: $preferences.minimumAnalysisConfidence,
                        range:
                            AutoMixPreferences
                                .minimumAnalysisConfidenceRange,
                        step: 0.05,
                        valueText:
                            "\(Int((preferences.minimumAnalysisConfidence * 100).rounded()))%"
                    )

                    Toggle(
                        "分析网络歌曲",
                        isOn: $preferences.analyzesStreamingTracks
                    )
                } header: {
                    Text("智能分析")
                } footer: {
                    Text(
                        "BeatNet 与频谱变化会在整曲范围寻找段落和 16/32 拍乐句边界，再对前后两首的能量走势、频段拥挤和安静区间联合评分。所有节拍都可成为候选，重拍只提供很小的辅助信息，不会等待人声完全结束。“上一首结束位置”决定最晚保留到哪里。"
                    )
                }
            }

            Section {
                if preferences.mode == .fixed
                    || preferences.fallbackBehavior == .crossfade {
                    valueSlider(
                        title: "交叉淡化时长",
                        value: $preferences.fixedDuration,
                        range: AutoMixPreferences.fixedDurationRange,
                        step: 0.5,
                        valueText:
                            "\(preferences.fixedDuration.formatted(.number.precision(.fractionLength(1)))) 秒"
                    )
                }

                valueSlider(
                    title: "提前预载",
                    value: $preferences.preloadLeadTime,
                    range: AutoMixPreferences.preloadLeadTimeRange,
                    step: 5,
                    valueText: "\(Int(preferences.preloadLeadTime)) 秒"
                )

                Picker("淡化曲线", selection: $preferences.fadeCurve) {
                    ForEach(AutoMixFadeCurve.allCases) { curve in
                        Text(curve.title).tag(curve)
                    }
                }
            } header: {
                Text("播放")
            } footer: {
                Text(
                    "\(preferences.fadeCurve.description) 智能混音期间两首歌会沿同一条速度曲线逐渐交接，并在中段交换低频，避免底鼓互相覆盖。播放器中的混音进度直接取自两台播放器实际走过的媒体时间；暂停或缓冲时不会继续前进。“提前预载”只控制何时准备第二个播放器。"
                )
            }

            if preferences.mode == .smart {
                Section {
                    Picker(
                        "分析不可用时",
                        selection: $preferences.fallbackBehavior
                    ) {
                        ForEach(AutoMixFallbackBehavior.allCases) {
                            behavior in
                            Text(behavior.title).tag(behavior)
                        }
                    }
                } header: {
                    Text("失败策略")
                } footer: {
                    Text(preferences.fallbackBehavior.description)
                }
            }
        }
        .navigationTitle("自动混音")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: preferences.configuration) {
            player.applyAutoMixSettings()
        }
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
