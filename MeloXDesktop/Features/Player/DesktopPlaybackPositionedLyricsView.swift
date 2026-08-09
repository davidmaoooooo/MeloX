import SwiftUI

/// Resolves the initial playback focus inside the lyrics subtree so the outer
/// player chrome does not observe progress and rebuild open menus every tick.
struct DesktopPlaybackPositionedLyricsView: View {
    @Environment(DesktopAppModel.self) private var model

    var compact = false
    var allowsLyricBlur = true
    var foregroundColor: Color = .primary
    var isActive = true
    var isPresented = true
    var keepsPlaybackFocusSynchronized = false

    var body: some View {
        DesktopLyricsScrollView(
            compact: compact,
            allowsLyricBlur: allowsLyricBlur,
            foregroundColor: foregroundColor,
            initialFocusID: model.currentLyricsFocusID,
            isActive: isActive,
            isPresented: isPresented,
            keepsPlaybackFocusSynchronized:
                keepsPlaybackFocusSynchronized
        )
    }
}
