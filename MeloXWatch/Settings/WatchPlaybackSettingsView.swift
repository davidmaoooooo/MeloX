import SwiftUI

struct WatchAudioSettingsView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator

    @AppStorage(WatchPreferenceKey.streamingQuality)
    private var qualityRawValue = WatchStreamingQuality.high.rawValue

    var body: some View {
        Form {
            Section {
                Picker("播放音质", selection: $qualityRawValue) {
                    ForEach(WatchStreamingQuality.allCases) { quality in
                        Text(quality.title).tag(quality.rawValue)
                    }
                }
            } header: {
                Text("流媒体")
            } footer: {
                Text("音质受歌曲版权和网易云账号权限限制；修改后会从当前进度重新载入音源。")
            }

            Section("音量") {
                LabeledContent(
                    "当前音量",
                    value: coordinator.volume.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )

                Slider(
                    value: Binding(
                        get: { coordinator.volume },
                        set: { coordinator.setVolume($0) }
                    ),
                    in: 0...1
                )
                .accessibilityLabel("音量")
            }
        }
        .navigationTitle("音质与音量")
        .onChange(of: qualityRawValue) {
            Task {
                await coordinator.reloadForSelectedQuality()
            }
        }
    }
}

struct WatchPlaybackBehaviorSettingsView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator

    @AppStorage(WatchPreferenceKey.autoPlaySelection)
    private var autoPlaySelection = true
    @AppStorage(WatchPreferenceKey.previousButtonBehavior)
    private var previousBehaviorRawValue =
        WatchPreviousButtonBehavior.restartAfterFiveSeconds.rawValue
    @AppStorage(WatchPreferenceKey.restoresLastSession)
    private var restoresLastSession = true
    @AppStorage(WatchPreferenceKey.resumesAfterInterruption)
    private var resumesAfterInterruption = true

    var body: some View {
        Form {
            Section("队列") {
                Picker(
                    "循环方式",
                    selection: Binding(
                        get: { coordinator.repeatMode },
                        set: { coordinator.setRepeatMode($0) }
                    )
                ) {
                    ForEach(WatchRepeatMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Toggle(
                    "随机播放",
                    isOn: Binding(
                        get: { coordinator.isShuffled },
                        set: { coordinator.setShuffleEnabled($0) }
                    )
                )
            }

            Section("操作") {
                Toggle("选择歌曲后自动播放", isOn: $autoPlaySelection)

                Picker(
                    "上一首按钮",
                    selection: $previousBehaviorRawValue
                ) {
                    ForEach(WatchPreviousButtonBehavior.allCases) { behavior in
                        Text(behavior.title).tag(behavior.rawValue)
                    }
                }
            }

            Section {
                Toggle("恢复上次队列和进度", isOn: $restoresLastSession)
                Toggle("中断结束后继续播放", isOn: $resumesAfterInterruption)
            } header: {
                Text("恢复")
            } footer: {
                Text("恢复播放只使用手表本地保存的数据，不依赖 iPhone。")
            }
        }
        .navigationTitle("播放行为")
        .onChange(of: restoresLastSession) { _, isEnabled in
            coordinator.setRestoresLastSession(isEnabled)
        }
    }
}
