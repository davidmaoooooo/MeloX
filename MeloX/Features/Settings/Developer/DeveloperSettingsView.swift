import SwiftUI

struct DeveloperSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Toggle(
                    "BeatNet 实时调试面板",
                    isOn: $settings.beatNetDebugEnabled
                )

                LabeledContent(
                    "入口",
                    value: "播放器“…”菜单"
                )
            } header: {
                Text("调试")
            } footer: {
                Text(
                    "此开关只控制播放器更多菜单中的调试入口。正常播放时的分析由“播放器外观”中的“重拍暗角”独立控制。"
                )
            }
        }
        .navigationTitle("开发者选项")
        .navigationBarTitleDisplayMode(.inline)
    }
}
