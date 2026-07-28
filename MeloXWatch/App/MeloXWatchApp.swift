import SwiftUI

@main
struct MeloXWatchApp: App {
    @StateObject private var account: WatchAccountStore
    @StateObject private var connectivity: WatchConnectivityStore
    @StateObject private var playback: WatchPlaybackStore
    @StateObject private var coordinator: WatchPlaybackCoordinator
    @StateObject private var lyrics: WatchLyricsStore

    private let api: WatchNeteaseAPI

    init() {
        WatchPreferenceDefaults.register()

        let account = WatchAccountStore()
        let client = WatchNeteaseClient {
            account.cookie
        }
        let api = WatchNeteaseAPI(client: client)
        let connectivity = WatchConnectivityStore(
            accountStore: account
        )
        let playback = WatchPlaybackStore(api: api)
        let coordinator = WatchPlaybackCoordinator(
            standalone: playback
        )
        let lyrics = WatchLyricsStore(api: api)

        self.api = api
        _account = StateObject(wrappedValue: account)
        _connectivity = StateObject(wrappedValue: connectivity)
        _playback = StateObject(wrappedValue: playback)
        _coordinator = StateObject(wrappedValue: coordinator)
        _lyrics = StateObject(wrappedValue: lyrics)
    }

    var body: some Scene {
        WindowGroup {
            WatchRootView(api: api)
                .environmentObject(account)
                .environmentObject(connectivity)
                .environmentObject(playback)
                .environmentObject(coordinator)
                .environmentObject(lyrics)
                .tint(.red)
                .task {
                    connectivity.activate()
                }
        }
    }
}
