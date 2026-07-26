import SwiftUI

enum NowPlayingPage: String, Hashable {
    case artwork
    case lyrics
    case queue
}

struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(\.accessibilityVoiceOverEnabled)
    private var accessibilityVoiceOverEnabled
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings
    @Environment(LyricsStore.self) private var lyricsStore

    @State private var page: NowPlayingPage
    @State private var showsLyricsControls = true
    @State private var appleMusicControlsActivityGeneration = 0
    @State private var highlightedLyricID: LyricLine.ID?
    @State private var showsTextPVLandscapeSuggestion = false
    @State private var isQueueSongHeaderHidden = false
    @State private var queueSongHeaderOffset: CGFloat = 0
    @State private var artworkPageFrame = CGRect.zero
    @State private var entersPageFromHiddenQueue = false
    @GestureState private var isInteractingWithPlayer = false
    @Namespace private var pageArtworkNamespace

    init(initialPage: NowPlayingPage = .artwork) {
        _page = State(initialValue: initialPage)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if usesMonochromeLyricsBackground {
                    Color.black
                        .ignoresSafeArea()
                } else {
                    NowPlayingBackground(
                        artworkURL: player.currentSong?.album?.artworkURL
                    )
                }

                if let song = player.currentSong {
                    if usesFullScreenTextPV {
                        TextPVFullScreenPlayerView(
                            page: pageSelection,
                            showsControls: $showsLyricsControls,
                            song: song,
                            lyrics: lyrics,
                            errorMessage: lyricError,
                            highlightedLyricID: highlightedLyricID,
                            onDismiss: { dismiss() },
                            onToggleInterface:
                                toggleLyricsControls
                        )
                        .transition(.opacity)
                    } else if proxy.size.width > proxy.size.height {
                        NowPlayingLandscapeView(
                            page: pageSelection,
                            showsLyricsControls: showsLyricsControls,
                            song: song,
                            lyrics: lyrics,
                            lyricError: lyricError,
                            highlightedLyricID: highlightedLyricID,
                            artworkNamespace: pageArtworkNamespace,
                            onDismiss: { dismiss() },
                            onInterfaceInteraction:
                                handleLyricsInterfaceInteraction,
                            onInterfaceVisibilityChange:
                                setAppleMusicLyricsControlsVisible
                        )
                    } else {
                        portraitContent(for: song)
                    }
                } else {
                    ContentUnavailableView("没有正在播放的歌曲", systemImage: "music.note")
                        .foregroundStyle(.white)
                }

                if usesFullScreenTextPV,
                   showsTextPVLandscapeSuggestion,
                   proxy.size.width <= proxy.size.height {
                    Label("建议切换至横屏观看文字PV", systemImage: "rectangle.landscape.rotate")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.regularMaterial, in: .capsule)
                        .shadow(color: .black.opacity(0.24), radius: 12, y: 5)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                        .safeAreaPadding(.top, 58)
                        .accessibilityLabel("建议切换至横屏观看文字PV")
                }
            }
        }
        .background {
            NowPlayingLyricSynchronizer(
                lyrics: lyrics,
                highlightedLyricID: $highlightedLyricID
            )
        }
        .simultaneousGesture(
            playerActivityGesture,
            including: acceptsPlayerActivityGesture ? .all : .none
        )
        .onChange(of: isInteractingWithPlayer) { _, isInteracting in
            guard isInteracting else { return }
            registerAppleMusicControlsActivity()
        }
        .keepsScreenAwake(keepsPlayerScreenAwake)
        .preferredColorScheme(.dark)
        .task(id: usesFullScreenTextPV) {
            guard usesFullScreenTextPV else {
                showsTextPVLandscapeSuggestion = false
                return
            }

            withAnimation(accessibilityReduceMotion ? nil : .smooth(duration: 0.25)) {
                showsTextPVLandscapeSuggestion = true
            }
            do {
                try await Task.sleep(for: .seconds(3.2))
            } catch {
                return
            }
            withAnimation(accessibilityReduceMotion ? nil : .easeOut(duration: 0.2)) {
                showsTextPVLandscapeSuggestion = false
            }
        }
        .task(id: appleMusicControlsActivityGeneration) {
            guard usesAutoHidingAppleMusicInterface,
                  showsLyricsControls,
                  !accessibilityVoiceOverEnabled else {
                return
            }

            do {
                try await Task.sleep(
                    for: .seconds(
                        settings
                            .appleMusicLyricsInterfaceAutoHideDelay
                    )
                )
            } catch {
                return
            }
            guard !Task.isCancelled,
                  usesAutoHidingAppleMusicInterface else {
                return
            }

            withAnimation(
                accessibilityReduceMotion
                    ? nil
                    : .easeOut(duration: 0.3)
            ) {
                showsLyricsControls = false
            }
        }
        .task(id: entersPageFromHiddenQueue) {
            await restoreArtworkTransitionAfterHiddenQueueEntry()
        }
        .onChange(of: page) { _, newPage in
            if newPage == .lyrics,
               settings.lyricsStyle == .appleMusic {
                registerAppleMusicControlsActivity()
            } else {
                cancelAppleMusicControlsAutoHide()
                showsLyricsControls = true
            }

            guard settings.rememberNowPlayingPage else { return }
            settings.rememberedNowPlayingPage = newPage.rawValue
        }
        .onChange(of: accessibilityVoiceOverEnabled) {
            _, voiceOverEnabled in
            guard usesAutoHidingAppleMusicInterface else { return }

            if voiceOverEnabled {
                cancelAppleMusicControlsAutoHide()
                showsLyricsControls = true
            } else {
                registerAppleMusicControlsActivity()
            }
        }
        .onChange(of: settings.lyricsStyle) { _, newStyle in
            cancelAppleMusicControlsAutoHide()
            showsLyricsControls = true

            if page == .lyrics, newStyle == .appleMusic {
                registerAppleMusicControlsActivity()
            }
        }
        .onChange(
            of: settings.appleMusicLyricsInterfaceAutoHideDelay
        ) {
            registerAppleMusicControlsActivity()
        }
    }

    private func portraitContent(for song: Song) -> some View {
        VStack(spacing: 0) {
            dismissalHandle

            pageContent(for: song)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .overlay(alignment: .bottom) {
                    portraitPlayerControls(for: song)
                        .opacity(hidesLyricsControls ? 0 : 1)
                        .allowsHitTesting(!hidesLyricsControls)
                        .accessibilityHidden(hidesLyricsControls)
                }
        }
        .padding(.horizontal, 32)
        .safeAreaPadding(.bottom, 3)
    }

    private func portraitPlayerControls(for song: Song) -> some View {
        NowPlayingBottomControls(
            song: song,
            page: pageSelection,
            showsLyricsUtilities: usesExpandedAppleMusicLyricsLayout
        )
    }

    private var pageSelection: Binding<NowPlayingPage> {
        Binding(
            get: { page },
            set: { newPage in
                entersPageFromHiddenQueue =
                    page == .queue
                    && isQueueSongHeaderHidden
                    && newPage != .queue
                if newPage == .queue, page != .queue {
                    isQueueSongHeaderHidden = false
                    queueSongHeaderOffset = 0
                }
                page = newPage
            }
        )
    }

    private var hidesLyricsControls: Bool {
        page == .lyrics && !showsLyricsControls
    }

    private var usesAutoHidingAppleMusicInterface: Bool {
        page == .lyrics && settings.lyricsStyle == .appleMusic
    }

    private var lyrics: [LyricLine] {
        lyricsStore.lyrics
    }

    private var lyricError: String? {
        lyricsStore.errorMessage
    }

    private var keepsPlayerScreenAwake: Bool {
        switch settings.playerScreenAwakeMode {
        case .disabled:
            false
        case .player:
            true
        case .lyrics:
            page == .lyrics
        case .hiddenLyricsInterface:
            hidesLyricsControls
        }
    }

    private var usesExpandedAppleMusicLyricsLayout: Bool {
        page == .lyrics && settings.lyricsStyle == .appleMusic
    }

    private var usesFullScreenTextPV: Bool {
        page == .lyrics && settings.lyricsStyle == .textPV
    }

    private var usesMonochromeLyricsBackground: Bool {
        page == .lyrics && settings.lyricsStyle.usesMonochromePlayerBackground
    }

    private var dismissalHandle: some View {
        ZStack(alignment: .top) {
            Capsule()
                .fill(.white.opacity(0.52))
                .frame(width: 60, height: 5)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .contentShape(.rect)
        .onTapGesture {
            dismiss()
        }
        .gesture(dismissalDragGesture)
        .accessibilityElement()
        .accessibilityLabel("收起播放器")
        .accessibilityHint("轻点收起，或向下拖动播放器")
        .accessibilityAction {
            dismiss()
        }
    }

    private func pageContent(for song: Song) -> some View {
        ZStack(alignment: .top) {
            switch page {
            case .artwork:
                NowPlayingArtworkPage(
                    song: song,
                    artworkNamespace: pageArtworkNamespace,
                    usesArtworkTransition: false,
                    showsArtwork: false,
                    onArtworkFrameChange: {
                        guard page == .artwork else { return }
                        artworkPageFrame = $0
                    }
                )
                .transition(
                    pageContentTransition(for: .artwork)
                )
            case .lyrics:
                NowPlayingLyricsPage(
                    song: song,
                    lyrics: lyrics,
                    errorMessage: lyricError,
                    highlightedLyricID: highlightedLyricID,
                    isInterfaceHidden: hidesLyricsControls,
                    artworkNamespace: pageArtworkNamespace,
                    usesArtworkTransition:
                        !entersPageFromHiddenQueue,
                    showsSongHeader: false,
                    onInterfaceInteraction:
                        handleLyricsInterfaceInteraction,
                    onInterfaceVisibilityChange:
                        setAppleMusicLyricsControlsVisible
                )
                .accessibilityAction(
                    named: lyricsInterfaceAccessibilityActionName
                ) {
                    handleLyricsInterfaceInteraction()
                }
                .transition(
                    pageContentTransition(for: .lyrics)
                )
            case .queue:
                NowPlayingQueuePage(
                    song: song,
                    presentation: .portrait,
                    artworkNamespace: pageArtworkNamespace,
                    usesArtworkTransition:
                        !entersPageFromHiddenQueue,
                    showsSongHeader: false,
                    onSongHeaderHiddenChange: {
                        isQueueSongHeaderHidden = $0
                    },
                    onSongHeaderOffsetChange: {
                        queueSongHeaderOffset = $0
                    }
                )
                .transition(
                    pageContentTransition(for: .queue)
                )
            }

            if page != .artwork {
                sharedPortraitSongHeader(for: song)
                    .offset(y: sharedPortraitSongHeaderOffset)
                    .transition(
                        NowPlayingPageTransition.songHeader(
                            reducesMotion: accessibilityReduceMotion
                        )
                    )
            }

            if portraitArtworkFrame.width > 0 {
                NowPlayingPortraitArtwork(
                    song: song,
                    isArtworkPage: page == .artwork
                )
                .frame(
                    width: portraitArtworkFrame.width,
                    height: portraitArtworkFrame.height
                )
                .position(
                    x: portraitArtworkFrame.midX,
                    y: portraitArtworkFrame.midY
                )
                .allowsHitTesting(false)
            }
        }
        .clipped()
        .coordinateSpace(
            name: NowPlayingPortraitCoordinateSpace.name
        )
    }

    private func sharedPortraitSongHeader(
        for song: Song
    ) -> some View {
        NowPlayingSongHeader(
            song: song,
            artworkNamespace: pageArtworkNamespace,
            usesReferenceLayout: true,
            usesArtworkTransition: false,
            showsArtwork: false
        )
    }

    private var portraitArtworkFrame: CGRect {
        if page == .artwork {
            return artworkPageFrame
        }

        return CGRect(
            x: 0,
            y: sharedPortraitSongHeaderOffset,
            width: NowPlayingSongHeader.referenceHeight,
            height: NowPlayingSongHeader.referenceHeight
        )
    }

    private var sharedPortraitSongHeaderOffset: CGFloat {
        page == .queue ? queueSongHeaderOffset : 0
    }

    private func pageContentTransition(
        for destination: NowPlayingPage
    ) -> AnyTransition {
        NowPlayingPageTransition.content(
            for: destination,
            entersFromHiddenQueue: entersPageFromHiddenQueue,
            reducesMotion: accessibilityReduceMotion
        )
    }

    private func restoreArtworkTransitionAfterHiddenQueueEntry() async {
        guard entersPageFromHiddenQueue else { return }

        do {
            try await Task.sleep(for: .milliseconds(420))
        } catch {
            return
        }
        guard !Task.isCancelled else { return }

        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            entersPageFromHiddenQueue = false
        }
    }

    private var dismissalDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                guard value.translation.height > 60,
                      abs(value.translation.height) > abs(value.translation.width) else {
                    return
                }
                dismiss()
            }
    }

    private var playerActivityGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($isInteractingWithPlayer) { _, isInteracting, _ in
                isInteracting = true
            }
    }

    private var lyricsInterfaceAccessibilityActionName: String {
        if settings.lyricsStyle == .appleMusic {
            return "显示播放器控制"
        }
        return showsLyricsControls
            ? "隐藏播放器控制"
            : "显示播放器控制"
    }

    private func handleLyricsInterfaceInteraction() {
        if settings.lyricsStyle == .appleMusic {
            registerAppleMusicControlsActivity()
        } else {
            toggleLyricsControls()
        }
    }

    private func registerAppleMusicControlsActivity() {
        guard usesAutoHidingAppleMusicInterface else { return }

        appleMusicControlsActivityGeneration &+= 1
        guard !showsLyricsControls else { return }

        withAnimation(
            accessibilityReduceMotion
                ? nil
                : .easeInOut(duration: 0.25)
        ) {
            showsLyricsControls = true
        }
    }

    private func setAppleMusicLyricsControlsVisible(_ isVisible: Bool) {
        guard usesAutoHidingAppleMusicInterface else { return }
        if isVisible {
            registerAppleMusicControlsActivity()
            return
        }

        guard showsLyricsControls,
              !accessibilityVoiceOverEnabled else {
            return
        }
        cancelAppleMusicControlsAutoHide()
        withAnimation(
            accessibilityReduceMotion
                ? nil
                : .easeOut(duration: 0.25)
        ) {
            showsLyricsControls = false
        }
    }

    private func toggleLyricsControls() {
        withAnimation(
            accessibilityReduceMotion
                ? nil
                : .smooth(duration: 0.3)
        ) {
            showsLyricsControls.toggle()
        }
    }

    private func cancelAppleMusicControlsAutoHide() {
        appleMusicControlsActivityGeneration &+= 1
    }

    private var acceptsPlayerActivityGesture: Bool {
        usesAutoHidingAppleMusicInterface && showsLyricsControls
    }
}
