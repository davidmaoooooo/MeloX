import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section {
                Picker(
                    "主题",
                    selection: $settings.appearance
                ) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Label(
                            appearance.title,
                            systemImage: appearance.systemImage
                        )
                        .tag(appearance)
                    }
                }
            } header: {
                Text("外观")
            } footer: {
                Text("跟随系统会根据设备外观自动切换浅色和深色主题。")
            }

            Section {
                Toggle(
                    "启动时继续上次页面",
                    isOn: $settings.restoresLastSelectedTab
                )

                Picker("默认启动页面", selection: $settings.defaultLaunchTab) {
                    ForEach(settings.visibleTabs) { tab in
                        Label(
                            tab.settingsTitle,
                            systemImage: tab.systemImage
                        )
                            .tag(tab)
                    }
                }
                .disabled(settings.restoresLastSelectedTab)
            } header: {
                Text("启动与导航")
            } footer: {
                if settings.restoresLastSelectedTab {
                    Text("下次启动时会回到最后使用的主页面。关闭后，将打开所选的默认启动页面。")
                } else {
                    Text("默认启动页面会在下次启动 MeloX 时生效。")
                }
            }

            Section {
                Toggle(
                    "识别剪贴板中的网易云链接",
                    isOn: $settings.recognizesClipboardLinksOnLaunch
                )
            } header: {
                Text("剪贴板")
            } footer: {
                Text(
                    "开启后，MeloX 会在每次启动时读取一次剪贴板；识别到网易云歌曲或一起听链接时，会先询问是否打开。系统可能显示粘贴权限提示。"
                )
            }

            if !settings.embeddedLibraryPages.isEmpty {
                Section {
                    Toggle(
                        "记住上次音乐库页面",
                        isOn: $settings.restoresLastLibraryPage
                    )

                    Picker(
                        "默认打开页面",
                        selection: $settings.defaultLibraryPage
                    ) {
                        ForEach(settings.embeddedLibraryPages) { page in
                            Label(page.title, systemImage: page.systemImage)
                                .tag(page)
                        }
                    }
                    .disabled(settings.restoresLastLibraryPage)
                } header: {
                    Text("音乐库")
                } footer: {
                    if settings.restoresLastLibraryPage {
                        Text("重新启动后，音乐库会恢复到最后浏览的内置页面。")
                    } else {
                        Text("每次启动 MeloX 后首次打开音乐库时，会显示所选页面。")
                    }
                }
            }
        }
        .navigationTitle("通用")
        .navigationBarTitleDisplayMode(.inline)
    }
}
