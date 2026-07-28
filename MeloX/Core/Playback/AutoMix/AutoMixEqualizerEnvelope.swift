import Foundation
import Synchronization

nonisolated struct AutoMixEqualizerAdjustment:
    Sendable
{
    let lowGain: Float
    let midGain: Float
    let highGain: Float
    let revision: UInt64

    var isFlat: Bool {
        abs(lowGain) < 0.001
            && abs(midGain) < 0.001
            && abs(highGain) < 0.001
    }
}

nonisolated final class SharedAutoMixEqualizerState:
    Sendable
{
    private let revision = Atomic<UInt64>(0)
    private let lowMid = Atomic<UInt64>(0)
    private let high = Atomic<UInt64>(0)

    @MainActor
    func update(
        lowGain: Float,
        midGain: Float,
        highGain: Float
    ) {
        revision.wrappingAdd(
            1,
            ordering: .acquiringAndReleasing
        )
        lowMid.store(
            Self.pack(lowGain, midGain),
            ordering: .relaxed
        )
        high.store(
            UInt64(highGain.bitPattern),
            ordering: .relaxed
        )
        revision.wrappingAdd(
            1,
            ordering: .releasing
        )
    }

    @MainActor
    func reset() {
        update(
            lowGain: 0,
            midGain: 0,
            highGain: 0
        )
    }

    func snapshot()
        -> AutoMixEqualizerAdjustment
    {
        while true {
            let startingRevision =
                revision.load(
                    ordering: .acquiring
                )
            guard startingRevision
                    .isMultiple(of: 2) else {
                continue
            }
            let packedLowMid =
                lowMid.load(ordering: .relaxed)
            let packedHigh =
                high.load(ordering: .relaxed)
            let endingRevision =
                revision.load(
                    ordering: .acquiring
                )
            guard startingRevision
                    == endingRevision else {
                continue
            }
            let gains =
                Self.unpack(packedLowMid)
            return AutoMixEqualizerAdjustment(
                lowGain: gains.first,
                midGain: gains.second,
                highGain:
                    Float(
                        bitPattern:
                            UInt32(
                                truncatingIfNeeded:
                                    packedHigh
                            )
                    ),
                revision: endingRevision
            )
        }
    }

    private static func pack(
        _ first: Float,
        _ second: Float
    ) -> UInt64 {
        UInt64(first.bitPattern)
            | UInt64(second.bitPattern) << 32
    }

    private static func unpack(
        _ value: UInt64
    ) -> (first: Float, second: Float) {
        (
            Float(
                bitPattern:
                    UInt32(
                        truncatingIfNeeded: value
                    )
            ),
            Float(
                bitPattern:
                    UInt32(
                        truncatingIfNeeded:
                            value >> 32
                    )
            )
        )
    }
}

nonisolated enum AutoMixEqualizerEnvelope {
    static func adjustments(
        at rawProgress: Double
    ) -> (
        outgoing: (
            low: Float,
            mid: Float,
            high: Float
        ),
        incoming: (
            low: Float,
            mid: Float,
            high: Float
        )
    ) {
        let progress =
            min(max(rawProgress, 0), 1)
        let bassSwap = smoothstep(
            (progress - 0.24) / 0.52
        )
        let outgoingExit = smoothstep(
            (progress - 0.5) / 0.5
        )
        let incomingEntry = smoothstep(
            progress / 0.48
        )

        return (
            outgoing: (
                low: Float(-12 * bassSwap),
                mid: Float(-3.5 * outgoingExit),
                high: Float(-1.5 * outgoingExit)
            ),
            incoming: (
                low:
                    Float(
                        -12
                            * (1 - bassSwap)
                    ),
                mid:
                    Float(
                        -2.5
                            * (1 - incomingEntry)
                    ),
                high:
                    Float(
                        -1
                            * (1 - incomingEntry)
                    )
            )
        )
    }

    private static func smoothstep(
        _ rawValue: Double
    ) -> Double {
        let value = min(max(rawValue, 0), 1)
        return value * value * (3 - 2 * value)
    }
}
