import SwiftUI

struct DesktopCommands: Commands {
    let model: DesktopAppModel

    var body: some Commands {
        DesktopSystemCommands()
        DesktopPlaybackCommands(model: model)
        DesktopNavigationCommands(model: model)
    }
}

private struct DesktopSystemCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("关于 MeloX") { openWindow(id: "about") }
        }

        CommandGroup(replacing: .systemServices) {}
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .toolbar) {}
        CommandGroup(replacing: .sidebar) {}
        CommandGroup(replacing: .windowArrangement) {}
        CommandGroup(replacing: .help) {}
    }
}

private struct DesktopPlaybackCommands: Commands {
    let model: DesktopAppModel
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
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

            DesktopPlaybackQualityMenu(model: model)

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
    }
}

private struct DesktopNavigationCommands: Commands {
    let model: DesktopAppModel

    var body: some Commands {
        CommandMenu("导航") {
            Button("搜索") { model.ui.selection = .search }
                .keyboardShortcut("f", modifiers: .command)
            Button("主页") { model.ui.selection = .home }
                .keyboardShortcut("1", modifiers: .command)
            Button("新发现") { model.ui.selection = .discovery }
                .keyboardShortcut("2", modifiers: .command)
            if model.isSectionEnabled(.radio) {
                Button("广播") { model.ui.selection = .radio }
                    .keyboardShortcut("3", modifiers: .command)
            }
        }
    }
}
