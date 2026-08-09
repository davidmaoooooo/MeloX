import SwiftUI

@main
struct MeloXDesktopApp: App {
    @State private var model = DesktopAppModel()

    var body: some Scene {
        WindowGroup("MeloX") {
            DesktopRootView()
                .environment(model)
                .environment(model.screenAwakeCoordinator)
                .preferredColorScheme(
                    model.settings.appearance.preferredColorScheme
                )
                .frame(
                    minWidth: DesktopMainWindowMetrics.minimumContentWidth,
                    minHeight: DesktopMainWindowMetrics.minimumContentHeight
                )
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .windowToolbarLabelStyle(fixed: .iconOnly)
        .defaultSize(width: 1_272, height: 600)
        .commands {
            DesktopCommands(model: model)
        }

        Window("迷你播放器", id: "mini-player") {
            DesktopMiniPlayerWindow()
                .environment(model)
                .preferredColorScheme(model.settings.appearance.preferredColorScheme)
        }
        .windowStyle(.plain)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.disabled)
        .defaultSize(width: 320, height: 145)

        Window("桌面歌词", id: "floating-lyrics") {
            DesktopFloatingLyricsWindow()
                .environment(model)
                .preferredColorScheme(model.settings.appearance.preferredColorScheme)
        }
        .windowStyle(.plain)
        .windowLevel(.floating)
        .windowResizability(.contentMinSize)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(
            width: DesktopFloatingLyricsWindowMetrics.defaultWidth,
            height: DesktopFloatingLyricsWindowMetrics.defaultHeight
        )

        Window("", id: "about") {
            DesktopAboutView()
                .preferredColorScheme(model.settings.appearance.preferredColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .windowBackgroundDragBehavior(.enabled)
        .defaultSize(width: 600, height: 320)
        .defaultPosition(.center)

        Window("版权声明", id: "licenses") {
            NavigationStack {
                DesktopProjectLicensesView()
            }
            .preferredColorScheme(model.settings.appearance.preferredColorScheme)
            .frame(width: 680, height: 680)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 680, height: 680)

        Settings {
            DesktopSettingsView()
                .environment(model)
                .preferredColorScheme(model.settings.appearance.preferredColorScheme)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 650, height: 650)
    }
}

private struct DesktopCommands: Commands {
    let model: DesktopAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .sidebar) {}

        CommandGroup(replacing: .appInfo) {
            Button("关于 MeloX") { openWindow(id: "about") }
        }

        CommandMenu("控制") {
            Button(model.player.isPlaying ? "暂停" : "播放") {
                model.player.togglePlayback()
            }
            .keyboardShortcut(.space, modifiers: [])
            .disabled(model.player.currentSong == nil)

            Button("上一首") {
                Task { await model.player.previous() }
            }
            .keyboardShortcut(.leftArrow, modifiers: .command)
            .disabled(model.player.currentSong == nil)

            Button("下一首") {
                Task { await model.player.next() }
            }
            .keyboardShortcut(.rightArrow, modifiers: .command)
            .disabled(model.player.currentSong == nil)

            Divider()

            Button("随机播放") { model.player.toggleShuffle() }
                .keyboardShortcut("s", modifiers: [.command, .option])
            Button("切换循环模式") { model.player.cycleRepeatMode() }
                .keyboardShortcut("r", modifiers: [.command, .option])

            Divider()

            Button("显示歌词") { model.ui.toggleInspector(.lyrics) }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            Button("显示播放队列") { model.ui.toggleInspector(.queue) }
                .keyboardShortcut("q", modifiers: [.command, .shift])
            Button("正在播放") { model.ui.isNowPlayingPresented = true }
            Button("迷你播放器") { openWindow(id: "mini-player") }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Button("桌面歌词") { openWindow(id: "floating-lyrics") }
        }

        CommandMenu("导航") {
            Button("搜索") { model.ui.selection = .search }
                .keyboardShortcut("f", modifiers: .command)
            Button("主页") { model.ui.selection = .home }
                .keyboardShortcut("1", modifiers: .command)
            Button("新发现") { model.ui.selection = .discovery }
                .keyboardShortcut("2", modifiers: .command)
            Button("广播") { model.ui.selection = .radio }
                .keyboardShortcut("3", modifiers: .command)
            Divider()
            Button("播客") { model.ui.navigate(to: .section(.podcasts)) }
            Button("下载") { model.ui.navigate(to: .section(.downloads)) }
            Button("音乐云盘") { model.ui.navigate(to: .section(.cloud)) }
            Button("消息") { model.ui.navigate(to: .section(.messages)) }
            Divider()
            Button("听歌识曲") { model.ui.sheet = .recognition }
            Button("一起听") { model.ui.sheet = .listenTogether }
        }
    }
}
