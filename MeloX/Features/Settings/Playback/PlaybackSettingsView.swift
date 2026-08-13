import SwiftUI

struct PlaybackSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker("无线网络播放音质", selection: qualityBinding) {
                    ForEach(MusicQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }

                Picker(
                    "蜂窝网络播放音质",
                    selection: $settings.cellularQuality
                ) {
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
            } header: {
                Text("播放")
            } footer: {
                Text(
                    "音质受歌曲版权和账号权限限制；Hi-Res、环绕声与"
                        + "超清母带仅在曲目支持时可用，不支持时会自动降级。"
                        + settings.playerVolumeControlMode.description
                )
            }

            Section {
                NavigationLink {
                    EqualizerSettingsView()
                } label: {
                    LabeledContent(
                        "均衡器",
                        value: settings.equalizer.summary
                    )
                }

                NavigationLink {
                    AutoMixSettingsView()
                } label: {
                    LabeledContent(
                        "自动混音",
                        value: player.isAutoMixEnabled
                            ? settings.autoMix.mode.title
                            : "关闭"
                    )
                }
            } header: {
                Text("音频处理")
            } footer: {
                Text(
                    AppFeatureAvailability.downloads
                        ? "均衡器和自动混音会同时作用于网络播放和已下载歌曲。"
                        : "均衡器和自动混音会同时作用于歌曲播放。"
                )
            }

            Section {
                Toggle(
                    "启动时自动从心动模式播放",
                    isOn: $settings.startsHeartModeOnLaunch
                )

                Toggle(
                    "记住播放器页面",
                    isOn: $settings.rememberNowPlayingPage
                )

                Toggle(
                    "上一首优先回到歌曲开头",
                    isOn: $settings.previousRestartsCurrentSong
                )
            } header: {
                Text("播放行为")
            } footer: {
                Text(
                    "自动心动模式需要登录网易云音乐；开启后会在下次启动时"
                        + "载入“我喜欢的音乐”并开始播放。"
                        + "页面记忆会恢复上次停留的封面、歌词或队列。"
                        + "开启“上一首优先回到歌曲开头”后，播放超过 5 秒会先回到本曲开头。"
                )
            }
        }
        .navigationTitle("播放与音频")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings.playerVolumeControlMode) {
            player.applyVolumeControlMode()
        }
    }

    private var qualityBinding: Binding<MusicQuality> {
        Binding(
            get: { settings.quality },
            set: { player.selectPlaybackQuality($0) }
        )
    }
}
