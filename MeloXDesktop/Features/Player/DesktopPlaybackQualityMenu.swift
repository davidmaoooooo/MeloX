import SwiftUI

/// Keeps every desktop player surface on the same quality-selection behavior.
/// The menu only publishes the preference; the app shell coordinates source
/// replacement so every settings and player surface follows one code path.
struct DesktopPlaybackQualityMenu: View {
    let model: DesktopAppModel

    var body: some View {
        Menu {
            if model.player.availablePlaybackQualities.isEmpty {
                Text("正在获取可用音质")
            } else {
                Picker("播放音质", selection: qualityBinding) {
                    ForEach(model.player.availablePlaybackQualities) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
            }
        } label: {
            Label(menuTitle, systemImage: "waveform")
        }
        .disabled(model.player.currentSong == nil)
    }

    private var menuTitle: String {
        if let quality = model.player.effectivePlaybackQuality {
            return "音质：\(quality.title)"
        }
        return "音质"
    }

    private var qualityBinding: Binding<MusicQuality> {
        Binding(
            get: {
                model.player.effectivePlaybackQuality
                    ?? model.settings.quality
            },
            set: { model.player.selectPlaybackQuality($0) }
        )
    }
}
