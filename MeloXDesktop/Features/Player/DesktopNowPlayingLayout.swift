import CoreGraphics

struct DesktopNowPlayingLayout {
    let viewport: CGSize

    private var compactHeightCompression: CGFloat {
        min(max(600 - viewport.height, 0), 50)
    }

    private var heightProgress: CGFloat {
        min(max((viewport.height - 600) / 168, 0), 1)
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
        320 + heightProgress * 102
    }

    var artworkSize: CGFloat {
        214 + heightProgress * 94
    }

    var artworkTopInset: CGFloat {
        54
            - compactHeightCompression
            + heightProgress * 60
    }

    var metadataTopInset: CGFloat {
        74 + heightProgress * 6
    }
}
