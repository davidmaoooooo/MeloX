import SwiftUI

struct DesktopNowPlayingToolbarContent: ToolbarContent {
    let model: DesktopAppModel

    var body: some ToolbarContent {
        if #available(macOS 26.0, *) {
            ToolbarSpacer(.flexible)

            ToolbarItem(
                id: "melox.now-playing.volume",
                placement: .automatic
            ) {
                volumeControl
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(
                id: "melox.now-playing.volume",
                placement: .primaryAction
            ) {
                volumeControl
            }
        }
    }

    private var volumeControl: some View {
        DesktopNowPlayingVolumeControl()
            .frame(width: 176, height: 36)
            .environment(model)
            .transaction { transaction in
                transaction.animation = nil
            }
    }
}
