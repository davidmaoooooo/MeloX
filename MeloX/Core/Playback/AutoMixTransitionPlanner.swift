import Foundation

enum AutoMixTransitionKind: String, Sendable {
    case smart
    case fixed
    case fallback
}

struct AutoMixTransitionPlan: Equatable, Sendable {
    let kind: AutoMixTransitionKind
    let outgoingStartTime: TimeInterval
    let duration: TimeInterval
    let incomingStartTime: TimeInterval
    let incomingPlaybackRate: Double
    let fadeCurve: AutoMixFadeCurve
    let confidence: Double?
}

enum AutoMixTransitionPlanner {
    static func makePlan(
        configuration: AutoMixConfiguration,
        outgoingDuration: TimeInterval,
        incomingDuration: TimeInterval,
        analysis: AutoMixPairAnalysis?
    ) -> AutoMixTransitionPlan? {
        let outgoingDuration = max(outgoingDuration, 0)
        let incomingDuration = max(incomingDuration, 0)
        guard outgoingDuration > 1, incomingDuration > 1 else {
            return nil
        }

        if configuration.mode == .fixed {
            return fixedPlan(
                kind: .fixed,
                duration: configuration.fixedDuration,
                outgoingDuration: outgoingDuration,
                incomingDuration: incomingDuration,
                fadeCurve: configuration.fadeCurve
            )
        }

        if let analysis,
           let smartPlan = smartPlan(
               configuration: configuration,
               outgoingDuration: outgoingDuration,
               incomingDuration: incomingDuration,
               analysis: analysis
           ) {
            return smartPlan
        }

        switch configuration.fallbackBehavior {
        case .crossfade:
            return fixedPlan(
                kind: .fallback,
                duration: configuration.fixedDuration,
                outgoingDuration: outgoingDuration,
                incomingDuration: incomingDuration,
                fadeCurve: configuration.fadeCurve
            )
        case .shortCrossfade:
            return fixedPlan(
                kind: .fallback,
                duration: 3,
                outgoingDuration: outgoingDuration,
                incomingDuration: incomingDuration,
                fadeCurve: configuration.fadeCurve
            )
        case .normal:
            return nil
        }
    }

    private static func smartPlan(
        configuration: AutoMixConfiguration,
        outgoingDuration: TimeInterval,
        incomingDuration: TimeInterval,
        analysis: AutoMixPairAnalysis
    ) -> AutoMixTransitionPlan? {
        let confidence = min(
            analysis.outgoing.confidence,
            analysis.incoming.confidence
        )
        guard confidence
                >= configuration.minimumAnalysisConfidence,
              analysis.outgoing.bpm.isFinite,
              analysis.incoming.bpm.isFinite,
              analysis.outgoing.bpm > 0,
              analysis.incoming.bpm > 0,
              !analysis.outgoing.downbeats.isEmpty,
              !analysis.incoming.downbeats.isEmpty else {
            return nil
        }

        let secondsPerBeat = 60 / analysis.outgoing.bpm
        let secondsPerBar = secondsPerBeat * 4
        let desiredDuration =
            Double(configuration.transitionBars * 4)
                * secondsPerBeat
        let maximumDuration = min(
            max(outgoingDuration - 1, 1),
            max(incomingDuration - 1, 1),
            24
        )
        let transitionDuration = min(
            max(desiredDuration, 3),
            maximumDuration
        )
        guard transitionDuration >= 1 else { return nil }

        let tailCutDuration =
            Double(configuration.tailCutBars)
                * secondsPerBar
        let desiredOutgoingEnd = max(
            outgoingDuration - tailCutDuration,
            transitionDuration + 1
        )
        let desiredOutgoingStart =
            desiredOutgoingEnd - transitionDuration
        let candidateDownbeats = analysis.outgoing.downbeats
            .filter {
                $0 >= max(analysis.outgoing.regionStart, 0)
                    && $0 <= desiredOutgoingEnd - 0.75
            }
        let nearbyDownbeats = candidateDownbeats.filter {
            abs($0 - desiredOutgoingStart)
                <= max(secondsPerBar * 2, 2)
        }
        guard let outgoingStart = (
            nearbyDownbeats.isEmpty
                ? candidateDownbeats
                : nearbyDownbeats
        ).min(
            by: {
                outgoingCandidateScore(
                    $0,
                    desiredStart: desiredOutgoingStart,
                    secondsPerBar: secondsPerBar,
                    analysis: analysis.outgoing
                )
                    < outgoingCandidateScore(
                        $1,
                        desiredStart: desiredOutgoingStart,
                        secondsPerBar: secondsPerBar,
                        analysis: analysis.outgoing
                    )
            }
        ) else {
            return nil
        }
        let incomingStart = incomingCue(
            analysis.incoming,
            skipsQuietOpening: configuration.skipsQuietOpening,
            incomingDuration: incomingDuration
        )
        let effectiveDuration = min(
            desiredOutgoingEnd - outgoingStart,
            incomingDuration - incomingStart,
            transitionDuration
        )
        guard effectiveDuration >= 1 else { return nil }

        let playbackRate = tempoMatchedRate(
            outgoingBPM: analysis.outgoing.bpm,
            incomingBPM: analysis.incoming.bpm,
            configuration: configuration
        )

        return AutoMixTransitionPlan(
            kind: .smart,
            outgoingStartTime: outgoingStart,
            duration: effectiveDuration,
            incomingStartTime: incomingStart,
            incomingPlaybackRate: playbackRate,
            fadeCurve: configuration.fadeCurve,
            confidence: confidence
        )
    }

    private static func incomingCue(
        _ analysis: AutoMixTrackAnalysis,
        skipsQuietOpening: Bool,
        incomingDuration: TimeInterval
    ) -> TimeInterval {
        let candidates = analysis.downbeats.filter {
            $0 >= 0 && $0 < min(incomingDuration, 28)
        }
        guard skipsQuietOpening else {
            return candidates.first ?? 0
        }
        let energeticCue = candidates.first {
            meanEnergy(
                around: $0,
                analysis: analysis
            ) >= 0.22
        }
        guard let energeticCue,
              let energeticIndex =
                candidates.firstIndex(
                    of: energeticCue
                ) else {
            return candidates.first ?? 0
        }
        let phraseLeadIndex = max(
            energeticIndex - 2,
            0
        )
        return candidates[phraseLeadIndex]
    }

    private static func outgoingCandidateScore(
        _ candidate: TimeInterval,
        desiredStart: TimeInterval,
        secondsPerBar: TimeInterval,
        analysis: AutoMixTrackAnalysis
    ) -> Double {
        let timingDistance =
            abs(candidate - desiredStart)
                / max(secondsPerBar * 2, 1)
        let energy = Double(
            meanEnergy(
                around: candidate,
                analysis: analysis
            )
        )
        return timingDistance * 0.7 + energy * 0.3
    }

    private static func meanEnergy(
        around time: TimeInterval,
        analysis: AutoMixTrackAnalysis
    ) -> Float {
        let offsets = stride(
            from: 0.0,
            through: 0.8,
            by: 0.1
        )
        let values = offsets.map {
            analysis.energy(at: time + $0)
        }
        return values.reduce(0, +)
            / Float(max(values.count, 1))
    }

    private static func tempoMatchedRate(
        outgoingBPM: Double,
        incomingBPM: Double,
        configuration: AutoMixConfiguration
    ) -> Double {
        guard configuration.tempoMatchingEnabled else {
            return 1
        }
        let alignedIncomingBPM = [
            incomingBPM / 2,
            incomingBPM,
            incomingBPM * 2,
        ].min {
            abs($0 - outgoingBPM) < abs($1 - outgoingBPM)
        } ?? incomingBPM
        let rate = outgoingBPM / alignedIncomingBPM
        let adjustmentPercent = abs(rate - 1) * 100
        guard adjustmentPercent
                <= configuration.maximumTempoAdjustmentPercent else {
            return 1
        }
        return min(max(rate, 0.92), 1.08)
    }

    private static func fixedPlan(
        kind: AutoMixTransitionKind,
        duration requestedDuration: TimeInterval,
        outgoingDuration: TimeInterval,
        incomingDuration: TimeInterval,
        fadeCurve: AutoMixFadeCurve
    ) -> AutoMixTransitionPlan? {
        let duration = min(
            max(requestedDuration, 1),
            max(outgoingDuration - 1, 1),
            max(incomingDuration - 1, 1)
        )
        guard duration >= 1 else { return nil }
        return AutoMixTransitionPlan(
            kind: kind,
            outgoingStartTime: max(outgoingDuration - duration, 0),
            duration: duration,
            incomingStartTime: 0,
            incomingPlaybackRate: 1,
            fadeCurve: fadeCurve,
            confidence: nil
        )
    }
}
