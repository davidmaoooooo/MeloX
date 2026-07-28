import SwiftUI

struct WatchMenuView: View {
    @EnvironmentObject private var coordinator: WatchPlaybackCoordinator
    @EnvironmentObject private var account: WatchAccountStore
    @EnvironmentObject private var connectivity: WatchConnectivityStore

    let api: WatchNeteaseAPI

    var body: some View {
        List {
            Section("播放") {
                NavigationLink {
                    WatchQueueView()
                        .navigationTitle("播放队列")
                } label: {
                    Label("播放队列", systemImage: "list.bullet")
                }

                Button {
                    coordinator.toggleShuffle()
                } label: {
                    Label(
                        coordinator.isShuffled ? "关闭随机播放" : "随机播放",
                        systemImage: "shuffle"
                    )
                }

                Button {
                    coordinator.cycleRepeatMode()
                } label: {
                    Label(
                        repeatTitle,
                        systemImage: coordinator.repeatMode == .one
                            ? "repeat.1"
                            : "repeat"
                    )
                }
            }

            Section("发现音乐") {
                NavigationLink {
                    WatchSearchView(api: api)
                } label: {
                    Label("搜索", systemImage: "magnifyingglass")
                }

                NavigationLink {
                    WatchDailySongsView(api: api)
                } label: {
                    Label("每日推荐", systemImage: "calendar")
                }

                NavigationLink {
                    WatchPlaylistsView(api: api)
                } label: {
                    Label("我的歌单", systemImage: "music.note.list")
                }
            }

            Section("账户与设备") {
                NavigationLink {
                    WatchAccountView(api: api)
                } label: {
                    Label(
                        account.profile?.nickname
                            ?? (account.isLoggedIn ? "网易云账号" : "登录"),
                        systemImage: account.isLoggedIn
                            ? "person.crop.circle.fill"
                            : "person.crop.circle.badge.plus"
                    )
                }

                NavigationLink {
                    WatchSettingsView()
                } label: {
                    Label("设置", systemImage: "gearshape")
                }

                Button {
                    connectivity.requestSnapshot()
                } label: {
                    Label(
                        "导入 iPhone 登录",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
            }
        }
        .navigationTitle("MeloX")
    }

    private var repeatTitle: String {
        switch coordinator.repeatMode {
        case .off: "循环：关闭"
        case .all: "循环：列表"
        case .one: "循环：单曲"
        }
    }
}
