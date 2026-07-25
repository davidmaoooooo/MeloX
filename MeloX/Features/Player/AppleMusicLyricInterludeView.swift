import SwiftUI

struct AppleMusicLyricInterludeCoordinator: View {
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let interludes: [LyricInterlude]
    @Binding var activeInterludeID: LyricInterlude.ID?

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
            .onChange(of: player.progress, initial: true) {
                synchronizeImmediately()
            }
            .task(id: synchronizationTrigger) {
                await synchronizeAtTransitions()
            }
    }

    private var synchronizationTrigger:
        AppleMusicInterludeSynchronizationTrigger {
        AppleMusicInterludeSynchronizationTrigger(
            songID: player.currentSong?.id,
            seekRevision: player.seekRevision,
            isPlaying: player.isPlaying,
            isEnabled: settings.lyricsInterludeCountdownEnabled,
            advanceTime: settings.lyricsAdvanceTime,
            interludeCount: interludes.count,
            firstInterludeID: interludes.first?.id,
            lastInterludeID: interludes.last?.id
        )
    }

    private func synchronizeImmediately() {
        guard settings.lyricsInterludeCountdownEnabled else {
            updateActiveInterlude(to: nil)
            return
        }
        let position = LyricInterludeTimeline.position(
            at: player.estimatedProgress() + settings.lyricsAdvanceTime,
            in: interludes
        )
        updateActiveInterlude(to: position.activeInterludeID)
    }

    private func synchronizeAtTransitions() async {
        guard settings.lyricsInterludeCountdownEnabled else {
            updateActiveInterlude(to: nil)
            return
        }

        while !Task.isCancelled {
            let adjustedProgress = player.estimatedProgress()
                + settings.lyricsAdvanceTime
            let position = LyricInterludeTimeline.position(
                at: adjustedProgress,
                in: interludes
            )
            updateActiveInterlude(to: position.activeInterludeID)

            guard player.isPlaying,
                  let nextTransitionTime = position.nextTransitionTime else {
                return
            }

            let remainingTime = nextTransitionTime
                - (
                    player.estimatedProgress()
                        + settings.lyricsAdvanceTime
                )
            guard remainingTime > 0 else {
                await Task.yield()
                continue
            }

            do {
                try await Task.sleep(for: .seconds(remainingTime))
            } catch {
                return
            }
        }
    }

    private func updateActiveInterlude(
        to interludeID: LyricInterlude.ID?
    ) {
        guard activeInterludeID != interludeID else { return }
        activeInterludeID = interludeID
    }
}

struct AppleMusicLyricInterludeView: View {
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.effectiveLyricsRefreshRate)
    private var effectiveLyricsRefreshRate
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    let interlude: LyricInterlude
    let fontSize: CGFloat
    let onToggleInterface: (() -> Void)?

    var body: some View {
        Group {
            if accessibilityReduceMotion {
                dots(
                    presentation: presentation(
                        at: player.estimatedProgress()
                            + settings.lyricsAdvanceTime
                    )
                )
            } else {
                TimelineView(
                    .animation(
                        minimumInterval:
                            effectiveLyricsRefreshRate.minimumInterval,
                        paused: !player.isPlaying
                    )
                ) { timeline in
                    dots(
                        presentation: presentation(
                            at: player.estimatedProgress(
                                at: timeline.date
                            ) + settings.lyricsAdvanceTime
                        )
                    )
                }
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: dotDiameter,
            alignment: .leading
        )
        .contentShape(.rect)
        .onTapGesture {
            onToggleInterface?()
        }
        .accessibilityHidden(true)
    }

    private var dotDiameter: CGFloat {
        max(fontSize * 0.5, 10)
    }

    private var dotSpacing: CGFloat {
        max(fontSize * 0.35, 7)
    }

    private func dots(
        presentation: AppleMusicInterludeDotsPresentation
    ) -> some View {
        HStack(spacing: dotSpacing) {
            ForEach(presentation.dotOpacities.indices, id: \.self) {
                index in
                ZStack {
                    Circle()
                        .fill(
                            .white.opacity(
                                presentation.dotGlowOpacities[index]
                                    * 0.24
                            )
                        )
                        .frame(
                            width: dotDiameter * 2.5,
                            height: dotDiameter * 2.5
                        )
                        .blur(radius: dotDiameter * 0.8)
                        .blendMode(.plusLighter)

                    Circle()
                        .fill(
                            .white.opacity(
                                presentation.dotGlowOpacities[index]
                                    * 0.52
                            )
                        )
                        .frame(
                            width: dotDiameter * 1.65,
                            height: dotDiameter * 1.65
                        )
                        .blur(radius: dotDiameter * 0.38)
                        .blendMode(.plusLighter)

                    Circle()
                        .fill(
                            .white.opacity(
                                presentation.dotOpacities[index]
                            )
                        )
                        .frame(
                            width: dotDiameter,
                            height: dotDiameter
                        )
                }
                .frame(
                    width: dotDiameter,
                    height: dotDiameter
                )
                .scaleEffect(
                    presentation.dotScales[index]
                )
            }
        }
        .scaleEffect(
            presentation.scale,
            anchor: .leading
        )
        .opacity(presentation.opacity)
    }

    private func presentation(
        at playbackTime: TimeInterval
    ) -> AppleMusicInterludeDotsPresentation {
        AppleMusicInterludeDotsPresentation.make(
            playbackTime: playbackTime,
            interlude: interlude,
            reducesMotion: accessibilityReduceMotion
        )
    }
}

private struct AppleMusicInterludeSynchronizationTrigger: Hashable {
    let songID: Int?
    let seekRevision: Int
    let isPlaying: Bool
    let isEnabled: Bool
    let advanceTime: TimeInterval
    let interludeCount: Int
    let firstInterludeID: LyricInterlude.ID?
    let lastInterludeID: LyricInterlude.ID?
}

private struct AppleMusicInterludeDotsPresentation {
    private static let dotCount = 3
    private static let entryDelay: TimeInterval = 0.5
    private static let entryFadeDuration: TimeInterval = 0.5
    private static let entryScaleDuration: TimeInterval = 2
    private static let exitScaleDuration: TimeInterval = 0.75
    private static let exitFadeDuration: TimeInterval = 0.375
    private static let targetBreatheDuration: TimeInterval = 1.5
    private static let baseScale = 0.7

    let dotOpacities: [Double]
    let dotScales: [CGFloat]
    let dotGlowOpacities: [Double]
    let scale: CGFloat
    let opacity: Double

    static func make(
        playbackTime: TimeInterval,
        interlude: LyricInterlude,
        reducesMotion: Bool
    ) -> AppleMusicInterludeDotsPresentation {
        let duration = max(
            interlude.countdownEndTime - interlude.startTime,
            0.001
        )
        let elapsed = clamped(
            playbackTime - interlude.startTime,
            minimum: 0,
            maximum: duration
        )
        let remaining = interlude.countdownEndTime - playbackTime
        guard playbackTime < interlude.countdownEndTime else {
            return AppleMusicInterludeDotsPresentation(
                dotOpacities: Array(repeating: 0, count: dotCount),
                dotScales: Array(repeating: 1, count: dotCount),
                dotGlowOpacities: Array(
                    repeating: 0,
                    count: dotCount
                ),
                scale: 0,
                opacity: 0
            )
        }

        let dotsDuration = max(duration - exitScaleDuration, 0.001)
        let dotOpacities = (0..<dotCount).map { index in
            let segmentOffset =
                dotsDuration * Double(index) / Double(dotCount)
            let progress =
                (
                    (elapsed - segmentOffset)
                        * Double(dotCount)
                        / dotsDuration
                ) * 0.75
            return clamped(
                progress,
                minimum: 0.25,
                maximum: 1
            )
        }
        let thirdDotProgress = smoothStep(
            clamped(
                (dotOpacities[dotCount - 1] - 0.25) / 0.75,
                minimum: 0,
                maximum: 1
            )
        )
        let dotScales = (0..<dotCount).map { index in
            guard index == dotCount - 1, !reducesMotion else {
                return CGFloat(1)
            }
            return CGFloat(1 + thirdDotProgress * 0.26)
        }
        let dotGlowOpacities = (0..<dotCount).map { index in
            index == dotCount - 1
                ? thirdDotProgress
                : 0
        }

        var globalOpacity: Double
        switch elapsed {
        case ..<entryDelay:
            globalOpacity = 0
        case ..<(entryDelay + entryFadeDuration):
            globalOpacity =
                (elapsed - entryDelay) / entryFadeDuration
        default:
            globalOpacity = 1
        }
        if remaining < exitFadeDuration {
            globalOpacity *= clamped(
                remaining / exitFadeDuration,
                minimum: 0,
                maximum: 1
            )
        }

        let scale: Double
        if reducesMotion {
            scale = baseScale
        } else {
            let breatheCount = max(
                ceil(duration / targetBreatheDuration),
                1
            )
            let breatheDuration = duration / breatheCount
            var animatedScale =
                sin(
                    1.5 * .pi
                        - (elapsed / breatheDuration) * 2
                ) / 20 + 1

            if elapsed < entryScaleDuration {
                animatedScale *= easeOutExpo(
                    elapsed / entryScaleDuration
                )
            }
            if remaining < exitScaleDuration {
                let exitProgress =
                    (exitScaleDuration - remaining)
                        / exitScaleDuration
                        / 2
                animatedScale *= 1 - easeInOutBack(
                    clamped(
                        exitProgress,
                        minimum: 0,
                        maximum: 0.5
                    )
                )
            }
            scale = max(animatedScale, 0) * baseScale
        }

        return AppleMusicInterludeDotsPresentation(
            dotOpacities: dotOpacities,
            dotScales: dotScales,
            dotGlowOpacities: dotGlowOpacities,
            scale: CGFloat(scale),
            opacity: clamped(
                globalOpacity,
                minimum: 0,
                maximum: 1
            )
        )
    }

    private static func smoothStep(_ value: Double) -> Double {
        value * value * (3 - 2 * value)
    }

    private static func easeOutExpo(_ value: Double) -> Double {
        value >= 1 ? 1 : 1 - pow(2, -10 * value)
    }

    private static func easeInOutBack(_ value: Double) -> Double {
        let firstCoefficient = 1.70158
        let secondCoefficient = firstCoefficient * 1.525
        if value < 0.5 {
            return (
                pow(2 * value, 2)
                    * (
                        (secondCoefficient + 1) * 2 * value
                            - secondCoefficient
                    )
            ) / 2
        }
        return (
            pow(2 * value - 2, 2)
                * (
                    (secondCoefficient + 1) * (value * 2 - 2)
                        + secondCoefficient
                )
                + 2
        ) / 2
    }

    private static func clamped(
        _ value: Double,
        minimum: Double,
        maximum: Double
    ) -> Double {
        min(max(value, minimum), maximum)
    }
}
