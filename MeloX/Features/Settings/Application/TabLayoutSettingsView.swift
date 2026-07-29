import SwiftUI

struct TabLayoutSettingsView: View {
    @Environment(AppSettings.self) private var settings

    @State private var showsResetConfirmation = false

    var body: some View {
        List {
            Section {
                ForEach(LibraryPage.allCases) { page in
                    Toggle(
                        isOn: Binding(
                            get: {
                                settings.isLibraryPageSeparated(page)
                            },
                            set: {
                                settings.setLibraryPage(
                                    page,
                                    isSeparated: $0
                                )
                            }
                        )
                    ) {
                        Label(page.title, systemImage: page.systemImage)
                    }
                }
            } header: {
                Text("独立标签页")
            } footer: {
                Text("开启后，该页面会从音乐库分类中移出，并显示为单独的标签页。关闭后会回到音乐库。")
            }

            Section {
                ForEach(settings.visibleTabs) { tab in
                    HStack(spacing: 12) {
                        Label(tab.title, systemImage: tab.systemImage)

                        Spacer(minLength: 8)

                        if tab == .search {
                            Text("系统固定")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if tab.libraryPage != nil {
                            Text("已拆分")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .contentShape(.rect)
                    .moveDisabled(tab == .search)
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
                Text("标签栏顺序")
            } footer: {
                Text("轻点右上角“编辑”，再拖动标签页。搜索标签使用系统搜索角色，因此固定在末尾；为了便于快速切换，建议在 iPhone 上保留不超过 5 个标签页。")
            }

            Section {
                Button(
                    "恢复默认标签布局",
                    systemImage: "arrow.counterclockwise",
                    role: .destructive
                ) {
                    showsResetConfirmation = true
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("标签页与音乐库")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            EditButton()
        }
        .confirmationDialog(
            "恢复默认标签布局？",
            isPresented: $showsResetConfirmation,
            titleVisibility: .visible
        ) {
            Button("恢复默认布局", role: .destructive) {
                settings.resetTabLayout()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("云盘会恢复为独立标签页，其他分类回到音乐库，标签顺序也会还原。")
        }
    }
}
