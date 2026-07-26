import SwiftUI

enum LyricLineFitting {
    static func validWidth(_ width: CGFloat?) -> CGFloat? {
        guard let width, width.isFinite, width > 0 else {
            return nil
        }
        return width
    }

    static func drawingTransform(
        for line: Text.Layout.Line,
        constrainedWidth: CGFloat?,
        centersLine: Bool,
        trailingSafety: CGFloat
    ) -> CGAffineTransform? {
        guard let width = validWidth(constrainedWidth) else {
            return nil
        }

        let bounds = line.typographicBounds.rect
        guard bounds.width.isFinite,
              bounds.width > 0,
              bounds.minX.isFinite,
              bounds.midY.isFinite else {
            return nil
        }

        let availableWidth = max(
            width - max(trailingSafety, 0),
            1
        )
        let scale = min(
            max(availableWidth / bounds.width, 0),
            1
        )
        let scaledWidth = bounds.width * scale
        let targetMinX = centersLine
            ? (width - scaledWidth) * 0.5
            : 0
        let translationX = targetMinX - bounds.minX * scale
        let translationY = bounds.midY * (1 - scale)

        guard scale < 1
                || abs(translationX) > 0.001
                || abs(translationY) > 0.001 else {
            return nil
        }
        return CGAffineTransform(
            a: scale,
            b: 0,
            c: 0,
            d: scale,
            tx: translationX,
            ty: translationY
        )
    }
}
