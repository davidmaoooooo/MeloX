import CoreGraphics

enum DesktopLyricsLayoutMetrics {
    private static let compactLineSpacingScale: CGFloat = 22.0 / 48.0

    static func lineSpacing(
        setting: Double,
        compact: Bool
    ) -> CGFloat {
        let spacing = CGFloat(setting)
        guard compact else { return spacing }
        return max(spacing * compactLineSpacingScale, 22)
    }
}
