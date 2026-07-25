import SwiftUI

struct LyricMovementAnimationConfiguration: Equatable {
    let delay: TimeInterval
    let duration: TimeInterval
    let usesBounce: Bool
    let bounce: Double
    let initialVelocity: Double

    init(
        delay: TimeInterval,
        duration: TimeInterval,
        usesBounce: Bool,
        bounce: Double,
        initialVelocity: Double = 0
    ) {
        self.delay = delay
        self.duration = duration
        self.usesBounce = usesBounce
        self.bounce = bounce
        self.initialVelocity = initialVelocity
    }

    var spring: Spring {
        usesBounce
            ? Spring(duration: duration, bounce: bounce)
            : .snappy(duration: duration)
    }
}

struct LyricMovementPresentation: Equatable {
    let offset: CGFloat
    let velocity: CGFloat
}

enum LyricMovementPhase: Equatable {
    case stationary(offset: CGFloat)
    case animated(
        transitionID: UUID,
        initialOffset: CGFloat,
        destinationOffset: CGFloat,
        configuration: LyricMovementAnimationConfiguration,
        startedAt: Date
    )

    var targetOffset: CGFloat {
        switch self {
        case let .stationary(offset):
            offset
        case let .animated(_, _, destinationOffset, _, _):
            destinationOffset
        }
    }

    var isAnimated: Bool {
        if case .animated = self {
            true
        } else {
            false
        }
    }

    func continuation(
        at date: Date
    ) -> LyricMovementContinuation? {
        guard case let .animated(
            _,
            initialOffset,
            destinationOffset,
            configuration,
            startedAt
        ) = self else {
            return nil
        }

        let elapsed = max(date.timeIntervalSince(startedAt), 0)
        let presentation = Self.presentation(
            initialOffset: initialOffset,
            destinationOffset: destinationOffset,
            configuration: configuration,
            elapsed: elapsed
        )
        let remainingDistance = destinationOffset - presentation.offset
        guard abs(remainingDistance) > 0.25 else {
            return LyricMovementContinuation(
                presentation: presentation,
                targetOffset: destinationOffset,
                animation: nil
            )
        }

        let remainingDelay = max(configuration.delay - elapsed, 0)
        let normalizedVelocity = presentation.velocity / remainingDistance
        let finiteVelocity = normalizedVelocity.isFinite
            ? min(max(Double(normalizedVelocity), -12), 12)
            : 0
        var animation = Animation.interpolatingSpring(
            configuration.spring,
            initialVelocity: finiteVelocity
        )
        if remainingDelay > 0 {
            animation = animation.delay(remainingDelay)
        }
        return LyricMovementContinuation(
            presentation: presentation,
            targetOffset: destinationOffset,
            animation: animation
        )
    }

    fileprivate static func presentation(
        initialOffset: CGFloat,
        destinationOffset: CGFloat,
        configuration: LyricMovementAnimationConfiguration,
        elapsed: TimeInterval
    ) -> LyricMovementPresentation {
        guard elapsed >= configuration.delay else {
            return LyricMovementPresentation(
                offset: initialOffset,
                velocity: 0
            )
        }

        let animationElapsed = max(elapsed - configuration.delay, 0)
        let spring = configuration.spring
        let progress = spring.value(
            target: 1,
            initialVelocity: configuration.initialVelocity,
            time: animationElapsed
        )
        let progressVelocity = spring.velocity(
            target: 1,
            initialVelocity: configuration.initialVelocity,
            time: animationElapsed
        )
        let distance = destinationOffset - initialOffset
        let offset = initialOffset + distance * CGFloat(progress)
        let velocity = distance * CGFloat(progressVelocity)
        return LyricMovementPresentation(
            offset: offset.isFinite ? offset : destinationOffset,
            velocity: velocity.isFinite ? velocity : 0
        )
    }
}

struct LyricMovementContinuation {
    let presentation: LyricMovementPresentation
    let targetOffset: CGFloat
    let animation: Animation?
}

struct LyricMovementTransition: Equatable {
    let id: UUID
    let focusID: LyricLine.ID
    let initialOffsetsByID: [LyricLine.ID: CGFloat]
    let destinationOffsetsByID: [LyricLine.ID: CGFloat]
    let animationByID: [
        LyricLine.ID: LyricMovementAnimationConfiguration
    ]
    let startedAt: Date?

    init(
        id: UUID = UUID(),
        focusID: LyricLine.ID,
        initialOffsetsByID: [LyricLine.ID: CGFloat],
        destinationOffsetsByID: [LyricLine.ID: CGFloat] = [:],
        animationByID: [
            LyricLine.ID: LyricMovementAnimationConfiguration
        ] = [:],
        startedAt: Date? = nil
    ) {
        self.id = id
        self.focusID = focusID
        self.initialOffsetsByID = initialOffsetsByID
        self.destinationOffsetsByID = destinationOffsetsByID
        self.animationByID = animationByID
        self.startedAt = startedAt
    }

    func starting(
        with animationByID: [
            LyricLine.ID: LyricMovementAnimationConfiguration
        ],
        at date: Date
    ) -> Self {
        let animatedInitialOffsets = initialOffsetsByID.filter {
            animationByID[$0.key] != nil
        }
        let animatedDestinationOffsets = destinationOffsetsByID.filter {
            animationByID[$0.key] != nil
        }
        return Self(
            id: id,
            focusID: focusID,
            initialOffsetsByID: animatedInitialOffsets,
            destinationOffsetsByID: animatedDestinationOffsets,
            animationByID: animationByID,
            startedAt: date
        )
    }

    func presentationStates(
        at date: Date
    ) -> [LyricLine.ID: LyricMovementPresentation] {
        guard let startedAt else {
            return initialOffsetsByID.mapValues {
                LyricMovementPresentation(offset: $0, velocity: 0)
            }
        }
        let elapsed = max(date.timeIntervalSince(startedAt), 0)
        var animatedIDs = Set(initialOffsetsByID.keys)
        animatedIDs.formUnion(destinationOffsetsByID.keys)
        return animatedIDs.reduce(into: [:]) { states, id in
            let destinationOffset = destinationOffsetsByID[id, default: 0]
            let initialOffset = initialOffsetsByID[
                id,
                default: destinationOffset
            ]
            guard let configuration = animationByID[id] else {
                states[id] = LyricMovementPresentation(
                    offset: initialOffset,
                    velocity: 0
                )
                return
            }
            states[id] = LyricMovementPhase.presentation(
                initialOffset: initialOffset,
                destinationOffset: destinationOffset,
                configuration: configuration,
                elapsed: elapsed
            )
        }
    }

    func phase(
        for id: LyricLine.ID,
        fallbackOffset: CGFloat
    ) -> LyricMovementPhase {
        guard let startedAt,
              let configuration = animationByID[id] else {
            return .stationary(offset: fallbackOffset)
        }
        let destinationOffset = destinationOffsetsByID[id, default: 0]
        let initialOffset = initialOffsetsByID[
            id,
            default: destinationOffset
        ]
        return .animated(
            transitionID: self.id,
            initialOffset: initialOffset,
            destinationOffset: destinationOffset,
            configuration: configuration,
            startedAt: startedAt
        )
    }
}

struct LifecycleAwareLyricMovement<Content: View>: View {
    let phase: LyricMovementPhase
    @ViewBuilder let content: (CGFloat) -> Content

    @State private var animatedOffset: CGFloat

    init(
        phase: LyricMovementPhase,
        @ViewBuilder content: @escaping (CGFloat) -> Content
    ) {
        self.phase = phase
        self.content = content
        _animatedOffset = State(
            initialValue:
                phase.continuation(at: .now)?.presentation.offset
                    ?? phase.targetOffset
        )
    }

    var body: some View {
        content(phase.isAnimated ? animatedOffset : phase.targetOffset)
            .task(id: phase) {
                guard let continuation = phase.continuation(at: .now) else {
                    animatedOffset = phase.targetOffset
                    return
                }

                guard let animation = continuation.animation else {
                    animatedOffset = continuation.targetOffset
                    return
                }

                withTransaction(Transaction(animation: nil)) {
                    animatedOffset = continuation.presentation.offset
                }
                await Task.yield()
                guard !Task.isCancelled else { return }
                withAnimation(animation) {
                    animatedOffset = continuation.targetOffset
                }
            }
    }
}
