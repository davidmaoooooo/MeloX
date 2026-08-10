import CoreGraphics

struct DesktopNowPlayingLayout {
    let viewport: CGSize

    private static let expandedReferenceHeight: CGFloat = 768
    private static let expandedReferenceWidth: CGFloat = 1_200
    private static let minimumViewportWidth: CGFloat = 980
    private static let minimumViewportHeight: CGFloat = 540

    private var compactHeightCompression: CGFloat {
        min(max(600 - viewport.height, 0), 50)
    }

    private var heightProgress: CGFloat {
        min(max((viewport.height - 600) / 168, 0), 1)
    }

    /// The original layout stopped growing at 768 points tall. Keep that
    /// layout as the reference size, then let genuinely large windows grow
    /// beyond it. Width participates in the calculation so a narrow, tall
    /// window still leaves useful room for the lyrics panel.
    var elementScale: CGFloat {
        min(
            max(viewport.height / Self.expandedReferenceHeight, 1),
            max(viewport.width / Self.expandedReferenceWidth, 1)
        )
    }

    /// Lyrics are a full-height visual surface, so they scale from the
    /// player's minimum supported viewport rather than from the artwork's
    /// already-expanded reference size.
    var lyricsScale: CGFloat {
        min(
            max(viewport.height / Self.minimumViewportHeight, 1),
            max(viewport.width / Self.minimumViewportWidth, 1)
        )
    }

    private var widthGrowth: CGFloat {
        max(viewport.width - 988, 0)
    }

    var chromeHeight: CGFloat { 48 }

    var contentHeight: CGFloat {
        max(viewport.height - chromeHeight, 0)
    }

    var leading: CGFloat {
        min(88 + widthGrowth * 0.15, 168)
    }

    var trailing: CGFloat {
        max(32, viewport.width * 0.045)
    }

    var panelSpacing: CGFloat {
        min(max(104 + widthGrowth * 0.15, 92), 182)
    }

    var playerWidth: CGFloat {
        (320 + heightProgress * 102) * elementScale
    }

    var artworkSize: CGFloat {
        (214 + heightProgress * 94) * elementScale
    }

    var artworkTopInset: CGFloat {
        (
            54
                - compactHeightCompression
                + heightProgress * 60
        ) * elementScale
    }

    var metadataTopInset: CGFloat {
        (74 + heightProgress * 6) * elementScale
    }
}
