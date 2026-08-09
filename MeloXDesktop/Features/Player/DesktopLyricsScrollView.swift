import SwiftUI

struct DesktopLyricsScrollView: View {
    private enum PresentationPhase: String {
        case unmanaged
        case hidden
        case opening
        case active
    }

    private struct ScrollRequest: Equatable {
        let id: String
        let generation: UInt
        let animationDuration: TimeInterval?
    }

    private static let focusColorTransitionDuration: TimeInterval = 0.12
    private static let viewportAlignmentDelay: Duration = .milliseconds(120)
    private static let annotationSpacing =
        LyricAnnotationMetrics.verticalSpacing

    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var scrollRequest: ScrollRequest?
    @State private var isInitialFocusPrepared = false
    @State private var isViewportChanging = false
    @State private var isBrowsingLyrics = false
    @State private var browsingGeneration = 0
    @State private var initialFocusPreparationRevision = 0
    @State private var positionedLyricID: LyricLine.ID?
    @State private var positionedInterludeID: LyricInterlude.ID?
    @State private var playbackFocus: AppleMusicLyricsPlaybackFocus?
    @State private var timelineHighlightedLyricID: LyricLine.ID?
    @State private var visualHighlightedLyricID: LyricLine.ID?
    @State private var lyricFocusColorTransition:
        LyricFocusColorTransition?
    @State private var visualCascadeFocusLyricID: LyricLine.ID?
    @State private var geometryCache = DesktopLyricsGeometryCache()
    @State private var lyricMovementOffsetByID: [LyricLine.ID: CGFloat] = [:]
    @State private var lyricMovementTransition: LyricMovementTransition?
    var compact = false
    var allowsLyricBlur = true
    var foregroundColor: Color = .primary
    var isActive = true
    var isPresented = true
    var keepsPlaybackFocusSynchronized = false

    init(
        compact: Bool = false,
        allowsLyricBlur: Bool = true,
        foregroundColor: Color = .primary,
        initialFocusID: LyricLine.ID? = nil,
        isActive: Bool = true,
        isPresented: Bool = true,
        keepsPlaybackFocusSynchronized: Bool = false
    ) {
        self.compact = compact
        self.allowsLyricBlur = allowsLyricBlur
        self.foregroundColor = foregroundColor
        self.isActive = isActive
        self.isPresented = isPresented
        self.keepsPlaybackFocusSynchronized =
            keepsPlaybackFocusSynchronized

        _scrollRequest = State(
            initialValue: initialFocusID.map {
                ScrollRequest(
                    id: $0,
                    generation: 0,
                    animationDuration: nil
                )
            }
        )
        // Keep the visual focus and the first one-way scroll request in sync.
        // This prevents the coordinator's initial update from producing a
        // visible first-row -> current-row double scroll.
        _positionedLyricID = State(initialValue: nil)
        _playbackFocus = State(
            initialValue: initialFocusID.map {
                AppleMusicLyricsPlaybackFocus.lyric($0)
            }
        )
        _timelineHighlightedLyricID = State(initialValue: initialFocusID)
        _visualHighlightedLyricID = State(initialValue: initialFocusID)
        _visualCascadeFocusLyricID = State(initialValue: initialFocusID)
    }

    private var hasSyllableSyncedLyrics: Bool {
        model.lyrics.lyrics.contains(where: \.isSyllableSynced)
    }

    private var horizontalVisualOverflow: CGFloat {
        let usesTimedLyrics =
            (model.settings.lyricsWordByWord && hasSyllableSyncedLyrics)
            || (
                model.settings.lyricsPseudoWordByWord
                    && !hasSyllableSyncedLyrics
            )
        let glowOverflow = Self.lyricGlowOverflow(
            isEnabled: model.settings.lyricsGlowEnabled && usesTimedLyrics,
            fontSize: model.settings.lyricsFontSize,
            intensity: model.settings.lyricsGlowIntensity
        )
        return max(
            glowOverflow,
            SynchronizedLyricText.interactionBackgroundVisualOverflow
        )
    }

    private var effectiveLyricsAdvanceTime: TimeInterval {
        model.settings.effectiveLyricsAdvanceTime(
            hasSyllableSyncedLyrics: hasSyllableSyncedLyrics
        )
    }

    private var interludes: [LyricInterlude] {
        LyricInterludeTimeline.interludes(in: model.lyrics.lyrics)
    }

    private var activeInterlude: LyricInterlude? {
        guard model.settings.lyricsInterludeCountdownEnabled,
              let id = playbackFocus?.interludeID else { return nil }
        return interludes.first { $0.id == id }
    }

    private var layoutInterlude: LyricInterlude? {
        activeInterlude
            ?? positionedInterludeID.flatMap { positionedID in
                interludes.first { $0.id == positionedID }
            }
    }

    private var highlightedID: LyricLine.ID? {
        if let playbackFocus {
            return playbackFocus.lyricID
        }
        return timelineHighlightedLyricID
    }

    private var requestedFocusID: String? {
        if let playbackFocus {
            return playbackFocus.interludeID ?? playbackFocus.lyricID
        }
        return highlightedID
    }

    private var visualFocusID: LyricLine.ID? {
        visualCascadeFocusLyricID
            ?? visualHighlightedLyricID
            ?? highlightedID
    }

    private var blurFocusID: LyricLine.ID? {
        visualCascadeFocusLyricID
            ?? timelineHighlightedLyricID
    }

    private var focusAnchor: UnitPoint {
        UnitPoint(x: 0.5, y: focusPosition)
    }

    private var requestedScrollID: LyricLine.ID? {
        scrollRequest?.id
    }

    private var focusPosition: CGFloat {
        min(
            max(
                CGFloat(model.settings.lyricsFocusPosition),
                CGFloat(AppSettings.lyricsFocusPositionRange.lowerBound)
            ),
            CGFloat(AppSettings.lyricsFocusPositionRange.upperBound)
        )
    }

    private var focusRequestID: String {
        "\(model.lyrics.songID.map { String($0) } ?? "none")-"
            + "\(model.lyrics.lyrics.count)-"
            + "\(requestedFocusID ?? "none")-"
            + "\(presentationFocusRequestID)-"
            + "\(isBrowsingLyrics)-"
            + "\(initialFocusPreparationRevision)"
    }

    private var presentationFocusRequestID: String {
        presentationPhase.rawValue
    }

    private var presentationPhase: PresentationPhase {
        guard keepsPlaybackFocusSynchronized else { return .unmanaged }
        guard isPresented else { return .hidden }
        return isActive ? .active : .opening
    }

    private var acceptsGeometryUpdates: Bool {
        !keepsPlaybackFocusSynchronized || isPresented
    }

    private var coordinatesPlaybackFocus: Bool {
        acceptsGeometryUpdates
            && (
                isActive
                    || (keepsPlaybackFocusSynchronized && isPresented)
            )
    }

    var body: some View {
        GeometryReader { geometry in
            Group {
                if model.lyrics.isLoading {
                    Text("正在载入歌词…")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(foregroundColor.opacity(0.58))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.lyrics.lyrics.isEmpty {
                    ContentUnavailableView(
                        "暂无歌词",
                        systemImage: "quote.bubble",
                        description: Text(
                            model.lyrics.errorMessage
                                ?? "当前歌曲没有可用歌词。"
                        )
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    lyricsScrollView(viewportSize: geometry.size)
                }
            }
            .onChange(of: geometry.size, initial: true) { _, size in
                let sizeChanged = geometryCache.recordViewportSize(size)
                guard acceptsGeometryUpdates, sizeChanged else { return }
                scheduleViewportAlignment(for: size.height)
            }
        }
        .onChange(of: model.lyrics.songID) { _, _ in
            resetLyricsSession()
        }
        .onChange(of: acceptsGeometryUpdates) { _, acceptsUpdates in
            guard !acceptsUpdates else { return }
            geometryCache.cancelPendingLayoutSynchronization()
            geometryCache.cancelPendingViewportSettlement()
            endViewportChange()
        }
        .onChange(of: focusPosition) { _, _ in
            guard acceptsGeometryUpdates,
                  model.settings.lyricsAutoFollow,
                  !isBrowsingLyrics,
                  let focusID = requestedFocusID
                    ?? positionedLyricID
                    ?? visualCascadeFocusLyricID else { return }
            requestScroll(to: focusID)
        }
        .onDisappear {
            browsingGeneration &+= 1
            isBrowsingLyrics = false
            geometryCache.cancelPendingLayoutSynchronization()
            geometryCache.cancelPendingViewportSettlement()
        }
        .background {
            AppleMusicLyricsFocusCoordinator(
                lyrics: model.lyrics.lyrics,
                interludes: interludes,
                isActive: coordinatesPlaybackFocus,
                playbackFocus: $playbackFocus,
                timelineHighlightedLyricID: $timelineHighlightedLyricID
            )
            .environment(model.player)
            .environment(model.settings)
        }
        .environment(
            \.effectiveLyricsRefreshRate,
            model.settings.lyricsRefreshRate
        )
        .environment(
            \.lyricsRenderingIsActive,
            isActive && acceptsGeometryUpdates && !isViewportChanging
        )
    }

    private func resetLyricsSession() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            scrollRequest = nil
            isInitialFocusPrepared = false
            isViewportChanging = false
            isBrowsingLyrics = false
            browsingGeneration &+= 1
            initialFocusPreparationRevision = 0
            positionedLyricID = nil
            positionedInterludeID = nil
            playbackFocus = nil
            timelineHighlightedLyricID = nil
            visualHighlightedLyricID = nil
            lyricFocusColorTransition = nil
            visualCascadeFocusLyricID = nil
            lyricMovementOffsetByID.removeAll()
            lyricMovementTransition = nil
        }
        geometryCache.removeAllMeasurements()
    }

    private func scheduleViewportAlignment(for viewportHeight: CGFloat) {
        guard isInitialFocusPrepared else { return }
        settleMovementForViewportChange()
        if !isViewportChanging {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                isViewportChanging = true
            }
        }
        geometryCache.scheduleViewportSettlement(
            after: Self.viewportAlignmentDelay
        ) {
            finishViewportChange(viewportHeight: viewportHeight)
        }
    }

    private func endViewportChange() {
        guard isViewportChanging else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isViewportChanging = false
        }
    }

    private func settleMovementForViewportChange() {
        guard isInitialFocusPrepared,
              let transition = lyricMovementTransition else { return }

        let focusID = transition.focusID
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visualCascadeFocusLyricID = focusID
            lyricMovementOffsetByID = focusedLineFollowingOffsets(
                for: focusID
            )
            lyricMovementTransition = nil
            positionedLyricID = focusID
        }
        updateVisualColorFocus(to: focusID)
    }

    private func currentViewportHeight(fallback: CGFloat) -> CGFloat {
        let measuredHeight = geometryCache.viewportSize.height
        guard measuredHeight.isFinite, measuredHeight > 0 else {
            return fallback
        }
        return measuredHeight
    }

    private func requestScroll(
        to id: String,
        animationDuration: TimeInterval? = nil
    ) {
        scrollRequest = ScrollRequest(
            id: id,
            generation: (scrollRequest?.generation ?? 0) &+ 1,
            animationDuration: animationDuration
        )
    }

    private func performScroll(
        _ request: ScrollRequest,
        with proxy: ScrollViewProxy
    ) {
        if let duration = request.animationDuration {
            withAnimation(.smooth(duration: duration)) {
                proxy.scrollTo(request.id, anchor: focusAnchor)
            }
            return
        }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            proxy.scrollTo(request.id, anchor: focusAnchor)
        }
    }

    private func lyricsScrollView(viewportSize: CGSize) -> some View {
        surfacedScrollView(viewportSize: viewportSize)
            .opacity(isInitialFocusPrepared ? 1 : 0)
            .task(id: focusRequestID) {
                let preparesInitialFocus = !isInitialFocusPrepared
                if let activeInterlude {
                    if preparesInitialFocus {
                        prepareInitialFocus(at: activeInterlude)
                        await finishInitialFocusPreparation(
                            at: activeInterlude.id,
                            waitsForLyricGeometry: false,
                            viewportHeight: viewportSize.height
                        )
                        return
                    }
                    if await prepareFocusForPresentationIfNeeded() {
                        return
                    }
                    await movePlaybackFocus(to: activeInterlude)
                    return
                }
                guard let highlightedID else {
                    resetPlaybackFocus()
                    if preparesInitialFocus {
                        // Give the coordinator one layout turn to publish the
                        // current playback line before falling back to row one.
                        await Task.yield()
                        do {
                            try await Task.sleep(for: .milliseconds(16))
                        } catch {
                            return
                        }
                        guard !Task.isCancelled,
                              self.highlightedID == nil else { return }
                        await finishInitialFocusPreparation(
                            at: model.lyrics.lyrics.first?.id,
                            waitsForLyricGeometry: false,
                            viewportHeight: viewportSize.height
                        )
                    }
                    return
                }
                let handsOffFromInterlude = isInterludeHandoff(
                    to: highlightedID
                )
                if preparesInitialFocus {
                    prepareInitialFocus(at: highlightedID)
                    await finishInitialFocusPreparation(
                        at: highlightedID,
                        waitsForLyricGeometry: true,
                        viewportHeight: viewportSize.height
                    )
                    return
                }
                if await prepareFocusForPresentationIfNeeded() {
                    return
                }
                if isActive,
                   !handsOffFromInterlude {
                    await Task.yield()
                    try? await Task.sleep(for: .milliseconds(60))
                }
                guard !Task.isCancelled,
                      self.highlightedID == highlightedID else { return }
                await movePlaybackFocus(
                    to: highlightedID,
                    viewportHeight: viewportSize.height
                )
            }
            .task(id: lyricFocusColorTransition?.id) {
                guard let lyricFocusColorTransition else { return }
                await finishFocusColorTransition(
                    lyricFocusColorTransition
                )
            }
    }

    private func finishViewportChange(
        viewportHeight: CGFloat
    ) {
        guard isViewportChanging, acceptsGeometryUpdates else {
            endViewportChange()
            return
        }
        synchronizeStationaryFollowingOffsets()
        if isActive,
           model.settings.lyricsAutoFollow,
           !isBrowsingLyrics {
            realignPlaybackFocusAfterViewportChange(
                viewportHeight: viewportHeight
            )
        }
        endViewportChange()
    }

    private func realignPlaybackFocusAfterViewportChange(
        viewportHeight proposedViewportHeight: CGFloat
    ) {
        guard let focusID = requestedFocusID
                ?? positionedLyricID
                ?? visualCascadeFocusLyricID else { return }

        let isLyricFocus = playbackFocus?.interludeID == nil
        let viewportHeight = currentViewportHeight(
            fallback: proposedViewportHeight
        )
        let viewportAnchorY = viewportHeight * focusPosition
        if isLyricFocus,
           isFocusAligned(
               id: focusID,
               viewportAnchorY: viewportAnchorY
           ) {
            return
        }
        requestScroll(to: focusID)
    }

    private func finishInitialFocusPreparation(
        at id: LyricLine.ID?,
        waitsForLyricGeometry: Bool,
        viewportHeight: CGFloat
    ) async {
        await Task.yield()
        guard !Task.isCancelled else { return }

        if waitsForLyricGeometry, let id {
            _ = await waitForLyricFrame(id: id)
            guard !Task.isCancelled else { return }
            let isPrepared = await ensureFocusAlignment(
                to: id,
                viewportHeight: viewportHeight,
                animated: false,
                forcesScrollTargetReapplication: true
            )
            guard isPrepared else {
                await retryInitialFocusPreparation()
                return
            }
        } else if let id {
            guard await reapplyScrollTarget(id) else {
                await retryInitialFocusPreparation()
                return
            }
        } else {
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return
            }
        }
        guard !Task.isCancelled else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isInitialFocusPrepared = true
        }
    }

    private func retryInitialFocusPreparation() async {
        do {
            try await Task.sleep(for: .milliseconds(16))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }
        initialFocusPreparationRevision &+= 1
    }

    private func prepareFocusForPresentationIfNeeded() async -> Bool {
        switch presentationPhase {
        case .unmanaged, .active:
            return false

        case .opening:
            settlePresentationTransitions()
            return true

        case .hidden:
            return true
        }
    }

    private func settlePresentationTransitions() {
        let settledFocusID = lyricMovementTransition?.focusID
            ?? positionedLyricID
            ?? visualCascadeFocusLyricID
        let settledOffsets = focusedLineFollowingOffsets(
            for: settledFocusID
        )
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricFocusColorTransition = nil
            lyricMovementTransition = nil
            if positionedInterludeID != nil, settledFocusID == nil {
                visualCascadeFocusLyricID = nil
                lyricMovementOffsetByID.removeAll()
            } else {
                visualCascadeFocusLyricID = settledFocusID
                lyricMovementOffsetByID = settledOffsets
            }
        }
    }

    private func reapplyScrollTarget(_ id: String) async -> Bool {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            requestScroll(to: id)
        }
        await Task.yield()
        guard !Task.isCancelled else { return false }
        do {
            try await Task.sleep(for: .milliseconds(16))
        } catch {
            return false
        }
        return !Task.isCancelled
    }

    private func prepareInitialFocus(at id: LyricLine.ID) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            requestScroll(to: id)
            positionedLyricID = id
            positionedInterludeID = nil
            visualHighlightedLyricID = id
            lyricFocusColorTransition = nil
            visualCascadeFocusLyricID = id
            lyricMovementOffsetByID = focusedLineFollowingOffsets(for: id)
            lyricMovementTransition = nil
        }
    }

    private func prepareInitialFocus(at interlude: LyricInterlude) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            requestScroll(to: interlude.id)
            positionedLyricID = interlude.precedingLyricID
            positionedInterludeID = interlude.id
            visualHighlightedLyricID = nil
            lyricFocusColorTransition = nil
            visualCascadeFocusLyricID = nil
            lyricMovementOffsetByID.removeAll()
            lyricMovementTransition = nil
        }
    }

    private func waitForLyricFrame(id: LyricLine.ID) async -> Bool {
        for attempt in 0..<30 {
            if geometryCache.frameByID[id] != nil {
                return true
            }
            guard !Task.isCancelled, attempt < 29 else { return false }
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return false
            }
        }
        return false
    }

    private func movePlaybackFocus(
        to interlude: LyricInterlude
    ) async {
        guard !isBrowsingLyrics else {
            settlePlaybackFocusDuringBrowsing(at: interlude)
            return
        }
        guard positionedInterludeID != interlude.id
                || requestedScrollID != interlude.id else { return }

        let animationDuration: TimeInterval? = if reduceMotion
                || !isActive
                || isViewportChanging
                || requestedScrollID == nil {
            nil
        } else {
            0.5
        }
        lyricMovementTransition = nil
        lyricMovementOffsetByID.removeAll()
        updateVisualColorFocus(to: nil)
        let animation = animationDuration.map {
            Animation.smooth(duration: $0)
        }
        withAnimation(animation) {
            visualCascadeFocusLyricID = nil
        }
        requestScroll(
            to: interlude.id,
            animationDuration: animationDuration
        )
        positionedLyricID = interlude.precedingLyricID
        positionedInterludeID = interlude.id
        await Task.yield()
    }

    private func movePlaybackFocus(
        to highlightedID: LyricLine.ID,
        viewportHeight proposedViewportHeight: CGFloat
    ) async {
        let viewportHeight = currentViewportHeight(
            fallback: proposedViewportHeight
        )
        let handsOffFromInterlude = isInterludeHandoff(
            to: highlightedID
        )
        guard !isBrowsingLyrics else {
            settlePlaybackFocusDuringBrowsing(at: highlightedID)
            return
        }
        guard positionedLyricID != highlightedID else {
            let viewportAnchorY = viewportHeight * focusPosition
            guard handsOffFromInterlude
                    || !isFocusAligned(
                        id: highlightedID,
                        viewportAnchorY: viewportAnchorY
                    ) else {
                return
            }
            await moveFocusWithoutCascade(
                to: highlightedID,
                viewportHeight: viewportHeight
            )
            return
        }

        let movementOriginLyricID: LyricLine.ID
        if let positionedLyricID {
            movementOriginLyricID = positionedLyricID
        } else if handsOffFromInterlude {
            // A prelude has no preceding lyric, but it is still an ordinary
            // interlude-to-lyric promotion rather than initial preparation.
            movementOriginLyricID = highlightedID
        } else {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                requestScroll(to: highlightedID)
                visualHighlightedLyricID = highlightedID
                lyricFocusColorTransition = nil
                visualCascadeFocusLyricID = highlightedID
                lyricMovementOffsetByID = focusedLineFollowingOffsets(
                    for: highlightedID
                )
                lyricMovementTransition = nil
            }
            await Task.yield()
            self.positionedLyricID = highlightedID
            return
        }

        guard model.settings.lyricsAutoFollow else {
            updateVisualFocus(to: highlightedID)
            synchronizeStationaryFollowingOffsets()
            self.positionedLyricID = highlightedID
            return
        }

        guard isActive,
              !isViewportChanging,
              !reduceMotion,
              handsOffFromInterlude
                || isForwardAdjacentTransition(
                    from: movementOriginLyricID,
                    to: highlightedID
                ),
              let highlightedIndex = model.lyrics.lyrics.firstIndex(
                where: { $0.id == highlightedID }
              ),
              let nextFocusFrame = geometryCache.frameByID[highlightedID] else {
            await moveFocusWithoutCascade(
                to: highlightedID,
                viewportHeight: viewportHeight
            )
            return
        }

        let focusAnchorY = viewportHeight * focusPosition
        let nextFocusAnchorY = nextFocusFrame.minY
            + nextFocusFrame.height * focusPosition
        let movementDistance = nextFocusAnchorY - focusAnchorY
        guard movementDistance.isFinite,
              abs(movementDistance) > 0.5 else {
            await moveFocusWithoutCascade(
                to: highlightedID,
                viewportHeight: viewportHeight
            )
            return
        }

        let firstChasingIndex = max(
            highlightedIndex - 1,
            model.lyrics.lyrics.startIndex
        )
        let maximumChaseOrder = min(
            max(
                model.lyrics.lyrics.index(before: model.lyrics.lyrics.endIndex)
                    - firstChasingIndex,
                0
            ),
            12
        )
        let baseDuration = LyricPlaybackTimeline.focusAnimationDuration(
            for: highlightedID,
            in: model.lyrics.lyrics
        )
        let cascadeDuration = LyricPlaybackTimeline.focusCascadeAnimationDuration(
            baseDuration: baseDuration,
            preferredDuration: model.settings.lyricsFocusCascadeDuration
        )
        let playbackTime = model.player.estimatedProgress()
            + effectiveLyricsAdvanceTime
        let remainingDuration = LyricPlaybackTimeline.remainingFocusDuration(
            for: highlightedID,
            at: playbackTime,
            in: model.lyrics.lyrics
        )
        let focusColorLeadTime = min(
            max(
                model.settings.lyricsFocusColorLeadTime,
                AppSettings.lyricsFocusColorLeadTimeRange.lowerBound
            ),
            AppSettings.lyricsFocusColorLeadTimeRange.upperBound
        )
        guard let cascadeTiming = LyricPlaybackTimeline.focusCascadeTiming(
            maximumLineOrder: maximumChaseOrder,
            preferredDelayPerLine: model.settings.lyricsFocusCascadeDelay,
            preferredDelayIncreasePerLine:
                model.settings.lyricsFocusCascadeDelayIncrease,
            followingLineBaseDelay:
                model.settings.lyricsFocusCascadeFollowingDelay,
            preferredCatchUpCompletionRatio:
                model.settings.lyricsFocusCascadeCatchUpRatio,
            focusColorLeadTime: focusColorLeadTime,
            baseAnimationDuration: baseDuration,
            preferredAnimationDuration: cascadeDuration,
            prefersBounce: model.settings.lyricsFocusCascadeBounceEnabled,
            snapThreshold: model.settings.lyricsFocusSnapThreshold,
            remainingDuration: remainingDuration
        ) else {
            await moveFocusWithoutCascade(
                to: highlightedID,
                viewportHeight: viewportHeight
            )
            return
        }

        let transitionDate = Date.now
        let carriedPresentations = lyricMovementTransition?
            .presentationStates(at: transitionDate) ?? [:]
        var carriedOffsets = lyricMovementOffsetByID
        carriedOffsets.merge(
            carriedPresentations.mapValues(\.offset),
            uniquingKeysWith: { _, presentationOffset in
                presentationOffset
            }
        )
        let carriedVelocities = carriedPresentations.mapValues(\.velocity)
        let destinationOffsets = focusedLineFollowingOffsets(
            for: highlightedID
        )
        let preparedOffsets = Dictionary(
            uniqueKeysWithValues: model.lyrics.lyrics.map { line in
                (
                    line.id,
                    movementDistance
                        + carriedOffsets[line.id, default: 0]
                )
            }
        )
        let preparedTransition = LyricMovementTransition(
            focusID: highlightedID,
            initialOffsetsByID: preparedOffsets,
            destinationOffsetsByID: destinationOffsets
        )
        var preparation = Transaction()
        preparation.disablesAnimations = true
        withTransaction(preparation) {
            lyricMovementOffsetByID = preparedOffsets
            lyricMovementTransition = preparedTransition
            requestScroll(to: highlightedID)
        }
        self.positionedLyricID = highlightedID
        await Task.yield()
        let destinationIsPrepared = await waitForPreparedFocus(
            id: highlightedID,
            viewportHeight: viewportHeight
        )
        guard !Task.isCancelled,
              lyricMovementTransition?.id == preparedTransition.id else {
            return
        }
        guard destinationIsPrepared else {
            completeCascadeMovement(to: highlightedID)
            _ = await ensureFocusAlignment(
                to: highlightedID,
                viewportHeight: viewportHeight,
                animated: false
            )
            return
        }

        let chaseSpeedGradient = min(
            max(
                model.settings.lyricsFocusCascadeChaseSpeedGradient,
                AppSettings
                    .lyricsFocusCascadeChaseSpeedGradientRange.lowerBound
            ),
            AppSettings.lyricsFocusCascadeChaseSpeedGradientRange.upperBound
        )
        let slowestDuration = cascadeTiming.lineTiming(for: 0).duration
        let movementAnimations = Dictionary(
            uniqueKeysWithValues:
                model.lyrics.lyrics.enumerated().map { index, line in
                    let movementOrder = min(
                        max(index - highlightedIndex, 0),
                        maximumChaseOrder
                    )
                    let chaseOrder = min(
                        max(index - firstChasingIndex, 0),
                        maximumChaseOrder
                    )
                    let movementTiming = cascadeTiming.lineTiming(
                        for: movementOrder
                    )
                    let chaseTiming = cascadeTiming.lineTiming(
                        for: chaseOrder
                    )
                    let duration = slowestDuration
                        + (chaseTiming.duration - slowestDuration)
                            * chaseSpeedGradient
                    let destinationOffset = destinationOffsets[
                        line.id,
                        default: 0
                    ]
                    let initialOffset = preparedOffsets[
                        line.id,
                        default: destinationOffset
                    ]
                    let distance = destinationOffset - initialOffset
                    let rawVelocity = abs(distance) > 0.5
                        ? Double(
                            carriedVelocities[line.id, default: 0]
                                / distance
                        )
                        : 0
                    let initialVelocity = rawVelocity.isFinite
                        ? min(max(rawVelocity, -12), 12)
                        : 0
                    return (
                        line.id,
                        LyricMovementAnimationConfiguration(
                            delay: movementTiming.delay,
                            duration: duration,
                            usesBounce: cascadeTiming.usesBounce,
                            bounce: lyricFocusCascadeBounce(
                                chaseOrder: chaseOrder,
                                maximumChaseOrder: maximumChaseOrder
                            ),
                            initialVelocity: initialVelocity
                        )
                    )
                }
        )

        if focusColorLeadTime >= 0 {
            updateVisualColorFocus(to: highlightedID)
        }
        if focusColorLeadTime > 0 {
            try? await Task.sleep(for: .seconds(focusColorLeadTime))
        }
        guard !Task.isCancelled,
              self.highlightedID == highlightedID,
              lyricMovementTransition?.id == preparedTransition.id else {
            return
        }

        let startedTransition = preparedTransition.starting(
            with: movementAnimations,
            at: .now
        )
        var movementTransaction = Transaction(animation: nil)
        movementTransaction.disablesAnimations = true
        withTransaction(movementTransaction) {
            lyricMovementTransition = startedTransition
            lyricMovementOffsetByID = destinationOffsets
        }
        visualCascadeFocusLyricID = highlightedID

        if focusColorLeadTime < 0 {
            try? await Task.sleep(
                for: .seconds(max(-focusColorLeadTime, 0))
            )
            guard !Task.isCancelled,
                  self.highlightedID == highlightedID else { return }
            updateVisualColorFocus(to: highlightedID)
        }

        let elapsed = startedTransition.startedAt.map {
            Date.now.timeIntervalSince($0)
        } ?? 0
        let completionDuration = max(
            startedTransition.completionDuration - elapsed,
            0
        )
        try? await Task.sleep(
            for: .seconds(completionDuration + 1.0 / 60.0)
        )
        guard !Task.isCancelled,
              self.highlightedID == highlightedID,
              lyricMovementTransition?.id == startedTransition.id else {
            return
        }
        completeCascadeMovement(to: highlightedID)
    }

    private func lyricFocusCascadeBounce(
        chaseOrder: Int,
        maximumChaseOrder: Int
    ) -> Double {
        let maximumBounce = min(
            max(
                model.settings.lyricsFocusCascadeBounce,
                AppSettings.lyricsFocusCascadeBounceRange.lowerBound
            ),
            AppSettings.lyricsFocusCascadeBounceRange.upperBound
        )
        let bounceGradient = min(
            max(
                model.settings.lyricsFocusCascadeBounceGradient,
                AppSettings.lyricsFocusCascadeBounceGradientRange.lowerBound
            ),
            AppSettings.lyricsFocusCascadeBounceGradientRange.upperBound
        )
        let linePosition = min(
            max(chaseOrder, 0),
            maximumChaseOrder
        ) + 1
        let normalizedPosition = Double(linePosition)
            / Double(max(maximumChaseOrder + 1, 1))
        let bounceScale = 1
            - (1 - normalizedPosition) * bounceGradient
        return maximumBounce * bounceScale
    }

    private func isForwardAdjacentTransition(
        from currentID: LyricLine.ID,
        to nextID: LyricLine.ID
    ) -> Bool {
        guard let currentIndex = model.lyrics.lyrics.firstIndex(
                where: { $0.id == currentID }
              ),
              let nextIndex = model.lyrics.lyrics.firstIndex(
                where: { $0.id == nextID }
              ) else { return false }
        return nextIndex == currentIndex + 1
    }

    private func isInterludeHandoff(
        to highlightedID: LyricLine.ID
    ) -> Bool {
        positionedInterludeID.flatMap { positionedID in
            interludes.first { $0.id == positionedID }
        }?.followingLyricID == highlightedID
    }

    private func waitForPreparedFocus(
        id: LyricLine.ID,
        viewportHeight proposedViewportHeight: CGFloat
    ) async -> Bool {
        for attempt in 0..<30 {
            let viewportAnchorY = currentViewportHeight(
                fallback: proposedViewportHeight
            ) * focusPosition
            if let frame = geometryCache.frameByID[id] {
                let preparedAnchorY = frame.minY
                    + frame.height * focusPosition
                if abs(preparedAnchorY - viewportAnchorY) <= 2 {
                    return true
                }
            }
            guard !Task.isCancelled, attempt < 29 else { return false }
            do {
                try await Task.sleep(for: .milliseconds(16))
            } catch {
                return false
            }
        }
        return false
    }

    private func completeCascadeMovement(to id: LyricLine.ID) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            requestScroll(to: id)
            visualCascadeFocusLyricID = id
            lyricMovementOffsetByID = focusedLineFollowingOffsets(for: id)
            lyricMovementTransition = nil
            positionedLyricID = id
        }
        updateVisualColorFocus(to: id)
    }

    private func resetPlaybackFocus() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visualHighlightedLyricID = nil
            visualCascadeFocusLyricID = nil
            lyricFocusColorTransition = nil
            lyricMovementOffsetByID.removeAll()
            lyricMovementTransition = nil
            positionedLyricID = nil
        }
    }

    private func moveFocusWithoutCascade(
        to highlightedID: LyricLine.ID,
        viewportHeight: CGFloat
    ) async {
        let duration = LyricPlaybackTimeline.focusAnimationDuration(
            for: highlightedID,
            in: model.lyrics.lyrics
        )
        lyricMovementTransition = nil
        _ = await ensureFocusAlignment(
            to: highlightedID,
            viewportHeight: viewportHeight,
            animated: true,
            animationDuration: max(duration, 0.34)
        )
        guard !Task.isCancelled else { return }
        lyricMovementOffsetByID = focusedLineFollowingOffsets(
            for: highlightedID
        )
        updateVisualFocus(to: highlightedID)
        positionedLyricID = highlightedID
    }

    private func ensureFocusAlignment(
        to id: LyricLine.ID,
        viewportHeight proposedViewportHeight: CGFloat,
        animated: Bool,
        animationDuration: TimeInterval? = nil,
        forcesScrollTargetReapplication: Bool = false
    ) async -> Bool {
        let viewportHeight = currentViewportHeight(
            fallback: proposedViewportHeight
        )
        let viewportAnchorY = viewportHeight * focusPosition
        if !forcesScrollTargetReapplication,
           isFocusAligned(id: id, viewportAnchorY: viewportAnchorY) {
            return true
        }

        for attempt in 0..<3 {
            guard !Task.isCancelled else { return false }

            let duration = animationDuration
                ?? LyricPlaybackTimeline.focusAnimationDuration(
                    for: id,
                    in: model.lyrics.lyrics
                )
            let requestAnimationDuration = animated
                    && attempt == 0
                    && !reduceMotion
                    && isActive
                    && !isViewportChanging
                ? duration
                : nil
            requestScroll(
                to: id,
                animationDuration: requestAnimationDuration
            )
            await Task.yield()
            guard !Task.isCancelled else { return false }
            if await waitForPreparedFocus(
                id: id,
                viewportHeight: viewportHeight
            ) {
                return true
            }
        }
        return isFocusAligned(id: id, viewportAnchorY: viewportAnchorY)
    }

    private func isFocusAligned(
        id: LyricLine.ID,
        viewportAnchorY: CGFloat
    ) -> Bool {
        guard let frame = geometryCache.frameByID[id] else { return false }
        let currentAnchorY = frame.minY + frame.height * focusPosition
        return abs(currentAnchorY - viewportAnchorY) <= 2
    }

    private func updateVisualFocus(to highlightedID: LyricLine.ID) {
        updateVisualColorFocus(to: highlightedID)
        withAnimation(
            isActive && !isViewportChanging
                ? DesktopLyricsAnimations.focusScaleAnimation(
                    settings: model.settings,
                    highlightedID: highlightedID,
                    lyrics: model.lyrics.lyrics,
                    reduceMotion: reduceMotion,
                    isFocused: true
                )
                : nil
        ) {
            visualCascadeFocusLyricID = highlightedID
        }
    }

    private func updateVisualColorFocus(
        to highlightedID: LyricLine.ID?
    ) {
        guard !reduceMotion, isActive, !isViewportChanging else {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                lyricFocusColorTransition = nil
                visualHighlightedLyricID = highlightedID
            }
            return
        }
        startFocusColorTransition(to: highlightedID)
    }

    private func startFocusColorTransition(
        to highlightedLyricID: LyricLine.ID?
    ) {
        guard visualHighlightedLyricID != highlightedLyricID else { return }
        let now = Date.now
        let initialProgressByID: [LyricLine.ID: CGFloat]
        if let lyricFocusColorTransition {
            initialProgressByID = lyricFocusColorTransition
                .presentationProgressByID(at: now)
        } else if let visualHighlightedLyricID {
            initialProgressByID = [visualHighlightedLyricID: 1]
        } else {
            initialProgressByID = [:]
        }
        let transition = LyricFocusColorTransition(
            initialProgressByID: initialProgressByID,
            destinationLyricID: highlightedLyricID,
            startedAt: now,
            duration: Self.focusColorTransitionDuration
        )
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            visualHighlightedLyricID = highlightedLyricID
            lyricFocusColorTransition = transition
        }
    }

    private func finishFocusColorTransition(
        _ transition: LyricFocusColorTransition
    ) async {
        let remainingDuration = transition.completionDate
            .timeIntervalSince(.now)
        if remainingDuration > 0 {
            do {
                try await Task.sleep(for: .seconds(remainingDuration))
            } catch {
                return
            }
        }
        guard !Task.isCancelled,
              lyricFocusColorTransition?.id == transition.id else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricFocusColorTransition = nil
        }
    }

    private func lyricMovementPhase(
        for id: LyricLine.ID
    ) -> LyricMovementPhase {
        let fallbackOffset = lyricMovementOffsetByID[id, default: 0]
        guard !reduceMotion,
              let lyricMovementTransition else {
            return .stationary(offset: fallbackOffset)
        }
        return lyricMovementTransition.phase(
            for: id,
            fallbackOffset: fallbackOffset
        )
    }

    @ViewBuilder
    private func surfacedScrollView(viewportSize: CGSize) -> some View {
        let lyrics = model.lyrics.lyrics
        let viewportHeight = viewportSize.height
        let textLayoutWidth = DesktopLyricsLayoutMetrics.textLayoutWidth(
            viewportWidth: viewportSize.width,
            compact: compact
        )
        let visualFocusAnchorY =
            DesktopLyricsLayoutMetrics.visualFocusAnchorY(
                viewportHeight: viewportHeight,
                focusPosition: focusPosition
            )
        let topPadding: CGFloat = compact
            ? max(viewportHeight * focusPosition, 44)
            : max(viewportHeight * focusPosition, 40)
        let bottomPadding: CGFloat = compact
            ? max(viewportHeight * (1 - focusPosition), 96)
            : max(viewportHeight * (1 - focusPosition), 80)
        let lineSpacing = DesktopLyricsLayoutMetrics.lineSpacing(
            setting: model.settings.lyricsLineSpacing,
            compact: compact
        )
        let blurFocusIndex = lyrics.firstIndex {
            $0.id == blurFocusID
        }
        let precedingFocusID = blurFocusIndex.flatMap {
            index -> LyricLine.ID? in
            index > lyrics.startIndex ? lyrics[index - 1].id : nil
        }
        let followingFocusID = blurFocusIndex.flatMap {
            index -> LyricLine.ID? in
            let followingIndex = index + 1
            return followingIndex < lyrics.endIndex
                ? lyrics[followingIndex].id
                : nil
        }
        let hasTranslations = lyrics.contains(where: \.hasTranslation)
        let hasRomanizations = lyrics.contains(where: \.hasRomanization)
        let containsSyllableSyncedLyrics = lyrics.contains(
            where: \.isSyllableSynced
        )

        let scrollView = ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(
                    alignment: .leading,
                    spacing: lineSpacing
                ) {
                    ForEach(lyrics) { line in
                        if let layoutInterlude,
                           layoutInterlude.displayBeforeLyricID == line.id {
                            AppleMusicLyricInterludeView(
                                interlude: layoutInterlude,
                                advanceTime: effectiveLyricsAdvanceTime,
                                fontSize: lyricFontSize,
                                onInterfaceInteraction: nil
                            )
                            .environment(model.player)
                            .id(layoutInterlude.id)
                        }

                        lyricLine(
                            line,
                            layoutWidth: textLayoutWidth,
                            visualFocusAnchorY: visualFocusAnchorY,
                            isPrecedingFocusLine: line.id == precedingFocusID,
                            isFollowingFocusLine: line.id == followingFocusID,
                            hasTranslations: hasTranslations,
                            hasRomanizations: hasRomanizations,
                            hasSyllableSyncedLyrics:
                                containsSyllableSyncedLyrics
                        )
                            .id(line.id)
                    }
                }
                .animation(
                    reduceMotion ? nil : .smooth(duration: 0.5),
                    value: layoutInterlude?.id
                )
                .padding(.top, topPadding)
                .padding(.bottom, bottomPadding)
                .padding(.horizontal, compact ? 24 : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scrollTargetLayout()
            }
            .scrollIndicators(compact ? .automatic : .hidden)
            .scrollClipDisabled(!compact)
            .defaultScrollAnchor(focusAnchor, for: .sizeChanges)
            .onScrollPhaseChange { _, newPhase in
                switch newPhase {
                case .tracking, .interacting:
                    beginManualLyricsBrowsing()
                case .idle:
                    schedulePlaybackFollowing()
                case .decelerating, .animating:
                    break
                }
            }
            .onChange(of: scrollRequest, initial: true) { _, request in
                guard let request else { return }
                performScroll(request, with: proxy)
            }
            .transaction { transaction in
                if !isInitialFocusPrepared
                    || isViewportChanging
                    || (
                        keepsPlaybackFocusSynchronized
                            && isPresented
                            && !isActive
                    ) {
                    transaction.animation = nil
                    transaction.disablesAnimations = true
                }
            }
        }

        if compact {
            scrollView
        } else {
            scrollView.mask {
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.08),
                        .init(color: .black, location: 0.86),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(
                    width:
                        viewportSize.width
                        + horizontalVisualOverflow * 2
                )
            }
        }
    }

    nonisolated private static func lyricGlowOverflow(
        isEnabled: Bool,
        fontSize: Double,
        intensity: Double
    ) -> CGFloat {
        guard isEnabled else { return 0 }
        return CGFloat(min(max(fontSize * intensity * 0.75, 16), 32))
    }

    nonisolated private static func quantizedGeometryFrame(
        _ frame: CGRect
    ) -> CGRect {
        CGRect(
            x: quantizedGeometryValue(frame.minX),
            y: quantizedGeometryValue(frame.minY),
            width: quantizedGeometryValue(frame.width),
            height: quantizedGeometryValue(frame.height)
        )
    }

    nonisolated private static func quantizedGeometryValue(
        _ value: CGFloat
    ) -> CGFloat {
        (value * 2).rounded() / 2
    }

    private func lyricLine(
        _ line: LyricLine,
        layoutWidth: CGFloat,
        visualFocusAnchorY: CGFloat,
        isPrecedingFocusLine: Bool,
        isFollowingFocusLine: Bool,
        hasTranslations: Bool,
        hasRomanizations: Bool,
        hasSyllableSyncedLyrics: Bool
    ) -> some View {
        return DesktopLyricLineView(
            line: line,
            isPlaybackLine: line.id == visualHighlightedLyricID,
            isActualPlaybackLine: line.id == highlightedID,
            isScaleFocused: line.id == visualFocusID,
            isPrecedingFocusLine: isPrecedingFocusLine,
            isFollowingFocusLine: isFollowingFocusLine,
            actualHighlightedLyricID: highlightedID,
            visualHighlightedLyricID: visualHighlightedLyricID,
            focusColorTransition: lyricFocusColorTransition,
            movementPhase: lyricMovementPhase(for: line.id),
            layoutWidth: layoutWidth,
            visualFocusAnchorY: visualFocusAnchorY,
            compact: compact,
            allowsLyricBlur: allowsLyricBlur,
            foregroundColor: foregroundColor,
            hasTranslations: hasTranslations,
            hasRomanizations: hasRomanizations,
            hasSyllableSyncedLyrics: hasSyllableSyncedLyrics,
            onAnnotationHeightChange: { height in
                guard acceptsGeometryUpdates else { return }
                recordAnnotationHeight(height, for: line.id)
            },
            onSeek: {
                resumePlaybackFollowing()
            }
        )
        .onGeometryChange(for: CGRect.self) { geometry in
            Self.quantizedGeometryFrame(
                geometry.frame(in: .scrollView(axis: .vertical))
            )
        } action: { frame in
            guard acceptsGeometryUpdates else { return }
            recordLyricGeometry(frame, for: line.id)
        }
        .onDisappear {
            geometryCache.removeMeasurements(for: line.id)
        }
    }

    private var lyricFontSize: CGFloat {
        CGFloat(model.settings.lyricsFontSize)
    }

    private var lyricsCurrentLineScale: CGFloat {
        CGFloat(
            min(
                max(
                    model.settings.lyricsCurrentLineScale,
                    AppSettings.lyricsCurrentLineScaleRange.lowerBound
                ),
                AppSettings.lyricsCurrentLineScaleRange.upperBound
            )
        )
    }

    private func recordLyricGeometry(
        _ frame: CGRect,
        for id: LyricLine.ID
    ) {
        guard acceptsGeometryUpdates else { return }
        guard frame.minY.isFinite,
              frame.maxY.isFinite,
              frame.height.isFinite,
              frame.height > 0 else { return }
        guard let update = geometryCache.recordFrame(frame, for: id) else {
            return
        }
        if id == visualCascadeFocusLyricID,
           !isViewportChanging,
           lyricMovementTransition == nil,
           update.layoutHeightChanged {
            scheduleStationaryFollowingOffsetsSynchronization()
        }
    }

    private func recordAnnotationHeight(
        _ height: CGFloat,
        for id: LyricLine.ID
    ) {
        guard acceptsGeometryUpdates else { return }
        guard height.isFinite, height > 0 else { return }
        guard geometryCache.recordAnnotationHeight(height, for: id) else {
            return
        }
        if id == visualCascadeFocusLyricID,
           !isViewportChanging,
           lyricMovementTransition == nil {
            scheduleStationaryFollowingOffsetsSynchronization()
        }
    }

    private func scheduleStationaryFollowingOffsetsSynchronization() {
        geometryCache.scheduleLayoutSynchronization {
            guard lyricMovementTransition == nil else { return }
            synchronizeStationaryFollowingOffsets()
        }
    }

    private func synchronizeStationaryFollowingOffsets() {
        let offsets = focusedLineFollowingOffsets(
            for: visualCascadeFocusLyricID ?? highlightedID
        )
        guard !Self.offsetsAreApproximatelyEqual(
            lyricMovementOffsetByID,
            offsets
        ) else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricMovementOffsetByID = offsets
        }
    }

    private func beginManualLyricsBrowsing() {
        browsingGeneration &+= 1
        guard !isBrowsingLyrics else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isBrowsingLyrics = true
            scrollRequest = nil
            lyricMovementTransition = nil
            lyricMovementOffsetByID = focusedLineFollowingOffsets(
                for: visualCascadeFocusLyricID ?? highlightedID
            )
        }
    }

    private func schedulePlaybackFollowing() {
        guard isBrowsingLyrics,
              model.settings.lyricsAutoFollow else { return }

        let generation = browsingGeneration
        let delay = model.settings.lyricsFollowDelay
        Task { @MainActor in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return
            }
            guard generation == browsingGeneration else { return }
            isBrowsingLyrics = false
        }
    }

    private func resumePlaybackFollowing() {
        browsingGeneration &+= 1
        isBrowsingLyrics = false
    }

    private func settlePlaybackFocusDuringBrowsing(
        at highlightedID: LyricLine.ID
    ) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricMovementTransition = nil
            lyricMovementOffsetByID = focusedLineFollowingOffsets(
                for: highlightedID
            )
            visualCascadeFocusLyricID = highlightedID
            positionedLyricID = highlightedID
            positionedInterludeID = nil
        }
        updateVisualColorFocus(to: highlightedID)
    }

    private func settlePlaybackFocusDuringBrowsing(
        at interlude: LyricInterlude
    ) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            lyricMovementTransition = nil
            lyricMovementOffsetByID.removeAll()
            lyricFocusColorTransition = nil
            visualHighlightedLyricID = nil
            visualCascadeFocusLyricID = nil
            positionedLyricID = interlude.precedingLyricID
            positionedInterludeID = interlude.id
        }
    }

    nonisolated private static func offsetsAreApproximatelyEqual(
        _ lhs: [LyricLine.ID: CGFloat],
        _ rhs: [LyricLine.ID: CGFloat]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        return lhs.allSatisfy { id, value in
            guard let otherValue = rhs[id] else { return false }
            return abs(value - otherValue) <= 0.5
        }
    }

    private func focusedLineFollowingOffsets(
        for focusedLyricID: LyricLine.ID?
    ) -> [LyricLine.ID: CGFloat] {
        guard let focusedLyricID,
              let focusedIndex = model.lyrics.lyrics.firstIndex(
                where: { $0.id == focusedLyricID }
              ),
              focusedIndex + 1 < model.lyrics.lyrics.endIndex else {
            return [:]
        }

        let focusedLine = model.lyrics.lyrics[focusedIndex]
        let fallbackPrimaryHeight = lyricFontSize * 1.2
        var focusedLayoutHeight = geometryCache.layoutHeightByID[
            focusedLyricID
        ]
            ?? fallbackPrimaryHeight
        let expandsRomanization =
            model.settings.lyricsRomanizationEnabled
                && focusedLine.hasRomanization
                && model.settings.lyricsRomanizationDisplayMode
                    == .focusedLine
        let expandsTranslation =
            model.settings.lyricsTranslationEnabled
                && focusedLine.hasTranslation
                && model.settings.lyricsTranslationDisplayMode
                    == .focusedLine
        if (expandsRomanization || expandsTranslation),
           focusedLyricID != visualCascadeFocusLyricID {
            if expandsRomanization {
                focusedLayoutHeight += max(
                    lyricFontSize
                        * CGFloat(
                            model.settings.lyricsRomanizationFontScale
                        ),
                    compact ? 11 : 13
                ) * 1.2 + Self.annotationSpacing
            }
            if expandsTranslation {
                focusedLayoutHeight +=
                    (geometryCache.annotationHeightByID[focusedLyricID]
                        ?? max(
                            lyricFontSize
                                * CGFloat(
                                    model.settings
                                        .lyricsTranslationFontScale
                                ),
                            compact ? 11 : 13
                        ) * 1.2)
                    + Self.annotationSpacing
            }
        }
        let followingOffset = max(
            focusedLayoutHeight * (lyricsCurrentLineScale - 1),
            0
        )
        guard followingOffset > 0.5 else { return [:] }
        return Dictionary(
            uniqueKeysWithValues:
                model.lyrics.lyrics[(focusedIndex + 1)...].map {
                    ($0.id, followingOffset)
                }
        )
    }

}
