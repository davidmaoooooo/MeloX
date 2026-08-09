import SwiftUI

enum DesktopPlayerMotion {
    static let nowPlayingContentDelay: Duration = .milliseconds(300)
    static let playbackSymbolSpeed = 2.0
    static let artworkHover = Animation.spring(
        duration: 0.26,
        bounce: 0.12
    )
    static let artworkRest = Animation.smooth(duration: 0.18)
    static let progressExpand = Animation.smooth(duration: 0.13)
    static let progressCollapse = Animation.smooth(duration: 0.17)
    static let progressPress = Animation.spring(
        duration: 0.20,
        bounce: 0.12
    )
    static let volumeExpand = Animation.spring(
        duration: 0.26,
        bounce: 0.04
    )
    static let volumeCollapse = Animation.smooth(duration: 0.18)
    static let nowPlayingPresentation = Animation.spring(
        duration: 0.30,
        bounce: 0.02
    )

    static func progress(expanded: Bool) -> Animation {
        expanded ? progressExpand : progressCollapse
    }

    static func volume(expanded: Bool) -> Animation {
        expanded ? volumeExpand : volumeCollapse
    }
}
