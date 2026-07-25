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
                        "音质",
                        "决定向网易云请求的在线播放音源规格。标准约为 128 kbps，高品质约为 320 kbps，无损会请求 FLAC；歌曲版权或账号不支持所选音质时，实际返回结果可能降低。"
                    )
                    footerDescription(
                        "音量控制",
                        "当前选择“\(settings.playerVolumeControlMode.title)”。\(settings.playerVolumeControlMode.description)"
                    )
                    footerDescription(
                        "均衡器",
                        "进入后可启用 10 段图形均衡器、选择预设，并调整前置放大与各频段增益；设置会实时作用于网络播放和已下载歌曲。"
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
                        "背景模糊",
                        "调整展开播放器中封面背景的模糊半径。数值越大，封面细节越少、颜色过渡越柔和；设为 0 时不添加模糊。"
                    )
                    footerDescription(
                        "背景色彩",
                        "调整封面背景的色彩饱和度。数值越低越接近灰色，数值越高颜色越鲜艳；修改会实时显示在展开的播放器中。"
                    )
                    footerDescription(
                        "暂停时缩小封面",
                        "开启后，暂停播放时封面会缩小到原尺寸的 90%，继续播放时恢复；关闭后封面在播放和暂停状态下保持相同大小。"
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
                        "记住所处页面",
                        "开启后会记住你最后停留的封面、歌词或播放队列页面，下次展开播放器时回到该页面；关闭后始终从封面页打开。"
                    )
                    footerDescription(
                        "上一首优先回到歌曲开头",
                        "开启后，当前歌曲已播放超过 5 秒时按“上一首”会先回到本曲开头，再次按下才切换上一首；关闭后会直接切换上一首。"
                    )
                }
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
                settingsFooter {
                    footerDescription(
                        "全屏天际歌词",
                        "进入后可调整播放器横屏时的歌词字号、布局、屏幕常亮及背景动态效果。这里的设置只影响天际歌词，不会改变竖屏播放器中的歌词样式。"
                    )
                }
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
                settingsFooter {
                    footerDescription(
                        "悬浮窗歌词",
                        "进入后可配置系统画中画歌词的外观与行为。启动悬浮歌词后，即使切换到其他应用，也会在画中画窗口中显示当前歌词和下一句。"
                    )
                }
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
                        "歌词样式",
                        "当前选择“\(settings.lyricsStyle.title)”：\(settings.lyricsStyle.description)。Apple Music 使用滚动与逐字动效；EVA 和文字PV使用各自的模板排版。"
                    )
                    if settings.lyricsStyle == .textPV {
                        footerDescription(
                            "文字PV设置",
                            "进入后可选择文字PV模板，并调整该模板独立的排版、图层和后期效果。"
                        )
                    }
                    footerDescription(
                        "字体大小",
                        "设置歌词正文的基准字号。翻译字号会按这个数值的比例计算；EVA 等样式可能在模板中继续按屏幕尺寸缩放。"
                    )
                    footerDescription(
                        "歌词字体粗细",
                        "调整原文、翻译和全屏天际歌词的字重。EVA 与文字PV仍会保留各自模板指定的字体设计。"
                    )
                    if settings.lyricsStyle == .appleMusic {
                        footerDescription(
                            "当前歌词大小",
                            "控制当前播放行相对普通歌词行的放大比例。100% 表示不额外放大，数值越高，当前行越突出。"
                        )
                        footerDescription(
                            "歌词行距",
                            "调整相邻歌词行之间的垂直间隔。数值越大，页面越疏朗，同时屏幕内可见的歌词行数会减少。"
                        )
                        footerDescription(
                            "基础模糊强度",
                            "控制非焦点歌词的整体模糊基准，并作为逐句距离模糊的基础。设为 0 时关闭歌词模糊；数值越高，焦点行与其他行的层次越明显。"
                        )
                        footerDescription(
                            "默认逐句模糊加强",
                            "控制播放器控制栏可见时，歌词离焦点越远所增加的模糊程度。0% 会移除按距离增加的部分，100% 使用完整强度，不影响基础的相邻行模糊。"
                        )
                        footerDescription(
                            "隐藏 UI 逐句模糊加强",
                            "与上一项作用相同，但只在歌词页隐藏控制栏后生效，可单独设置更清晰或更柔和的沉浸效果。"
                        )
                        footerDescription(
                            "非焦点歌词变暗",
                            "控制当前行之外歌词的透明度衰减。0% 时各行基本保持同等明亮，100% 时完整应用随距离变暗的层次。"
                        )
                        footerDescription(
                            "焦点垂直位置",
                            "决定当前播放行在歌词视口中的锚点。百分比表示距顶部的位置；数值越大，当前行越靠近屏幕下方。"
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
                        "决定歌词进度、高光和动态效果每秒更新的次数，并应用到所有歌词页面。数值越高，移动越平滑，但会增加处理器负载和耗电；实际帧率仍受设备屏幕上限影响。"
                    )
                    footerDescription(
                        "自动限制",
                        "高负载文字PV模板会自动限制为 30 FPS，以保证播放器操作流畅。系统进入低电量模式时也会暂时降至 30 FPS，退出后恢复你选择的频率。"
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
                        "基础拖尾延迟",
                        "为后续歌词逐行增加启动间隔。数值越大，各行依次跟随的层次越明显；设为 0 时不添加这部分逐行延迟。"
                    )
                    footerDescription(
                        "逐句拖尾增量",
                        "让越靠后的歌词行在基础拖尾之上继续增加间隔。数值越大，队尾展开得越慢；设为 0 时每一行只使用固定的基础拖尾。"
                    )
                    footerDescription(
                        "后续歌词启动延迟",
                        "当前句及上方歌词开始移动后，下一句及下方歌词统一等待的时间。它会与基础拖尾和逐句增量叠加；设为 0 时立即开始后续队列。"
                    )
                    footerDescription(
                        "拖尾追赶节奏",
                        "决定延迟启动的歌词应在整段动画的哪个时间点附近完成追赶。数值越低，后续行移动得越快、越早追上；数值越高，拖尾保留得越久。"
                    )
                    footerDescription(
                        "追赶速度梯度",
                        "控制越靠后的歌词是否使用更强的追赶速度。0% 时各行移动时长接近一致，100% 时完整应用逐行加速差异。"
                    )
                    footerDescription(
                        "位移收束时长",
                        "设置歌词换句位移希望使用的基准时长。数值越小越干脆，数值越大越舒缓；歌词间隔很短时，系统会压缩动画以避免落后于播放进度。"
                    )
                    footerDescription(
                        "瞬移阈值",
                        "当距离下一次歌词切换的剩余时间短于该值时，跳过拖尾过程并直接对齐焦点，避免密集歌词连续积压。"
                    )
                    footerDescription(
                        "启用位移回弹",
                        "开启后，歌词行到达新位置时会带有弹簧式收束；关闭后使用无回弹的平滑位移。"
                    )
                    if settings.lyricsFocusCascadeBounceEnabled {
                        footerDescription(
                            "最大回弹弹性",
                            "设置歌词位移动画可使用的最大弹性。数值越高，越过目标位置后的回摆越明显。"
                        )
                        footerDescription(
                            "回弹强度梯度",
                            "控制回弹是否沿后续歌词逐行增强。0% 时各行回弹接近一致，100% 时前方较弱、越靠后的歌词越接近最大弹性。"
                        )
                    }
                    footerDescription(
                        "启用升格回弹",
                        "控制当前歌词切换为焦点并放大时是否使用独立的弹簧动画，不影响整页歌词的位移回弹。"
                    )
                    if settings.lyricsFocusScaleBounceEnabled {
                        footerDescription(
                            "升格回弹时长",
                            "设置当前行从普通大小过渡到焦点大小的动画时长。数值越小响应越快，数值越大变化越柔和。"
                        )
                        footerDescription(
                            "升格回弹弹性",
                            "设置当前行放大时的弹性。数值越高，超过目标大小后再回落的效果越明显。"
                        )
                    }
                    footerDescription(
                        "焦点颜色提前",
                        "调整当前行颜色变化与整页位移的先后关系。正值表示颜色先变化、等待指定时间后再移动；负值表示先移动、随后才变化颜色；0 毫秒表示同时开始。"
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
                        "显示歌词翻译",
                        "显示网易云返回的 ytlrc 或 tlyric 翻译；歌曲没有翻译数据时不会生成或显示替代内容。关闭后只显示原文。"
                    )
                    if settings.lyricsTranslationEnabled {
                        if settings.lyricsStyle == .appleMusic {
                            footerDescription(
                                "翻译显示方式",
                                "“仅当前播放行”会在换句时收起旧翻译、淡入新翻译，并让高度变化参与整页位移；“全部歌词行”会为所有可用翻译持续保留空间。"
                            )
                        }
                        footerDescription(
                            "翻译歌词大小",
                            "按原文基准字号的百分比设置翻译大小。数值越高，翻译越接近原文大小；过小时仍会保留最低可读字号。"
                        )
                        footerDescription(
                            "翻译歌词亮度",
                            "调整翻译文字的不透明度。数值越高越明亮清晰，数值越低越弱化，从而让原文更突出。"
                        )
                    }
                    footerDescription(
                        "逐字歌词",
                        "使用歌曲自带的 YRC 时间轴，让高光、抬升和长音效果跟随字词播放。关闭后按整句切换；没有 YRC 的歌曲需要另行启用伪逐字歌词。"
                    )
                    if settings.lyricsWordByWord
                        || settings.lyricsPseudoWordByWord {
                        footerDescription(
                            "抬升方式",
                            "“按字抬升”会让每个字随自己的进度依次上移；“按词抬升”会让同一词内的字一起上移。该选项只改变抬升分组，不会改变逐字高光的时间轴。"
                        )
                        footerDescription(
                            "高光渐变宽度",
                            "设置高光越过当前播放位置后继续覆盖的范围，单位为平均字宽。数值越小边界越集中，数值越大后一个字承接得越柔和；默认是 0.7 个字宽。"
                        )
                        footerDescription(
                            "渐变削减程度",
                            "调整高光在设定宽度内的衰减曲线。渐变始终从当前播放边界的满亮状态连续过渡，不会突然切换；0% 接近线性衰减，数值越高，后一个字越早降低亮度。默认是 65%。"
                        )
                        footerDescription(
                            "逐字歌词光效",
                            "控制逐字播放时的外发光。关闭后仍保留逐字高光、抬升和长音膨胀，只移除辉光。"
                        )
                        footerDescription(
                            "长音识别方式",
                            "“按字识别”分别检查每个字或音节的持续时间；“按词识别”使用整个词的持续时间，并让词内各字依次进入膨胀与辉光动画。"
                        )
                        footerDescription(
                            "长音判定阈值",
                            "持续时间达到该值的字或词才会被视为长音。数值越低，更多普通音节会触发；数值越高，只保留持续更久的长音。"
                        )
                        footerDescription(
                            "长音膨胀大小",
                            "设置长音在动画峰值时的最大放大幅度。0% 会关闭膨胀，数值越高字形越饱满；默认最大 5%，刚达到阈值的长音会按时长使用较弱幅度。"
                        )
                        if settings.lyricsGlowEnabled {
                            footerDescription(
                                "仅长音显示辉光",
                                "开启后只有达到长音阈值的字或词会发光；关闭后普通播放中的字词也会出现短暂辉光。无论是否开启，膨胀仍只用于长音。"
                            )
                            footerDescription(
                                "逐字光效强度",
                                "同时调整辉光的亮度与扩散半径。数值越高，光晕越亮、覆盖范围越大；不会改变高光进度或长音膨胀大小。"
                            )
                        }
                    }
                }
            }

            Section {
                Toggle("启用伪逐字歌词", isOn: $settings.lyricsPseudoWordByWord)
            } header: {
                Text("伪逐字歌词")
            } footer: {
                settingsFooter {
                    footerDescription(
                        "启用伪逐字歌词",
                        "只在整首歌没有网易云 YRC 时间轴时，根据每行的持续时间和字符数量估算逐字进度。它不能还原真实演唱停顿，准确度低于官方逐字歌词；检测到 YRC 时会自动忽略此功能。"
                    )
                    footerDescription(
                        "与逐字歌词的关系",
                        "该开关可独立开启：有 YRC 的歌曲由上方“逐字歌词”控制，没有 YRC 的歌曲才由此处生成模拟进度。"
                    )
                }
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
                settingsFooter {
                    footerDescription(
                        "关闭",
                        "播放器不会干预系统自动锁屏。"
                    )
                    footerDescription(
                        "播放器常亮",
                        "只要展开播放器，就阻止系统自动锁屏，无论当前显示封面、歌词还是队列。"
                    )
                    footerDescription(
                        "歌词页常亮",
                        "仅在展开播放器并停留于歌词页时保持屏幕常亮。"
                    )
                    footerDescription(
                        "歌词页隐藏 UI 后常亮",
                        "只有进入歌词页并隐藏播放器控制栏时才保持常亮，控制栏重新出现后恢复系统锁屏规则。"
                    )
                    footerDescription(
                        "适用范围",
                        "这里控制竖屏播放器；横屏天际歌词使用其设置页面中的独立常亮选项。"
                    )
                }
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
                        "双击歌词跳转",
                        "开启后，双击任意歌词行会把播放进度跳转到该行的开始时间；关闭后浏览歌词不会改变歌曲进度。"
                    )
                    footerDescription(
                        "歌词提前量",
                        "把歌词使用的时间轴整体向前偏移。数值越大，当前行切换、逐字高光和悬浮歌词都会更早出现；不会改变音频本身的播放位置。"
                    )
                    footerDescription(
                        "浏览后恢复跟随",
                        "开启后，在 Apple Music 歌词页手动滚动查看其他歌词后，会自动回到当前播放行；关闭后保持在你浏览的位置。"
                    )
                    if settings.lyricsAutoFollow {
                        footerDescription(
                            "恢复跟随等待",
                            "从最后一次手动浏览结束后开始计时，达到所选秒数才滚回当前播放行；继续滚动会重新计时。"
                        )
                    }
                }
            }

            Section {
                Button("恢复播放器默认设置", role: .destructive) {
                    showsResetConfirmation = true
                }
                .disabled(isResettingSettings)
            } footer: {
                settingsFooter {
                    footerDescription(
                        "恢复播放器默认设置",
                        "重置本页以及均衡器、全屏天际歌词、悬浮歌词和文字PV的设置。不会退出账号，也不会删除下载、歌单或播放记录。"
                    )
                }
            }
        }
        .navigationTitle("播放器")
        .onChange(of: settings.playerVolumeControlMode) {
            player.applyVolumeControlMode()
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
            await Task.yield()

            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                settings.resetPlayerSettings()
            }

            await Task.yield()
            player.applyEqualizerSettings()
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
