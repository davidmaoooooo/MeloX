import SwiftUI

struct ContentFeatureSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library

    var body: some View {
        Form {
            Section {
                ForEach(ContentFeature.availableCases) { feature in
                    Toggle(isOn: binding(for: feature)) {
                        Label {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(feature.title)
                                Text(feature.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: feature.systemImage)
                        }
                    }
                }
            } header: {
                Text("可选功能")
            } footer: {
                Text("关闭后会隐藏相关入口并停止主动载入对应内容，不会删除收藏、下载、云盘歌曲或播放记录。")
            }
        }
        .navigationTitle("功能模块")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(
        for feature: ContentFeature
    ) -> Binding<Bool> {
        Binding(
            get: { settings.isContentFeatureEnabled(feature) },
            set: { isEnabled in
                settings.setContentFeature(
                    feature,
                    isEnabled: isEnabled
                )
                guard isEnabled,
                      feature == .podcasts
                        || feature == .listeningHistory else {
                    return
                }
                Task { await library.refresh(force: true) }
            }
        )
    }
}
