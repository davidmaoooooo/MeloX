import SwiftUI

struct WatchPlayerAppearanceSettingsView: View {
    @AppStorage(WatchPreferenceKey.shrinksPausedArtwork)
    private var shrinksPausedArtwork = false
    @AppStorage(WatchPreferenceKey.showsArtist)
    private var showsArtist = true
    @AppStorage(WatchPreferenceKey.playerBackgroundBlur)
    private var backgroundBlur = 18.0
    @AppStorage(WatchPreferenceKey.playerBackgroundDim)
    private var backgroundDim = 0.62
    @AppStorage(WatchPreferenceKey.playerBackgroundSaturation)
    private var backgroundSaturation = 1.15

    var body: some View {
        Form {
            Section("模糊封面背景") {
                LabeledContent(
                    "模糊半径",
                    value: backgroundBlur.formatted(
                        .number.precision(.fractionLength(0))
                    )
                )
                Slider(value: $backgroundBlur, in: 8...32)
                    .accessibilityLabel("背景模糊半径")

                LabeledContent(
                    "暗化程度",
                    value: backgroundDim.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                Slider(value: $backgroundDim, in: 0.35...0.85)
                    .accessibilityLabel("背景暗化程度")

                LabeledContent(
                    "饱和度",
                    value: backgroundSaturation.formatted(
                        .percent.precision(.fractionLength(0))
                    )
                )
                Slider(value: $backgroundSaturation, in: 0.5...1.5)
                    .accessibilityLabel("背景饱和度")
            }

            Section("封面") {
                Toggle("暂停时缩小封面", isOn: $shrinksPausedArtwork)
            }

            Section("信息") {
                Toggle("显示歌手", isOn: $showsArtist)
            }

            Section {
                Text("播放器采用固定单屏布局，封面、标题和播放按钮不会触发上下滚动。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("播放器外观")
    }
}
