import SwiftUI

struct LyricTimingTextAttribute: TextAttribute, Hashable, Sendable {
    let startTime: TimeInterval
    let endTime: TimeInterval
    let syllableStartTime: TimeInterval
    let syllableEndTime: TimeInterval
    let characterIndex: Int
    let characterCount: Int
    let wordStartTime: TimeInterval
    let wordEndTime: TimeInterval
    let wordIndex: Int
    let isWhitespace: Bool
}

/// Renders timed lyric runs in the coordinates supplied by SwiftUI.
/// Each glyph keeps its unplayed style while the played style is revealed
/// horizontally across it. Word lift moves both layers as one block, while
/// character lift preserves the original played-only movement. Word-based long
/// tones also scale every glyph around one shared word center. Glow and text
/// stay composited through all transforms.
struct LyricGlowTextRenderer: TextRenderer {
    struct Style: Equatable, Sendable {
        let glowRadius: CGFloat
        let glowOpacity: Double
        let glowsLongSyllablesOnly: Bool
        let longSyllableDetectionMode:
            LyricsLongSyllableDetectionMode
        let longSyllableDurationThreshold: TimeInterval
        let unplayedOpacity: Double
        let maximumUnplayedBlurRadius: CGFloat
        let playedRise: CGFloat
        let maximumLongSyllableScale: CGFloat
        let longSyllableExpansionPadding: CGFloat
        let liftMode: LyricsLiftMode

        fileprivate var drawsGlow: Bool {
            glowRadius > 0 && glowOpacity > 0
        }
    }

    struct LayoutConfiguration: Equatable, Sendable {
        let width: CGFloat?
        let centersLines: Bool

        fileprivate var constrainedWidth: CGFloat? {
            guard let width, width.isFinite, width > 0 else { return nil }
            return width
        }
    }

    static let glowTailDuration: TimeInterval = 0.55

    var playbackTime: TimeInterval
    let style: Style
    let layoutConfiguration: LayoutConfiguration

    var animatableData: Double {
        get { playbackTime }
        set { playbackTime = newValue }
    }

    var displayPadding: EdgeInsets {
        let padding = style.glowRadius * Metrics.displayPaddingMultiplier
        let expansionPadding = max(style.longSyllableExpansionPadding, 0)
        return EdgeInsets(
            top: padding + max(style.playedRise, 0) + expansionPadding,
            leading: padding + expansionPadding,
            bottom: padding + expansionPadding,
            trailing: padding + expansionPadding
        )
    }

    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            var lineContext = context
            if let transform = lineDrawingTransform(for: line) {
                lineContext.addFilter(
                    .projectionTransform(ProjectionTransform(transform))
                )
            }

            let expansionBoundsByWordIndex =
                wordExpansionBounds(in: line)
            for run in line {
                draw(
                    run,
                    expansionBoundsByWordIndex:
                        expansionBoundsByWordIndex,
                    in: &lineContext
                )
            }
        }
    }

    private func lineDrawingTransform(
        for line: Text.Layout.Line
    ) -> CGAffineTransform? {
        guard let width = layoutConfiguration.constrainedWidth else {
            return nil
        }

        let lineBounds = line.typographicBounds.rect
        guard lineBounds.width.isFinite,
              lineBounds.width > 0,
              lineBounds.minX.isFinite else {
            return nil
        }

        let trailingSafety = max(
            style.longSyllableExpansionPadding,
            Metrics.minimumTrailingSafety
        )
        let availableWidth = max(width - trailingSafety, 1)
        let horizontalScale = min(
            max(availableWidth / lineBounds.width, 0),
            1
        )
        let scaledWidth = lineBounds.width * horizontalScale
        let targetMinX = layoutConfiguration.centersLines
            ? (width - scaledWidth) * 0.5
            : 0
        let translationX = targetMinX
            - lineBounds.minX * horizontalScale

        guard horizontalScale < 1 || abs(translationX) > 0.001 else {
            return nil
        }
        return CGAffineTransform(
            a: horizontalScale,
            b: 0,
            c: 0,
            d: 1,
            tx: translationX,
            ty: 0
        )
    }

    private func draw(
        _ run: Text.Layout.Run,
        expansionBoundsByWordIndex: [Int: CGRect],
        in context: inout GraphicsContext
    ) {
        guard let timing = run[LyricTimingTextAttribute.self] else {
            context.draw(run)
            return
        }

        let state = visualState(for: timing)
        let wordExpansionAnchor =
            expansionBoundsByWordIndex[timing.wordIndex].map {
                CGPoint(x: $0.midX, y: $0.midY)
            }
        var runContext = context
        let liftsWholeWord = style.liftMode == .word
        if liftsWholeWord {
            applyLift(
                to: &runContext,
                progress: state.liftProgress
            )
        }
        if let wordExpansionAnchor {
            applyExpansion(
                to: &runContext,
                scale: state.expansionScale,
                anchor: wordExpansionAnchor
            )
        }

        drawUnplayed(
            run,
            blurRadius: state.unplayedBlurRadius,
            in: &runContext
        )
        guard state.revealProgress > 0 else { return }

        drawPlayed(
            run,
            revealProgress: state.revealProgress,
            liftProgress: liftsWholeWord ? 0 : state.liftProgress,
            expansionScale:
                wordExpansionAnchor == nil
                    ? state.expansionScale
                    : 1,
            rawProgress: state.rawProgress,
            glowStrength: state.glowStrength,
            in: &runContext
        )
    }

    private func visualState(
        for timing: LyricTimingTextAttribute
    ) -> RunVisualState {
        let rawProgress = playedProgress(for: timing)
        let glowStrength = style.drawsGlow
            && (!style.glowsLongSyllablesOnly || isLongSyllable(timing))
            && rawProgress > 0
            ? glowStrength(for: timing, rawProgress: rawProgress)
            : 0

        return RunVisualState(
            rawProgress: rawProgress,
            revealProgress: smootherStep(rawProgress),
            liftProgress: liftProgress(for: timing),
            expansionScale: expansionScale(for: timing),
            unplayedBlurRadius: unplayedBlurRadius(for: timing),
            glowStrength: glowStrength
        )
    }

    private func liftProgress(
        for timing: LyricTimingTextAttribute
    ) -> Double {
        let liftStartTime = style.liftMode == .word
            ? timing.wordStartTime
            : timing.startTime
        let liftEndTime = style.liftMode == .word
            ? timing.wordEndTime
            : timing.endTime
        guard playbackTime > liftStartTime else { return 0 }

        let transitionEndTime = liftEndTime
            + Metrics.liftContinuationDuration
        let transitionDuration = transitionEndTime - liftStartTime
        guard transitionDuration > 0 else { return 1 }
        return smootherStep(
            (playbackTime - liftStartTime) / transitionDuration
        )
    }

    private func expansionScale(
        for timing: LyricTimingTextAttribute
    ) -> CGFloat {
        let maximumScale = max(style.maximumLongSyllableScale, 1)
        guard maximumScale > 1,
              isLongSyllable(timing) else {
            return 1
        }

        if style.longSyllableDetectionMode == .word {
            return wordExpansionScale(
                from: timing.wordStartTime,
                to: timing.wordEndTime,
                maximumScale: maximumScale
            )
        }

        guard timing.characterCount > 0 else { return 1 }
        let characterDuration = max(
            timing.endTime - timing.startTime,
            0
        )
        let overlapDuration = min(
            characterDuration * Metrics.expansionOverlapFraction,
            Metrics.maximumExpansionOverlapDuration
        )
        let windowStart = timing.startTime
            - (timing.characterIndex > 0 ? overlapDuration : 0)
        let windowEnd = timing.endTime
            + (timing.characterIndex < timing.characterCount - 1
                ? overlapDuration
                : 0)
        return pulsingExpansionScale(
            from: windowStart,
            to: windowEnd,
            maximumScale: maximumScale
        )
    }

    private func wordExpansionScale(
        from startTime: TimeInterval,
        to endTime: TimeInterval,
        maximumScale: CGFloat
    ) -> CGFloat {
        let duration = endTime - startTime
        guard duration > 0,
              playbackTime > startTime else {
            return 1
        }

        let peakProgress = Metrics.wordExpansionPeakProgress
        let peakTime = startTime + duration * peakProgress
        let envelope: Double
        if playbackTime <= peakTime {
            envelope = cosineEaseInOut(
                (playbackTime - startTime)
                    / max(peakTime - startTime, 0.001)
            )
        } else {
            let releaseEndTime = endTime
                + Metrics.wordExpansionReleaseTailDuration
            guard playbackTime < releaseEndTime else { return 1 }
            envelope = 1 - cosineEaseInOut(
                (playbackTime - peakTime)
                    / max(releaseEndTime - peakTime, 0.001)
            )
        }
        return 1 + (maximumScale - 1)
            * CGFloat(envelope)
    }

    private func pulsingExpansionScale(
        from startTime: TimeInterval,
        to endTime: TimeInterval,
        maximumScale: CGFloat
    ) -> CGFloat {
        let duration = endTime - startTime
        guard duration > 0,
              playbackTime > startTime,
              playbackTime < endTime else {
            return 1
        }

        let rawProgress = unitProgress(
            (playbackTime - startTime) / duration
        )
        let envelope = sin(.pi * smootherStep(rawProgress))
        return 1 + (maximumScale - 1) * CGFloat(envelope)
    }

    private func wordExpansionBounds(
        in line: Text.Layout.Line
    ) -> [Int: CGRect] {
        guard style.longSyllableDetectionMode == .word else {
            return [:]
        }

        return line.reduce(into: [:]) { boundsByWordIndex, run in
            guard let timing = run[LyricTimingTextAttribute.self],
                  !timing.isWhitespace else {
                return
            }
            let bounds = run.typographicBounds.rect
            guard !bounds.isNull,
                  !bounds.isInfinite,
                  bounds.width.isFinite,
                  bounds.height.isFinite else {
                return
            }
            boundsByWordIndex[timing.wordIndex] =
                boundsByWordIndex[timing.wordIndex]?.union(bounds)
                    ?? bounds
        }
    }

    private func isLongSyllable(
        _ timing: LyricTimingTextAttribute
    ) -> Bool {
        let duration = switch style.longSyllableDetectionMode {
        case .word:
            timing.wordEndTime - timing.wordStartTime
        case .character:
            timing.endTime - timing.startTime
        }
        return duration
            >= max(style.longSyllableDurationThreshold, 0)
    }

    private func drawUnplayed(
        _ run: Text.Layout.Run,
        blurRadius: CGFloat,
        in context: inout GraphicsContext
    ) {
        var unplayedContext = context
        unplayedContext.opacity = style.unplayedOpacity
        if blurRadius > 0 {
            unplayedContext.addFilter(.blur(radius: blurRadius))
        }
        unplayedContext.draw(run)
    }

    private func drawPlayed(
        _ run: Text.Layout.Run,
        revealProgress: Double,
        liftProgress: Double,
        expansionScale: CGFloat,
        rawProgress: Double,
        glowStrength: Double,
        in context: inout GraphicsContext
    ) {
        let verticalOffset = liftOffset(at: liftProgress)
        let scale = max(expansionScale, 1)
        let bounds = run.typographicBounds.rect
        var playedContext = context
        if verticalOffset != 0 || scale != 1 {
            let transform = CGAffineTransform(
                a: scale,
                b: 0,
                c: 0,
                d: scale,
                tx: bounds.midX * (1 - scale),
                ty: bounds.midY * (1 - scale) + verticalOffset
            )
            playedContext.addFilter(
                .projectionTransform(ProjectionTransform(transform))
            )
        }

        playedContext.drawLayer { layer in
            if glowStrength > 0 {
                drawGlow(
                    for: run,
                    revealProgress: revealProgress,
                    rawProgress: rawProgress,
                    strength: glowStrength,
                    in: &layer
                )
            }

            var textContext = layer
            drawRevealed(
                run,
                progress: revealProgress,
                in: &textContext
            )
        }
    }

    private func applyLift(
        to context: inout GraphicsContext,
        progress: Double
    ) {
        let verticalOffset = liftOffset(at: progress)
        guard verticalOffset != 0 else { return }
        context.addFilter(
            .projectionTransform(
                ProjectionTransform(
                    CGAffineTransform(
                        translationX: 0,
                        y: verticalOffset
                    )
                )
            )
        )
    }

    private func applyExpansion(
        to context: inout GraphicsContext,
        scale: CGFloat,
        anchor: CGPoint
    ) {
        let scale = max(scale, 1)
        guard scale != 1 else { return }
        context.addFilter(
            .projectionTransform(
                ProjectionTransform(
                    CGAffineTransform(
                        a: scale,
                        b: 0,
                        c: 0,
                        d: scale,
                        tx: anchor.x * (1 - scale),
                        ty: anchor.y * (1 - scale)
                    )
                )
            )
        )
    }

    private func liftOffset(
        at progress: Double
    ) -> CGFloat {
        -max(style.playedRise, 0)
            * CGFloat(unitProgress(progress))
    }

    private func drawGlow(
        for run: Text.Layout.Run,
        revealProgress: Double,
        rawProgress: Double,
        strength: Double,
        in context: inout GraphicsContext
    ) {
        let pulse = 1 + Metrics.glowPulseAmount * sin(.pi * rawProgress)
        let baseOpacity = style.glowOpacity * strength

        drawGlowLayer(
            for: run,
            revealProgress: revealProgress,
            radius: style.glowRadius
                * Metrics.outerGlowRadiusMultiplier
                * CGFloat(pulse),
            opacity: min(baseOpacity * Metrics.outerGlowOpacityMultiplier, 1),
            in: &context
        )
        drawGlowLayer(
            for: run,
            revealProgress: revealProgress,
            radius: style.glowRadius
                * Metrics.innerGlowRadiusMultiplier
                * CGFloat(pulse),
            opacity: min(baseOpacity, 1),
            in: &context
        )
    }

    private func drawGlowLayer(
        for run: Text.Layout.Run,
        revealProgress: Double,
        radius: CGFloat,
        opacity: Double,
        in context: inout GraphicsContext
    ) {
        guard radius > 0, opacity > 0 else { return }

        var glowContext = context
        glowContext.opacity = opacity
        glowContext.blendMode = .plusLighter
        glowContext.addFilter(.blur(radius: radius))
        glowContext.drawLayer { layer in
            drawRevealed(
                run,
                progress: revealProgress,
                in: &layer
            )
        }
    }

    private func drawRevealed(
        _ run: Text.Layout.Run,
        progress: Double,
        in context: inout GraphicsContext
    ) {
        let progress = unitProgress(progress)
        guard progress > 0 else { return }
        guard progress < 1 else {
            context.draw(run)
            return
        }

        let bounds = run.typographicBounds.rect
        guard bounds.width > 0, bounds.height > 0 else { return }

        let featherWidth = max(
            bounds.width * Metrics.revealFeatherWidthRatio,
            Metrics.minimumRevealFeatherWidth
        )
        let travelDistance = bounds.width + featherWidth
        let gradient: Gradient
        let startPoint: CGPoint
        let endPoint: CGPoint

        if run.layoutDirection == .rightToLeft {
            let boundaryX = bounds.maxX
                - CGFloat(progress) * travelDistance
            gradient = Gradient(colors: [.clear, .white])
            startPoint = CGPoint(x: boundaryX, y: bounds.midY)
            endPoint = CGPoint(
                x: boundaryX + featherWidth,
                y: bounds.midY
            )
        } else {
            let boundaryX = bounds.minX
                + CGFloat(progress) * travelDistance
            gradient = Gradient(colors: [.white, .clear])
            startPoint = CGPoint(
                x: boundaryX - featherWidth,
                y: bounds.midY
            )
            endPoint = CGPoint(x: boundaryX, y: bounds.midY)
        }

        context.clipToLayer { maskContext in
            maskContext.fill(
                Path(bounds),
                with: .linearGradient(
                    gradient,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            )
        }
        context.draw(run)
    }

    private func unplayedBlurRadius(
        for timing: LyricTimingTextAttribute
    ) -> CGFloat {
        guard style.maximumUnplayedBlurRadius > 0,
              playbackTime < timing.startTime else {
            return 0
        }

        let leadTime = timing.startTime - playbackTime
        let distance = smootherStep(
            leadTime / Metrics.unplayedBlurLeadDuration
        )
        let blurFraction = Metrics.minimumUnplayedBlurFraction
            + (1 - Metrics.minimumUnplayedBlurFraction) * distance
        return style.maximumUnplayedBlurRadius * CGFloat(blurFraction)
    }

    private func playedProgress(
        for timing: LyricTimingTextAttribute
    ) -> Double {
        guard playbackTime >= timing.startTime else { return 0 }
        guard playbackTime < timing.endTime else { return 1 }

        let duration = timing.endTime - timing.startTime
        guard duration > 0 else { return 1 }
        return unitProgress((playbackTime - timing.startTime) / duration)
    }

    private func glowStrength(
        for timing: LyricTimingTextAttribute,
        rawProgress: Double
    ) -> Double {
        if playbackTime <= timing.endTime {
            let attack = smootherStep(
                rawProgress / Metrics.glowAttackProgress
            )
            let breath = Metrics.minimumGlowStrength
                + (1 - Metrics.minimumGlowStrength)
                    * sin(.pi * rawProgress)
            return attack * breath
        }

        let tailProgress = (playbackTime - timing.endTime)
            / Self.glowTailDuration
        guard tailProgress < 1 else { return 0 }
        return (1 - smootherStep(tailProgress)) * Metrics.minimumGlowStrength
    }

    private func smootherStep(_ value: Double) -> Double {
        let progress = unitProgress(value)
        return progress * progress * progress
            * (progress * (progress * 6 - 15) + 10)
    }

    private func cosineEaseInOut(_ value: Double) -> Double {
        let progress = unitProgress(value)
        return (1 - cos(.pi * progress)) * 0.5
    }

    private func unitProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

private extension LyricGlowTextRenderer {
    struct RunVisualState {
        let rawProgress: Double
        let revealProgress: Double
        let liftProgress: Double
        let expansionScale: CGFloat
        let unplayedBlurRadius: CGFloat
        let glowStrength: Double
    }

    enum Metrics {
        static let displayPaddingMultiplier: CGFloat = 6
        static let minimumTrailingSafety: CGFloat = 1
        static let unplayedBlurLeadDuration: TimeInterval = 2.4
        static let minimumUnplayedBlurFraction = 0.12
        static let glowAttackProgress = 0.24
        static let minimumGlowStrength = 0.82
        static let glowPulseAmount = 0.2
        static let liftContinuationDuration: TimeInterval = 0.32
        static let expansionOverlapFraction = 0.32
        static let maximumExpansionOverlapDuration: TimeInterval = 0.14
        static let wordExpansionPeakProgress = 0.62
        static let wordExpansionReleaseTailDuration: TimeInterval = 0.24
        static let outerGlowRadiusMultiplier: CGFloat = 1.75
        static let outerGlowOpacityMultiplier = 0.72
        static let innerGlowRadiusMultiplier: CGFloat = 0.62
        static let revealFeatherWidthRatio: CGFloat = 0.85
        static let minimumRevealFeatherWidth: CGFloat = 2
    }
}
