import SwiftUI

struct DesktopAboutReleaseNotesView: View {
    @Environment(DesktopAppModel.self) private var model

    let releaseNotes: AppReleaseNotes?
    let currentVersion: String

    @State private var showsResetConfirmation = false
    @State private var isResettingSettings = false
    @State private var hasResetPlayerSettings = false

    init(
        releaseNotes: AppReleaseNotes?,
        currentVersion: String = Bundle.main.appReleaseVersion
    ) {
        self.releaseNotes = releaseNotes
        self.currentVersion = currentVersion
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text("MeloX \(displayVersion)")
                        .font(.title2.bold())

                    Text("当前版本更新日志")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section {
                if visibleEntries.isEmpty {
                    ContentUnavailableView(
                        "暂无更新内容",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text(emptyStateDescription)
                    )
                    .frame(maxWidth: .infinity)
                } else {
                    ForEach(visibleEntries.indices, id: \.self) { index in
                        Text(visibleEntries[index])
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } header: {
                Text("更新内容")
            } footer: {
                if let previousVersion = releaseNotes?.displayPreviousVersion {
                    Text(
                        "版本范围：MeloX \(previousVersion) 至 "
                            + "MeloX \(displayVersion)"
                    )
                }
            }

            Section {
                Button(role: .destructive) {
                    showsResetConfirmation = true
                } label: {
                    HStack {
                        Label(
                            hasResetPlayerSettings
                                ? "已恢复作者推荐设置"
                                : "恢复作者推荐的播放器设置",
                            systemImage: hasResetPlayerSettings
                                ? "checkmark.circle"
                                : "arrow.counterclockwise"
                        )

                        Spacer()

                        if isResettingSettings {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(
                    isResettingSettings || hasResetPlayerSettings
                )
                .confirmationDialog(
                    "恢复作者推荐的播放器设置？",
                    isPresented: $showsResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("恢复并体验", role: .destructive) {
                        resetPlayerSettings()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text(
                        "这会永久覆盖并丢失你原先自定义的播放器设置，"
                            + "恢复为作者当前的推荐调教。"
                    )
                }
            } header: {
                Text("体验优化后的调教")
            } footer: {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        "这会恢复作者当前推荐的播放器参数，并覆盖、丢失你原先的自定义设置。",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)

                    Text(resetScopeDescription)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("更新日志")
    }

    private var displayVersion: String {
        releaseNotes?.displayVersion
            ?? AppVersion.displayName(for: currentVersion)
    }

    private var visibleEntries: [String] {
        let entries = releaseNotes?.entries ?? []
        guard !AppFeatureAvailability.downloads else { return entries }
        return entries.filter { !$0.contains("下载") }
    }

    private var resetScopeDescription: String {
        if AppFeatureAvailability.downloads {
            return "重置范围包含播放器、歌词、均衡器、全屏天际歌词、"
                + "悬浮歌词与文字 PV；账号、下载、歌单和播放记录"
                + "不会受到影响。"
        }
        return "重置范围包含播放器、歌词、均衡器、全屏天际歌词、"
            + "悬浮歌词与文字 PV；账号、歌单和播放记录不会受到影响。"
    }

    private var emptyStateDescription: String {
        if releaseNotes == nil {
            return "此构建未包含有效的更新日志。"
        }
        return "本次没有需要公开展示的更新内容。"
    }

    private func resetPlayerSettings() {
        guard !isResettingSettings else { return }
        isResettingSettings = true

        Task { @MainActor in
            await DesktopPlayerSettingsResetter.reset(model: model)
            isResettingSettings = false
            hasResetPlayerSettings = true
        }
    }
}
