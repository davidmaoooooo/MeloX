import SwiftUI

enum NowPlayingPageTransition {
    static let animation = Animation.smooth(duration: 0.3)

    static let lyricsUtilityOffset: CGFloat = 64
    static let lyricsUtilityHiddenScale: CGFloat = 0.82

    private static let artworkDetailsOffset: CGFloat = -300
    private static let songHeaderOffset: CGFloat = 40
    private static let lyricsOffset: CGFloat = 400
    private static let outgoingAnimation =
        Animation.smooth(duration: 0.24)
    private static let incomingAnimation =
        Animation.smooth(duration: 0.22).delay(0.07)
    private static let utilityOutgoingAnimation =
        Animation.smooth(duration: 0.16)

    static func content(
        for page: NowPlayingPage,
        entersFromHiddenQueue: Bool,
        reducesMotion: Bool
    ) -> AnyTransition {
        if reducesMotion {
            return .opacity
        }

        if entersFromHiddenQueue {
            return .asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity),
                removal: .opacity
            )
        }

        switch page {
        case .artwork:
            return stagedOffsetAndOpacity(
                y: artworkDetailsOffset
            )
        case .lyrics:
            return stagedOffsetAndOpacity(y: lyricsOffset)
        case .queue:
            return .opacity
        }
    }

    static func songHeader(reducesMotion: Bool) -> AnyTransition {
        guard !reducesMotion else { return .opacity }
        return stagedOffsetAndOpacity(y: songHeaderOffset)
    }

    static func lyricsUtilityAnimation(
        isVisible: Bool,
        reducesMotion: Bool
    ) -> Animation? {
        guard !reducesMotion else { return nil }
        return isVisible
            ? incomingAnimation
            : utilityOutgoingAnimation
    }

    private static func stagedOffsetAndOpacity(
        y: CGFloat
    ) -> AnyTransition {
        .asymmetric(
            insertion:
                offsetAndOpacity(y: y)
                .animation(incomingAnimation),
            removal:
                offsetAndOpacity(y: y)
                .animation(outgoingAnimation)
        )
    }

    private static func offsetAndOpacity(
        y: CGFloat
    ) -> AnyTransition {
        .offset(y: y).combined(with: .opacity)
    }
}
