import SwiftUI

struct NowPlayingBottomControls: View {
    static let utilityHeight: CGFloat = 62
    static let coreHeight: CGFloat = 279
    static let overlayHeight = utilityHeight + coreHeight

    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion

    let song: Song
    @Binding var page: NowPlayingPage
    let showsLyricsUtilities: Bool
    let isInterfaceHidden: Bool

    var body: some View {
        VStack(spacing: 0) {
            NowPlayingLyricsUtilityControls(
                isVisible:
                    showsLyricsUtilities
                    && !isInterfaceHidden
            )
            .frame(height: Self.utilityHeight, alignment: .top)

            coreControls
        }
        .frame(height: Self.overlayHeight)
    }

    private var coreControls: some View {
        VStack(spacing: 0) {
            interfaceLayer(.progress) {
                NowPlayingProgressControl(song: song)
            }

            Color.clear
                .frame(height: 19)

            interfaceLayer(.transport) {
                NowPlayingTransportControls()
            }

            Color.clear
                .frame(height: 31)

            interfaceLayer(.volume) {
                NowPlayingVolumeControl()
            }

            Color.clear
                .frame(height: 3)

            interfaceLayer(.pageSelector) {
                NowPlayingPageSelector(page: $page)
            }
        }
        .frame(height: Self.coreHeight)
    }

    private func interfaceLayer<Content: View>(
        _ layer: NowPlayingInterfaceTransition.ControlLayer,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .offset(
                y: isInterfaceHidden
                    ? NowPlayingInterfaceTransition.hiddenOffset(
                        for: layer
                    )
                    : 0
            )
            .opacity(isInterfaceHidden ? 0 : 1)
            .animation(
                NowPlayingInterfaceTransition.controlAnimation(
                    for: layer,
                    isVisible: !isInterfaceHidden,
                    reducesMotion: accessibilityReduceMotion
                ),
                value: isInterfaceHidden
            )
    }
}

private struct NowPlayingLyricsUtilityControls: View {
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion

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
        .offset(
            y: isVisible
                ? 0
                : NowPlayingInterfaceTransition
                    .utilityHiddenOffset
        )
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isVisible)
        .animation(
            NowPlayingInterfaceTransition.utilityAnimation(
                isVisible: isVisible,
                reducesMotion: accessibilityReduceMotion
            ),
            value: isVisible
        )
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
        .scaleEffect(
            isVisible
                ? 1
                : NowPlayingInterfaceTransition
                    .utilityHiddenScale
        )
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("功能入口已预留，暂未开放")
    }
}
