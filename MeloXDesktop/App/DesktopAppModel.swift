import Foundation
import Observation

@MainActor
@Observable
final class DesktopAppModel {
    let settings: AppSettings
    let api: NeteaseAPI
    let library: LibraryStore
    let cloud: CloudMusicStore
    let downloads: DownloadStore
    let player: PlayerStore
    let playbackVolume: DesktopPlaybackVolumeController
    let listenTogether: ListenTogetherStore
    let lyrics: LyricsStore
    let lyricsNotifications: LyricsNotificationController
    let screenAwakeCoordinator: ScreenAwakeCoordinator
    let home: DesktopHomeStore
    let ui = DesktopUIState()

    private(set) var hasBootstrapped = false
    private(set) var launchErrorMessage: String?

    init() {
        let settings = AppSettings()
        Self.normalizeDesktopSettings(settings)
        let api = NeteaseAPI(settings: settings)
        let library = LibraryStore(api: api, settings: settings)
        let cloud = CloudMusicStore(api: api, settings: settings)
        let downloads = DownloadStore(api: api, settings: settings)
        let notifications = LyricsNotificationController(
            preferences: settings.lyricsNotifications
        )
        let player = PlayerStore(
            api: api,
            settings: settings,
            downloads: downloads,
            lyricsNotificationController: notifications,
            onPlaybackRecorded: { song in
                library.recordRecentlyPlayed(song)
            }
        )

        self.settings = settings
        self.api = api
        self.library = library
        self.cloud = cloud
        self.downloads = downloads
        self.lyricsNotifications = notifications
        self.player = player
        playbackVolume = DesktopPlaybackVolumeController(
            settings: settings,
            player: player
        )
        listenTogether = ListenTogetherStore(api: api, player: player)
        lyrics = LyricsStore(api: api)
        screenAwakeCoordinator = ScreenAwakeCoordinator()
        home = DesktopHomeStore(api: api)

        if !settings.hasCompletedOnboarding {
            ui.sheet = .onboarding
        }
    }

    func bootstrap() async {
        guard !hasBootstrapped else { return }
        hasBootstrapped = true

        await player.restore()
        async let homeLoad: Void = home.load()
        async let notificationLoad: Void = lyricsNotifications
            .refreshAuthorizationStatus()
        if library.isLoggedIn {
            async let libraryLoad: Void = library.refresh()
            async let cloudLoad: Void = cloud.refresh()
            async let roomLoad: Void = listenTogether
                .accountDidChange(hasCredentials: true)
            _ = await (libraryLoad, cloudLoad, roomLoad)
            await startHeartModeOnLaunchIfNeeded()
        }
        _ = await (homeLoad, notificationLoad)
        await synchronizeLyrics()
    }

    func synchronizeLyrics() async {
        let songID = player.currentSong?.id
        await lyrics.load(for: songID)
        player.setNowPlayingLyrics(lyrics.lyrics, for: songID)
    }

    func refreshAll() async {
        async let homeLoad: Void = home.load(force: true)
        async let libraryLoad: Void = library.refresh(force: true)
        async let cloudLoad: Void = cloud.refresh(force: true)
        _ = await (homeLoad, libraryLoad, cloudLoad)
    }

    func accountCookieDidChange() async {
        async let homeLoad: Void = home.load(force: true)
        await library.refresh(force: true)
        await cloud.refresh(force: true)
        await listenTogether.accountDidChange(
            hasCredentials: library.isLoggedIn
        )
        _ = await homeLoad
    }

    func logOut() {
        settings.clearAccount()
        library.clearAccountData()
        Task {
            async let homeLoad: Void = home.load(force: true)
            async let roomUpdate: Void = listenTogether.accountDidChange(
                hasCredentials: false
            )
            _ = await (homeLoad, roomUpdate)
        }
    }

    func clearLaunchError() {
        launchErrorMessage = nil
    }

    private func startHeartModeOnLaunchIfNeeded() async {
        guard settings.startsHeartModeOnLaunch,
              library.canStartHeartMode,
              let playlistID = library.likedPlaylistID,
              let seedSongID = library.randomHeartModeSeedSongID() else {
            return
        }

        do {
            try await player.playHeartMode(
                playlistID: playlistID,
                seedSongID: seedSongID
            )
        } catch is CancellationError {
            return
        } catch {
            launchErrorMessage = error.localizedDescription
        }
    }

    private static func normalizeDesktopSettings(_ settings: AppSettings) {
        // The desktop target currently ships the Apple Music lyric renderer.
        // Do not retain mobile-only renderer selections that the Mac cannot show.
        if settings.lyricsStyle != .appleMusic {
            settings.lyricsStyle = .appleMusic
        }

        // Desktop lyrics have no independently hidden full-screen interface.
        if settings.playerScreenAwakeMode == .hiddenLyricsInterface {
            settings.playerScreenAwakeMode = .lyrics
        }
    }
}
