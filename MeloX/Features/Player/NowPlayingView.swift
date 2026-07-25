import SwiftUI

enum NowPlayingPage: String, Hashable {
    case artwork
    case details
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
                            page: $page,
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
                            page: $page,
                            showsLyricsControls: showsLyricsControls,
                            song: song,
                            lyrics: lyrics,
                            lyricError: lyricError,
                            highlightedLyricID: highlightedLyricID,
                            artworkNamespace: pageArtworkNamespace,
                            onDismiss: { dismiss() },
                            onInterfaceInteraction:
                                handleLyricsInterfaceInteraction
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
            including: usesAutoHidingAppleMusicInterface ? .all : .none
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
        .onChange(of: page) { _, newPage in
            if newPage == .lyrics,
               settings.lyricsStyle == .appleMusic {
                registerAppleMusicControlsActivity()
            } else {
                cancelAppleMusicControlsAutoHide()
                showsLyricsControls = true
            }

            guard settings.rememberNowPlayingPage else { return }
            settings.rememberedNowPlayingPage = (
                newPage == .details ? NowPlayingPage.artwork : newPage
            ).rawValue
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
        .animation(.smooth(duration: 0.4), value: page)
    }

    private func portraitContent(for song: Song) -> some View {
        VStack(spacing: 0) {
            dismissalHandle

            if usesExpandedAppleMusicLyricsLayout {
                pageContent(for: song)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        portraitPlayerControls(for: song)
                            .opacity(hidesLyricsControls ? 0 : 1)
                            .allowsHitTesting(!hidesLyricsControls)
                            .accessibilityHidden(hidesLyricsControls)
                    }
            } else {
                pageContent(for: song)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                portraitPlayerControls(for: song)
                    .opacity(hidesLyricsControls ? 0 : 1)
                    .allowsHitTesting(!hidesLyricsControls)
                    .accessibilityHidden(hidesLyricsControls)
            }
        }
        .padding(.horizontal, 28)
        .safeAreaPadding(.top, 4)
        .safeAreaPadding(.bottom, 8)
    }

    private func portraitPlayerControls(for song: Song) -> some View {
        VStack(spacing: 0) {
            NowPlayingProgressControl(song: song)
            NowPlayingTransportControls()
            NowPlayingVolumeControl()
            NowPlayingPageSelector(page: $page)
        }
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
        Capsule()
            .fill(.white.opacity(0.52))
            .frame(width: 38, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
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
        ZStack {
            switch page {
            case .artwork:
                NowPlayingArtworkPage(
                    song: song,
                    artworkNamespace: pageArtworkNamespace,
                    onShowDetails: showDetails
                )
                .transition(.opacity)
            case .details:
                NowPlayingSongDetailsPage(
                    song: song,
                    showsArtworkToggle: true,
                    artworkNamespace: pageArtworkNamespace,
                    onShowArtwork: showArtwork
                )
                .transition(.opacity)
            case .lyrics:
                NowPlayingLyricsPage(
                    song: song,
                    lyrics: lyrics,
                    errorMessage: lyricError,
                    highlightedLyricID: highlightedLyricID,
                    isInterfaceHidden: hidesLyricsControls,
                    artworkNamespace: pageArtworkNamespace,
                    onInterfaceInteraction:
                        handleLyricsInterfaceInteraction,
                    onShowDetails: showDetails
                )
                .accessibilityAction(
                    named: lyricsInterfaceAccessibilityActionName
                ) {
                    handleLyricsInterfaceInteraction()
                }
                .transition(.opacity)
            case .queue:
                NowPlayingQueuePage()
                    .transition(.opacity)
            }
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

    private func showDetails() {
        withAnimation(.smooth(duration: 0.3)) {
            page = .details
        }
    }

    private func showArtwork() {
        withAnimation(.smooth(duration: 0.3)) {
            page = .artwork
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
}
