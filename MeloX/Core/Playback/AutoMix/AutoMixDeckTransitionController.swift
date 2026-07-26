@preconcurrency import AVFoundation
import Foundation

enum AutoMixPreparationError: LocalizedError {
    case itemFailed(Error?)

    var errorDescription: String? {
        switch self {
        case .itemFailed(let error):
            error?.localizedDescription ?? "下一首歌曲预载失败。"
        }
    }
}

@MainActor
final class AutoMixDeckTransitionController {
    var onTransitionBegan:
        ((Int, AutoMixTransitionPlan) -> Void)?
    var onTransitionProgress: ((Double) -> Void)?
    var onTransitionCompleted: ((Int) -> Void)?
    var onPreparationFailed: ((Int, Error) -> Void)?
    var onActiveDeckChanged: (() -> Void)?

    let decks = [
        AudioPlaybackDeck(),
        AudioPlaybackDeck(),
    ]
    private(set) var activeDeckIndex = 0

    private struct PreparedTransition {
        let identifier: Int
        let deckIndex: Int
        let item: AVPlayerItem
        let plan: AutoMixTransitionPlan
    }

    private struct ActiveTransition {
        let identifier: Int
        let outgoingDeckIndex: Int
        let incomingDeckIndex: Int
        let plan: AutoMixTransitionPlan
        let outgoingStartPosition: TimeInterval
    }

    private let itemFactory: AudioPlaybackItemFactory
    private var preparationGeneration = 0
    private var baseVolume: Float = 1
    private var deckGains: [Float] = [1, 0]
    private var preparedTransition: PreparedTransition?
    private var activeTransition: ActiveTransition?
    private var envelopeTask: Task<Void, Never>?
    private var wantsPlayback = false

    var activeDeck: AudioPlaybackDeck {
        decks[activeDeckIndex]
    }

    var hasPreparedTransition: Bool {
        preparedTransition != nil
            || activeTransition != nil
    }

    private var standbyDeckIndex: Int {
        activeDeckIndex == 0 ? 1 : 0
    }

    init(itemFactory: AudioPlaybackItemFactory) {
        self.itemFactory = itemFactory
        applyOutputVolumes()
    }

    deinit {
        envelopeTask?.cancel()
    }

    func prepare(
        _ source: PlaybackSource,
        identifier: Int,
        plan: AutoMixTransitionPlan
    ) async {
        guard plan.duration > 0 else { return }
        preparationGeneration += 1
        let generation = preparationGeneration
        clearStandbyDeck()

        let deckIndex = standbyDeckIndex
        let item = await itemFactory.makeItem(
            for: source,
            preferredForwardBufferDuration:
                max(plan.duration + 8, 12)
        )
        item.audioTimePitchAlgorithm = .spectral
        guard generation == preparationGeneration,
              !Task.isCancelled,
              activeTransition == nil else {
            return
        }

        let deck = decks[deckIndex]
        deck.replaceCurrentItem(
            with: item,
            identifier: identifier
        )
        deckGains[deckIndex] = 0
        applyOutputVolumes()
        await seek(
            deck.player,
            to: CMTime(
                seconds:
                    max(plan.incomingStartTime, 0),
                preferredTimescale: 600
            )
        )
        guard generation == preparationGeneration,
              deck.player.currentItem === item else {
            return
        }
        preparedTransition = PreparedTransition(
            identifier: identifier,
            deckIndex: deckIndex,
            item: item,
            plan: plan
        )
        switch item.status {
        case .readyToPlay
            where deck.player.status == .readyToPlay:
            deck.player.preroll(
                atRate: Float(plan.incomingPlaybackRate)
            ) { _ in }
        case .failed:
            failPreparedTransition(
                on: deckIndex,
                error: item.error
            )
        case .unknown, .readyToPlay:
            break
        @unknown default:
            failPreparedTransition(
                on: deckIndex,
                error: item.error
            )
        }
    }

    func cancel(wantsPlayback: Bool) {
        self.wantsPlayback = wantsPlayback
        preparationGeneration += 1
        envelopeTask?.cancel()
        envelopeTask = nil

        if let activeTransition {
            decks[activeTransition.incomingDeckIndex]
                .clear()
            activeDeckIndex =
                activeTransition.outgoingDeckIndex
        } else if let preparedTransition {
            decks[preparedTransition.deckIndex]
                .clear()
        } else {
            clearStandbyDeck()
        }

        preparedTransition = nil
        activeTransition = nil
        deckGains = activeDeckIndex == 0
            ? [1, 0]
            : [0, 1]
        activeDeck.player.rate =
            wantsPlayback ? 1 : 0
        applyOutputVolumes()
        onTransitionProgress?(0)
    }

    func reset() {
        cancel(wantsPlayback: false)
        for deck in decks {
            deck.clear()
        }
        activeDeckIndex = 0
        deckGains = [1, 0]
        applyOutputVolumes()
    }

    func setVolume(_ volume: Double) {
        baseVolume = Float(
            min(max(volume, 0), 1)
        )
        applyOutputVolumes()
    }

    func pauseAll() {
        wantsPlayback = false
        for deck in decks {
            deck.player.pause()
        }
    }

    func resumeIncomingIfNeeded() {
        wantsPlayback = true
        guard let activeTransition else { return }
        let progress = currentProgress(
            for: activeTransition
        )
        decks[activeTransition.incomingDeckIndex]
            .player.playImmediately(
                atRate: incomingRate(
                    for: activeTransition,
                    progress: progress
                )
            )
    }

    func handleStandbyStatus(
        _ item: AVPlayerItem,
        deckIndex: Int,
        wantsPlayback: Bool
    ) {
        guard deckIndex != activeDeckIndex else {
            return
        }
        switch item.status {
        case .readyToPlay:
            startIfNeeded(
                wantsPlayback: wantsPlayback
            )
            if let preparedTransition,
               preparedTransition.deckIndex
                == deckIndex,
               decks[deckIndex].player.status
                == .readyToPlay {
                decks[deckIndex].player.preroll(
                    atRate: Float(
                        preparedTransition.plan
                            .incomingPlaybackRate
                    )
                ) { _ in }
            }
        case .failed:
            failPreparedTransition(
                on: deckIndex,
                error: item.error
            )
        case .unknown:
            break
        @unknown default:
            failPreparedTransition(
                on: deckIndex,
                error: item.error
            )
        }
    }

    func startIfNeeded(wantsPlayback: Bool) {
        self.wantsPlayback = wantsPlayback
        guard activeTransition == nil,
              let preparedTransition,
              wantsPlayback,
              preparedTransition.item.status
                == .readyToPlay,
              decks[preparedTransition.deckIndex]
                .player.status == .readyToPlay else {
            return
        }
        let seconds =
            activeDeck.player.currentTime().seconds
        guard seconds.isFinite,
              seconds
                >= preparedTransition.plan
                    .outgoingStartTime else {
            return
        }
        start(preparedTransition)
    }

    func finishIfOutgoingEnded(
        _ item: AVPlayerItem,
        wantsPlayback: Bool
    ) -> Bool {
        self.wantsPlayback = wantsPlayback
        guard let activeTransition,
              decks[
                activeTransition.outgoingDeckIndex
              ].player.currentItem === item else {
            return false
        }
        finish(
            activeTransition,
            wantsPlayback: wantsPlayback
        )
        return true
    }

    func failPreparedIfMatching(
        _ item: AVPlayerItem,
        error: Error?
    ) -> Bool {
        guard let preparedTransition,
              decks[preparedTransition.deckIndex]
                .player.currentItem === item else {
            return false
        }
        failPreparedTransition(
            on: preparedTransition.deckIndex,
            error: error
        )
        return true
    }

    private func start(
        _ prepared: PreparedTransition
    ) {
        guard prepared.deckIndex == standbyDeckIndex,
              decks[prepared.deckIndex]
                .player.currentItem
                === prepared.item else {
            return
        }
        do {
            try activateAudioSession()
        } catch {
            failPreparedTransition(
                on: prepared.deckIndex,
                error: error
            )
            return
        }

        let outgoingPosition =
            activeDeck.player.currentTime().seconds
        let transition = ActiveTransition(
            identifier: prepared.identifier,
            outgoingDeckIndex: activeDeckIndex,
            incomingDeckIndex: prepared.deckIndex,
            plan: prepared.plan,
            outgoingStartPosition:
                outgoingPosition.isFinite
                    ? outgoingPosition
                    : prepared.plan.outgoingStartTime
        )
        preparedTransition = nil
        activeTransition = transition
        deckGains[transition.outgoingDeckIndex] = 1
        deckGains[transition.incomingDeckIndex] = 0
        applyOutputVolumes()
        decks[transition.incomingDeckIndex]
            .player.playImmediately(
                atRate: Float(
                    transition.plan.incomingPlaybackRate
                )
            )
        onTransitionBegan?(
            transition.identifier,
            transition.plan
        )
        runEnvelope(transition)
    }

    private func runEnvelope(
        _ transition: ActiveTransition
    ) {
        envelopeTask?.cancel()
        envelopeTask = Task {
            @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled,
                  let current = self.activeTransition,
                  current.identifier
                    == transition.identifier {
                let progress =
                    self.currentProgress(for: current)
                let gains = AutoMixFadeEnvelope.gains(
                    at: progress,
                    curve: current.plan.fadeCurve
                )
                self.deckGains[
                    current.outgoingDeckIndex
                ] = gains.outgoing
                self.deckGains[
                    current.incomingDeckIndex
                ] = gains.incoming
                self.applyOutputVolumes()
                let incomingPlayer =
                    self.decks[
                        current.incomingDeckIndex
                    ].player
                if self.wantsPlayback {
                    incomingPlayer.rate =
                        self.incomingRate(
                            for: current,
                            progress: progress
                        )
                } else if incomingPlayer.rate != 0 {
                    incomingPlayer.pause()
                }
                self.onTransitionProgress?(progress)
                if progress >= 1 {
                    self.finish(
                        current,
                        wantsPlayback:
                            self.wantsPlayback
                    )
                    return
                }
                try? await Task.sleep(
                    for: .milliseconds(20)
                )
            }
        }
    }

    private func currentProgress(
        for transition: ActiveTransition
    ) -> Double {
        let outgoingPosition =
            decks[transition.outgoingDeckIndex]
                .player.currentTime().seconds
        guard outgoingPosition.isFinite else { return 0 }
        return min(
            max(
                (
                    outgoingPosition
                        - transition
                            .outgoingStartPosition
                ) / max(transition.plan.duration, 0.1),
                0
            ),
            1
        )
    }

    private func incomingRate(
        for transition: ActiveTransition,
        progress: Double
    ) -> Float {
        let startRate =
            transition.plan.incomingPlaybackRate
        let smoothed =
            progress * progress * (3 - 2 * progress)
        return Float(
            startRate + (1 - startRate) * smoothed
        )
    }

    private func finish(
        _ transition: ActiveTransition,
        wantsPlayback: Bool
    ) {
        guard activeTransition?.identifier
                == transition.identifier else {
            return
        }
        envelopeTask?.cancel()
        envelopeTask = nil

        decks[transition.outgoingDeckIndex].clear()
        activeDeckIndex =
            transition.incomingDeckIndex
        activeDeck.player.rate =
            wantsPlayback ? 1 : 0
        deckGains = activeDeckIndex == 0
            ? [1, 0]
            : [0, 1]
        activeTransition = nil
        applyOutputVolumes()
        onActiveDeckChanged?()
        onTransitionProgress?(1)
        onTransitionCompleted?(
            transition.identifier
        )
    }

    private func failPreparedTransition(
        on deckIndex: Int,
        error: Error?
    ) {
        guard let preparedTransition,
              preparedTransition.deckIndex
                == deckIndex else {
            return
        }
        let identifier =
            preparedTransition.identifier
        decks[deckIndex].clear()
        self.preparedTransition = nil
        deckGains[deckIndex] = 0
        applyOutputVolumes()
        onPreparationFailed?(
            identifier,
            AutoMixPreparationError.itemFailed(error)
        )
    }

    private func clearStandbyDeck() {
        guard activeTransition == nil else { return }
        let index = standbyDeckIndex
        decks[index].clear()
        deckGains[index] = 0
        preparedTransition = nil
    }

    private func applyOutputVolumes() {
        for index in decks.indices {
            decks[index].player.volume =
                baseVolume * deckGains[index]
        }
    }

    private func seek(
        _ player: AVPlayer,
        to time: CMTime
    ) async {
        await withCheckedContinuation { continuation in
            player.seek(
                to: time,
                toleranceBefore: .zero,
                toleranceAfter: .zero
            ) { _ in
                continuation.resume()
            }
        }
    }

    private func activateAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playback,
            mode: .default
        )
        try session.setActive(true)
    }
}
