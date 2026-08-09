import CoreGraphics

enum DesktopLyricsLayoutMetrics {
    private static let compactLineSpacingScale: CGFloat = 22.0 / 48.0
    private static let textLayoutWidthQuantum: CGFloat = 4
    private static let visualFocusAnchorQuantum: CGFloat = 2

    static func lineSpacing(
        setting: Double,
        compact: Bool
    ) -> CGFloat {
        let spacing = CGFloat(setting)
        guard compact else { return spacing }
        return max(spacing * compactLineSpacingScale, 22)
    }

    /// Keeps expensive timed-text and ruby layout cache keys stable while a
    /// window is live-resized. Four-point width steps are visually
    /// indistinguishable here and avoid rebuilding every visible lyric for
    /// every single-point resize event.
    static func textLayoutWidth(
        viewportWidth: CGFloat,
        compact: Bool
    ) -> CGFloat {
        let horizontalInset: CGFloat = compact ? 48 : 0
        let availableWidth = max(viewportWidth - horizontalInset, 1)
        let quantizedWidth = (
            availableWidth / textLayoutWidthQuantum
        ).rounded(.down) * textLayoutWidthQuantum
        return max(quantizedWidth, 1)
    }

    /// Distance blur only needs a visually stable focal point. Quantizing it
    /// prevents height-only live-resize events from invalidating every row.
    static func visualFocusAnchorY(
        viewportHeight: CGFloat,
        focusPosition: CGFloat
    ) -> CGFloat {
        let anchorY = max(viewportHeight, 0) * focusPosition
        return (
            anchorY / visualFocusAnchorQuantum
        ).rounded() * visualFocusAnchorQuantum
    }
}
