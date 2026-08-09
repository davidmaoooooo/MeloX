import SwiftUI

enum DesktopPlayerSettingsResetter {
    @MainActor
    static func reset(model: DesktopAppModel) async {
        await Task.yield()

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            model.settings.resetPlayerSettings()
        }

        await Task.yield()
        model.player.applyVolumeControlMode()
        model.player.applySpatialAudioSettings()
        model.player.applyEqualizerSettings()
        model.player.applyAutoMixSettings()
        model.player.applySystemNowPlayingLyricsPreference()
        model.player.applyLyricsLiveActivityPreference()
        model.player.applyLyricsNotificationPreference()
    }
}
