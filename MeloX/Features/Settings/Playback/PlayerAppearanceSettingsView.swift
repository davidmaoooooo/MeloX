import SwiftUI

struct PlayerAppearanceSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
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
                    valueText:
                        "\(Int(settings.playerBackgroundSaturation * 100))%"
                )

                Toggle(
                    "暂停时缩小封面",
                    isOn: $settings.shrinksPausedArtwork
                )
            } header: {
                Text("背景与封面")
            } footer: {
                Text("背景选项会实时生效；开启暂停缩小后，封面会在暂停时缩至 90%。")
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
                Text("屏幕")
            } footer: {
                Text("决定竖屏播放器何时阻止自动锁屏；横屏天际歌词使用独立设置。")
            }
        }
        .navigationTitle("播放器外观")
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
