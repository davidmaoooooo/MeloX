import SwiftUI

struct PlayerSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    @State private var showsResetConfirmation = false
    @State private var isResettingSettings = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("音质", selection: $settings.quality) {
                    ForEach(MusicQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }

                Picker(
                    "音量控制",
                    selection: $settings.playerVolumeControlMode
                ) {
                    ForEach(PlayerVolumeControlMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                NavigationLink {
                    EqualizerSettingsView()
                } label: {
                    LabeledContent(
                        "均衡器",
                        value: settings.equalizer.summary
                    )
                }
            } header: {
                Text("音频")
            } footer: {
                settingsFooter {
                    footerDescription(
                        "音频",
                        "音质受歌曲版权和账号权限限制；均衡器会同时作用于网络播放和已下载歌曲。"
                    )
                    footerDescription(
                        "音量控制",
                        "当前选择“\(settings.playerVolumeControlMode.title)”。\(settings.playerVolumeControlMode.description)"
                    )
                }
            }

            Section {
                valueSlider(
                    title: "背景模糊",
                    value: $settings.playerBackgroundBlur,
                    range: 0...140,
                    step: 5,
                    valueText: "\(Int(settings.playerBackgroundBlur))"
                )

                valueSlider(
                    title: "背景色彩",
                    value: $settings.playerBackgroundSaturation,
                    range: 0.4...1.2,
                    step: 0.05,
                    valueText: "\(Int(settings.playerBackgroundSaturation * 100))%"
                )

                Toggle("暂停时缩小封面", isOn: $settings.shrinksPausedArtwork)
            } header: {
                Text("播放器外观")
            } footer: {
                settingsFooter {
                    footerDescription(
                        "播放器外观",
                        "背景选项会实时生效；开启暂停缩小后，封面在暂停时缩至 90%。"
                    )
                }
            }

            Section {
                Toggle("记住所处页面", isOn: $settings.rememberNowPlayingPage)

                Toggle("上一首优先回到歌曲开头", isOn: $settings.previousRestartsCurrentSong)
            } header: {
                Text("播放器行为")
            } footer: {
                settingsFooter {
                    footerDescription(
                        "播放器行为",
                        "页面记忆会恢复上次停留的封面、歌词或队列。开启“上一首优先回到歌曲开头”后，歌曲播放超过 5 秒时会先回到本曲开头。"
                    )
                }
            }

            Section {
                Toggle(
                    "系统播放歌词",
                    isOn: $settings.systemNowPlayingLyricsEnabled
                )

                if settings.systemNowPlayingLyricsEnabled {
                    LabeledContent("标题格式") {
                        TextField(
                            "标题格式",
                            text:
                                $settings
                                    .systemNowPlayingLyricsTitleFormat
                        )
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }

                    LabeledContent("副标题格式") {
                        TextField(
                            "副标题格式",
                            text:
                                $settings
                                    .systemNowPlayingLyricsSubtitleFormat
                        )
                        .labelsHidden()
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }
                }
            } header: {
                Text("系统播放信息")
            } footer: {
                Text("可使用 {歌词}、{歌名}、{作者} 占位符；格式为空时会自动回退。关闭后恢复显示标准歌名和作者。")
            }

            Section {
                Toggle(
                    "实时活动歌词",
                    isOn: $settings.lyricsLiveActivityEnabled
                )

                if settings.lyricsLiveActivityEnabled {
                    NavigationLink("显示设置") {
                        LyricsLiveActivitySettingsView()
                    }
                }
            } header: {
                Text("实时活动")
            } footer: {
                Text("播放时在锁定屏幕和灵动岛显示歌词。此功能默认关闭，且不会改变系统播放信息。")
            }

            Section {
                NavigationLink {
                    SkylineLyricsSettingsView()
                } label: {
                    Label("全屏天际歌词", systemImage: "textformat.size")
                }
            } header: {
                Text("全屏歌词")
            } footer: {
                Text("调整横屏天际歌词的布局和动态效果，不影响竖屏歌词。")
            }

            Section {
                NavigationLink {
                    FloatingLyricsSettingsView()
                } label: {
                    Label("悬浮窗歌词", systemImage: "pip")
                }
            } header: {
                Text("悬浮歌词")
            } footer: {
                Text("通过系统画中画在其他应用上方显示当前歌词和下一句。")
            }

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
                        LabeledContent("文字PV设置", value: settings.textPV.style.title)
                    }
                }

                valueSlider(
                    title: "字体大小",
                    value: $settings.lyricsFontSize,
                    range: 20...36,
                    step: 1,
                    valueText: "\(Int(settings.lyricsFontSize)) 磅"
                )

                Picker(
                    "歌词字体粗细",
                    selection: $settings.lyricsFontWeight
                ) {
                    ForEach(LyricsFontWeight.allCases) { weight in
                        Text(weight.title).tag(weight)
                    }
                }

                if settings.lyricsStyle == .appleMusic {
                    Toggle(
                        "显示等待倒计时",
                        isOn: $settings
                            .lyricsInterludeCountdownEnabled
                    )

                    valueSlider(
                        title: "当前歌词大小",
                        value: $settings.lyricsCurrentLineScale,
                        range: AppSettings.lyricsCurrentLineScaleRange,
                        step: 0.01,
                        valueText: "\(Int((settings.lyricsCurrentLineScale * 100).rounded()))%"
                    )

                    valueSlider(
                        title: "歌词行距",
                        value: $settings.lyricsLineSpacing,
                        range: 12...36,
                        step: 1,
                        valueText: "\(Int(settings.lyricsLineSpacing))"
                    )

                    valueSlider(
                        title: "基础模糊强度",
                        value: $settings.lyricsBlurIntensity,
                        range: 0...2,
                        step: 0.1,
                        valueText: settings.lyricsBlurIntensity.formatted(
                            .number.precision(.fractionLength(1))
                        )
                    )

                    valueSlider(
                        title: "默认逐句模糊加强",
                        value: $settings.lyricsDistanceBlurScale,
                        range: AppSettings.lyricsDistanceBlurScaleRange,
                        step: 0.05,
                        valueText: "\(Int((settings.lyricsDistanceBlurScale * 100).rounded()))%"
                    )

                    valueSlider(
                        title: "隐藏 UI 逐句模糊加强",
                        value: $settings.lyricsHiddenInterfaceBlurScale,
                        range: AppSettings.lyricsDistanceBlurScaleRange,
                        step: 0.05,
                        valueText: "\(Int((settings.lyricsHiddenInterfaceBlurScale * 100).rounded()))%"
                    )

                    valueSlider(
                        title: "非焦点歌词变暗",
                        value: $settings.lyricsDimAmount,
                        range: 0...1,
                        step: 0.1,
                        valueText: "\(Int(settings.lyricsDimAmount * 100))%"
                    )

                    valueSlider(
                        title: "焦点垂直位置",
                        value: $settings.lyricsFocusPosition,
                        range: AppSettings.lyricsFocusPositionRange,
                        step: 0.01,
                        valueText: "距顶部 \(Int(settings.lyricsFocusPosition * 100))%"
                    )
                }

            } header: {
                Text("歌词外观")
            } footer: {
                settingsFooter {
                    footerDescription(
                        settings.lyricsStyle.title,
                        "\(settings.lyricsStyle.description)。字号是正文基准，翻译按比例缩放；EVA 与文字PV会保留模板字体。"
                    )
                    if settings.lyricsStyle == .appleMusic {
                        footerDescription(
                            "等待倒计时",
                            "首句歌词前，以及精确歌词中较长的演奏空档，会显示 Apple Music 风格的三点倒计时。"
                        )
                        footerDescription(
                            "模糊与焦点",
                            "基础模糊控制整体强度，两项逐句加强分别用于显示和隐藏控制栏时；焦点位置数值越大，当前行越靠下。"
                        )
                    }
                }
            }

            Section {
                Picker("刷新频率", selection: $settings.lyricsRefreshRate) {
                    ForEach(LyricsRefreshRate.allCases) { refreshRate in
                        Text(refreshRate.title).tag(refreshRate)
                    }
                }
            } header: {
                Text("歌词性能")
            } footer: {
                settingsFooter {
                    footerDescription(
                        "刷新频率",
                        "越高越流畅，也越耗电。低电量模式和高负载文字PV会自动限制为 30 FPS。"
                    )
                }
            }

            Section {
                valueSlider(
                    title: "基础拖尾延迟",
                    value: $settings.lyricsFocusCascadeDelay,
                    range: AppSettings.lyricsFocusCascadeDelayRange,
                    step: 0.001,
                    valueText: "\(Int((settings.lyricsFocusCascadeDelay * 1_000).rounded())) 毫秒"
                )

                valueSlider(
                    title: "逐句拖尾增量",
                    value: $settings.lyricsFocusCascadeDelayIncrease,
                    range: AppSettings.lyricsFocusCascadeDelayIncreaseRange,
                    step: 0.001,
                    valueText: "\(Int((settings.lyricsFocusCascadeDelayIncrease * 1_000).rounded())) 毫秒/句"
                )

                valueSlider(
                    title: "后续歌词启动延迟",
                    value: $settings.lyricsFocusCascadeFollowingDelay,
                    range: AppSettings.lyricsFocusCascadeFollowingDelayRange,
                    step: 0.001,
                    valueText: "\(Int((settings.lyricsFocusCascadeFollowingDelay * 1_000).rounded())) 毫秒"
                )

                valueSlider(
                    title: "拖尾追赶节奏",
                    value: $settings.lyricsFocusCascadeCatchUpRatio,
                    range: AppSettings.lyricsFocusCascadeCatchUpRatioRange,
                    step: 0.01,
                    valueText: "\(Int((settings.lyricsFocusCascadeCatchUpRatio * 100).rounded()))%"
                )

                valueSlider(
                    title: "追赶速度梯度",
                    value: $settings.lyricsFocusCascadeChaseSpeedGradient,
                    range: AppSettings.lyricsFocusCascadeChaseSpeedGradientRange,
                    step: 0.01,
                    valueText: "\(Int((settings.lyricsFocusCascadeChaseSpeedGradient * 100).rounded()))%"
                )

                valueSlider(
                    title: "位移收束时长",
                    value: $settings.lyricsFocusCascadeDuration,
                    range: AppSettings.lyricsFocusCascadeDurationRange,
                    step: 0.01,
                    valueText: "\(settings.lyricsFocusCascadeDuration.formatted(.number.precision(.fractionLength(2)))) 秒"
                )

                valueSlider(
                    title: "瞬移阈值",
                    value: $settings.lyricsFocusSnapThreshold,
                    range: AppSettings.lyricsFocusSnapThresholdRange,
                    step: 0.001,
                    valueText: "\(Int((settings.lyricsFocusSnapThreshold * 1_000).rounded())) 毫秒"
                )

                Toggle(
                    "启用位移回弹",
                    isOn: $settings.lyricsFocusCascadeBounceEnabled
                )

                if settings.lyricsFocusCascadeBounceEnabled {
                    valueSlider(
                        title: "最大回弹弹性",
                        value: $settings.lyricsFocusCascadeBounce,
                        range: AppSettings.lyricsFocusCascadeBounceRange,
                        step: 0.01,
                        valueText: "\(Int((settings.lyricsFocusCascadeBounce * 100).rounded()))%"
                    )

                    valueSlider(
                        title: "回弹强度梯度",
                        value: $settings.lyricsFocusCascadeBounceGradient,
                        range: AppSettings.lyricsFocusCascadeBounceGradientRange,
                        step: 0.01,
                        valueText: "\(Int((settings.lyricsFocusCascadeBounceGradient * 100).rounded()))%"
                    )
                }

                Toggle(
                    "启用升格回弹",
                    isOn: $settings.lyricsFocusScaleBounceEnabled
                )

                if settings.lyricsFocusScaleBounceEnabled {
                    valueSlider(
                        title: "升格回弹时长",
                        value: $settings.lyricsFocusScaleBounceDuration,
                        range: AppSettings.lyricsFocusScaleBounceDurationRange,
                        step: 0.01,
                        valueText: "\(settings.lyricsFocusScaleBounceDuration.formatted(.number.precision(.fractionLength(2)))) 秒"
                    )

                    valueSlider(
                        title: "升格回弹弹性",
                        value: $settings.lyricsFocusScaleBounce,
                        range: AppSettings.lyricsFocusScaleBounceRange,
                        step: 0.01,
                        valueText: "\(Int((settings.lyricsFocusScaleBounce * 100).rounded()))%"
                    )
                }

                valueSlider(
                    title: "焦点颜色提前",
                    value: $settings.lyricsFocusColorLeadTime,
                    range: AppSettings.lyricsFocusColorLeadTimeRange,
                    step: 0.005,
                    valueText: "\(Int((settings.lyricsFocusColorLeadTime * 1_000).rounded())) 毫秒"
                )
            } header: {
                Text("歌词动画")
            } footer: {
                settingsFooter {
                    footerDescription(
                        "拖尾延迟",
                        "后续歌词先等待启动延迟，再叠加基础逐行延迟和逐句增量；数值越大，队尾跟随越晚。"
                    )
                    footerDescription(
                        "追赶与收束",
                        "追赶节奏越低，后续行越快追上；速度梯度越高，队尾加速越明显。剩余时间短于瞬移阈值时会直接对齐。"
                    )
                    footerDescription(
                        "回弹",
                        "位移回弹作用于整页移动，升格回弹只作用于当前行放大；梯度控制队尾回弹的增强程度。"
                    )
                    footerDescription(
                        "焦点颜色提前",
                        "正值先变色再移动，负值先移动再变色，0 表示同时开始。"
                    )
                }
            }

            Section {
                Toggle("显示歌词翻译", isOn: $settings.lyricsTranslationEnabled)

                if settings.lyricsTranslationEnabled {
                    if settings.lyricsStyle == .appleMusic {
                        Picker(
                            "翻译显示方式",
                            selection: $settings.lyricsTranslationDisplayMode
                        ) {
                            ForEach(LyricsTranslationDisplayMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                    }

                    valueSlider(
                        title: "翻译歌词大小",
                        value: $settings.lyricsTranslationFontScale,
                        range: 0.5...0.8,
                        step: 0.05,
                        valueText: "\(Int(settings.lyricsTranslationFontScale * 100))%"
                    )

                    valueSlider(
                        title: "翻译歌词亮度",
                        value: $settings.lyricsTranslationOpacity,
                        range: 0.4...0.9,
                        step: 0.05,
                        valueText: "\(Int(settings.lyricsTranslationOpacity * 100))%"
                    )
                }

                Toggle("逐字歌词", isOn: $settings.lyricsWordByWord)

                if settings.lyricsWordByWord || settings.lyricsPseudoWordByWord {
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
                        valueText: "\(settings.lyricsHighlightGradientWidth.formatted(.number.precision(.fractionLength(1)))) 个字宽"
                    )

                    valueSlider(
                        title: "渐变削减程度",
                        value: $settings.lyricsHighlightGradientReduction,
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

                    Toggle("逐字歌词光效", isOn: $settings.lyricsGlowEnabled)

                    Picker(
                        "长音识别方式",
                        selection:
                            $settings.lyricsLongSyllableDetectionMode
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
                        value: $settings.lyricsLongSyllableDurationThreshold,
                        range:
                            AppSettings
                                .lyricsLongSyllableDurationThresholdRange,
                        step: 0.05,
                        valueText: "\(settings.lyricsLongSyllableDurationThreshold.formatted(.number.precision(.fractionLength(2)))) 秒"
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

                    if settings.lyricsGlowEnabled {
                        Toggle(
                            "仅长音显示辉光",
                            isOn: $settings.lyricsGlowLongSyllablesOnly
                        )

                        valueSlider(
                            title: "逐字光效强度",
                            value: $settings.lyricsGlowIntensity,
                            range: 0.4...1.6,
                            step: 0.1,
                            valueText: settings.lyricsGlowIntensity.formatted(
                                .number.precision(.fractionLength(1))
                            )
                        )
                    }
                }
            } header: {
                Text("歌词内容与光效")
            } footer: {
                settingsFooter {
                    footerDescription(
                        "翻译",
                        "使用网易云提供的 ytlrc 或 tlyric；Apple Music 样式可仅显示当前行或显示全部翻译。"
                    )
                    footerDescription(
                        "逐字歌词",
                        "使用歌曲自带的 YRC 时间轴；抬升方式只改变按字或按词分组，不改变高光时间。"
                    )
                    if settings.lyricsWordByWord
                        || settings.lyricsPseudoWordByWord {
                        footerDescription(
                            "高光渐变",
                            "宽度控制过渡范围，削减程度控制亮度衰减速度；当前默认分别为 0.7 个字宽和 65%。"
                        )
                        footerDescription(
                            "长音与光效",
                            "达到阈值的字或词会依次膨胀；光效开关只控制辉光，不影响高光、抬升和膨胀。"
                        )
                    }
                }
            }

            Section {
                Toggle("启用伪逐字歌词", isOn: $settings.lyricsPseudoWordByWord)
            } header: {
                Text("伪逐字歌词")
            } footer: {
                Text("仅在歌曲没有 YRC 时按行时长估算逐字进度，准确度低于官方逐字歌词。")
            }

            Section {
                Picker(
                    "屏幕常亮",
                    selection: $settings.playerScreenAwakeMode
                ) {
                    ForEach(PlayerScreenAwakeMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            } header: {
                Text("屏幕常亮")
            } footer: {
                Text("决定竖屏播放器何时阻止自动锁屏；横屏天际歌词使用独立设置。")
            }

            Section {
                Toggle("双击歌词跳转", isOn: $settings.lyricsTapToSeek)

                valueSlider(
                    title: "歌词提前量",
                    value: $settings.lyricsAdvanceTime,
                    range: 0...5,
                    step: 0.1,
                    valueText: "\(settings.lyricsAdvanceTime.formatted(.number.precision(.fractionLength(1)))) 秒"
                )

                Toggle("浏览后恢复跟随", isOn: $settings.lyricsAutoFollow)

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
                Text("歌词交互")
            } footer: {
                settingsFooter {
                    footerDescription(
                        "歌词提前量",
                        "让当前行、逐字高光和悬浮歌词提前显示，不改变音频进度。"
                    )
                    footerDescription(
                        "恢复跟随",
                        "开启后，手动浏览歌词结束并等待指定时间，再返回当前播放行。"
                    )
                }
            }

            Section {
                Button("恢复播放器默认设置", role: .destructive) {
                    showsResetConfirmation = true
                }
                .disabled(isResettingSettings)
            } footer: {
                Text("同时重置均衡器、天际歌词、悬浮歌词和文字PV设置，不会删除账号或音乐数据。")
            }
        }
        .navigationTitle("播放器")
        .onChange(of: settings.playerVolumeControlMode) {
            player.applyVolumeControlMode()
        }
        .onChange(of: settings.systemNowPlayingLyricsEnabled) {
            player.applySystemNowPlayingLyricsPreference()
        }
        .onChange(of: settings.systemNowPlayingLyricsTitleFormat) {
            player.applySystemNowPlayingLyricsPreference()
        }
        .onChange(of: settings.systemNowPlayingLyricsSubtitleFormat) {
            player.applySystemNowPlayingLyricsPreference()
        }
        .onChange(of: settings.lyricsLiveActivityEnabled) {
            player.applyLyricsLiveActivityPreference()
        }
        .confirmationDialog("恢复播放器默认设置？", isPresented: $showsResetConfirmation) {
            Button("恢复默认设置", role: .destructive) {
                resetPlayerSettings()
            }
        }
    }

    private func resetPlayerSettings() {
        guard !isResettingSettings else { return }
        isResettingSettings = true

        Task { @MainActor in
            await PlayerSettingsResetter.reset(
                settings: settings,
                player: player
            )
            isResettingSettings = false
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

    private func settingsFooter<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
    }

    private func footerDescription(
        _ title: String,
        _ description: String
    ) -> Text {
        Text(
            "\(Text("\(title)：").fontWeight(.semibold))\(description)"
        )
    }
}
