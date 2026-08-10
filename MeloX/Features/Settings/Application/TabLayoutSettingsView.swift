import SwiftUI

struct TabLayoutSettingsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var showsResetConfirmation = false

    var body: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    Label(
                        AppTab.recommended.settingsTitle,
                        systemImage: AppTab.recommended.systemImage
                    )

                    Spacer(minLength: 8)

                    Text("固定在首页")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("推荐")
            } footer: {
                Text("推荐固定在首页首位，不参与移动。")
            }

            Section {
                ForEach(
                    AppTab.movablePrimaryContentPages.filter(
                        settings.isNavigationTabEnabled
                    )
                ) { tab in
                    placementPicker(for: tab)
                }
            } header: {
                Text("内容页面")
            } footer: {
                Text("可将首页内容移到底部标签栏，也可把发现和音乐库移入首页。")
            }

            Section {
                ForEach(
                    AppTab.libraryContentPages.filter(
                        settings.isNavigationTabEnabled
                    )
                ) { tab in
                    placementPicker(for: tab)
                }
            } header: {
                Text("收藏与本地")
            } footer: {
                Text("这些页面可放在首页、底部标签栏，或保留在音乐库内。")
            }

            Section {
                ForEach(settings.homeTabs) { tab in
                    orderRow(
                        for: tab,
                        trailingText:
                            tab == .recommended ? "固定" : nil
                    )
                    .moveDisabled(tab == .recommended)
                }
                .onMove { source, destination in
                    var tabs = settings.homeTabs
                    tabs.move(
                        fromOffsets: source,
                        toOffset: destination
                    )
                    settings.setHomeTabOrder(tabs)
                }
            } header: {
                Text("首页顺序")
            } footer: {
                Text("首页只剩推荐时，不会显示页面切换条。")
            }

            Section {
                ForEach(settings.visibleTabs) { tab in
                    orderRow(
                        for: tab,
                        trailingText: fixedTabDescription(for: tab)
                    )
                    .moveDisabled(tab == .home || tab == .search)
                }
                .onMove { source, destination in
                    var tabs = settings.visibleTabs
                    tabs.move(
                        fromOffsets: source,
                        toOffset: destination
                    )
                    settings.setVisibleTabOrder(tabs)
                }
            } header: {
                Text("底部标签栏顺序")
            } footer: {
                Text("首页入口固定在首位，系统搜索标签固定在末尾；轻点右上角“编辑”可拖动其他项目。")
            }

            Section {
                Button(
                    "恢复默认页面布局",
                    systemImage: "arrow.counterclockwise",
                    role: .destructive
                ) {
                    showsResetConfirmation = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("页面与标签栏")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .confirmationDialog(
            "恢复默认页面布局？",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("恢复默认布局", role: .destructive) {
                settings.resetTabLayout()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("推荐、音乐和播客会回到首页；云盘会放到底部标签栏，其他收藏与本地页面会回到音乐库。")
        }
    }

    private func placementPicker(
        for tab: AppTab
    ) -> some View {
        Picker(
            selection: Binding(
                get: { settings.placement(for: tab) },
                set: { settings.setPage(tab, placement: $0) }
            )
        ) {
            ForEach(tab.allowedPlacements) { placement in
                Text(placement.title)
                    .tag(placement)
            }
        } label: {
            Label(tab.settingsTitle, systemImage: tab.systemImage)
        }
        .pickerStyle(.menu)
    }

    private func orderRow(
        for tab: AppTab,
        trailingText: String?
    ) -> some View {
        HStack(spacing: 12) {
            Label(tab.settingsTitle, systemImage: tab.systemImage)

            Spacer(minLength: 8)

            if let trailingText {
                Text(trailingText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
    }

    private func fixedTabDescription(
        for tab: AppTab
    ) -> String? {
        switch tab {
        case .home:
            "固定入口"
        case .search:
            "系统固定"
        default:
            nil
        }
    }
}
