import SwiftUI

struct NowPlayingBottomControls: View {
    static let utilityHeight: CGFloat = 62
    static let coreHeight: CGFloat = 279
    static let overlayHeight = utilityHeight + coreHeight

    let song: Song
    @Binding var page: NowPlayingPage
    let showsLyricsUtilities: Bool

    var body: some View {
        VStack(spacing: 0) {
            NowPlayingLyricsUtilityControls(
                isVisible: showsLyricsUtilities
            )
            .frame(height: Self.utilityHeight, alignment: .top)

            NowPlayingProgressControl(song: song)

            Color.clear
                .frame(height: 19)

            NowPlayingTransportControls()

            Color.clear
                .frame(height: 31)

            NowPlayingVolumeControl()

            Color.clear
                .frame(height: 3)

            NowPlayingPageSelector(page: $page)
        }
        .frame(height: Self.overlayHeight)
    }
}

private struct NowPlayingLyricsUtilityControls: View {
    let isVisible: Bool

    var body: some View {
        HStack {
            reservedButton(
                systemImage: "translate",
                accessibilityLabel: "翻译歌词"
            )

            Spacer()

            reservedButton(
                systemImage: "wand.and.sparkles",
                accessibilityLabel: "歌词长按功能"
            )
        }
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .animation(.easeInOut(duration: 0.2), value: isVisible)
    }

    private func reservedButton(
        systemImage: String,
        accessibilityLabel: String
    ) -> some View {
        Button(action: {}) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.18), in: .circle)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("功能入口已预留，暂未开放")
    }
}
