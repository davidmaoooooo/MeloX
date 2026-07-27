import SwiftUI

struct NowPlayingLandscapeView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(PlayerStore.self) private var player
    @Environment(AppSettings.self) private var settings

    @Binding var page: NowPlayingPage
    let showsLyricsControls: Bool

    let song: Song
    let lyrics: [LyricLine]
    let lyricError: String?
    let highlightedLyricID: LyricLine.ID?
    let artworkNamespace: Namespace.ID
    let onDismiss: () -> Void
    let onInterfaceInteraction: () -> Void
    let onInterfaceVisibilityChange: (Bool) -> Void

    @State private var showsSkylineLyrics = false

    var body: some View {
        ZStack {
            if showsSkylineLyrics, page == .lyrics {
                SkylineLyricsView(
                    artworkURL: song.album?.artworkURL,
                    lyrics: lyrics,
                    errorMessage: lyricError,
                    highlightedLyricID: highlightedLyricID,
                    onExit: exitSkylineLyrics
                )
                .transition(.opacity)
            } else {
                standardPlayer
                    .transition(.opacity)
            }
        }
        .onChange(of: page) { _, newPage in
            if newPage != .lyrics {
                showsSkylineLyrics = false
            }
        }
        .animation(
            accessibilityReduceMotion ? nil : .smooth(duration: 0.4),
            value: showsSkylineLyrics
        )
    }

    private var standardPlayer: some View {
        VStack(spacing: 0) {
            dismissalHandle

            GeometryReader { proxy in
                let artworkSide = min(
                    proxy.size.height,
                    proxy.size.width * 0.43,
                    460
                )

                HStack(spacing: landscapeSpacing(for: proxy.size.width)) {
                    artwork(side: artworkSide)

                    rightPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: 1_100, maxHeight: .infinity)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .safeAreaPadding(.top, 2)
        .safeAreaPadding(.bottom, 8)
    }

    private var dismissalHandle: some View {
        Button(action: onDismiss) {
            Capsule()
                .fill(.white.opacity(0.52))
                .frame(width: 38, height: 5)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .frame(height: 28)
        .accessibilityLabel("收起播放器")
        .accessibilityHint("轻点收起，或向下拖动播放器")
        .gesture(dismissalDragGesture)
    }

    private func artwork(side: CGFloat) -> some View {
        ArtworkImage(url: song.album?.artworkURL, cornerRadius: 12)
            .frame(width: side, height: side)
            .scaleEffect(player.isPlaying || !settings.shrinksPausedArtwork ? 1 : 0.9)
            .shadow(
                color: .black.opacity(
                    player.isPlaying ? 0.32 : 0.18
                ),
                radius: player.isPlaying ? 24 : 14,
                y: player.isPlaying ? 12 : 7
            )
            .animation(.smooth(duration: 0.45), value: player.isPlaying)
            .accessibilityElement()
            .accessibilityLabel("\(song.name)的封面")
    }

    private var rightPanel: some View {
        VStack(spacing: 0) {
            songHeader

            if usesExpandedAppleMusicLyricsLayout {
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottom) {
                        pageSelector
                    }
            } else {
                pageContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                pageSelector
            }
        }
    }

    private var pageSelector: some View {
        NowPlayingPageSelector(page: $page)
            .opacity(hidesLyricsControls ? 0 : 1)
            .allowsHitTesting(!hidesLyricsControls)
            .accessibilityHidden(hidesLyricsControls)
    }

    private var hidesLyricsControls: Bool {
        page == .lyrics && !showsLyricsControls
    }

    private var usesExpandedAppleMusicLyricsLayout: Bool {
        page == .lyrics && settings.lyricsStyle == .appleMusic
    }

    private var songHeader: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.headline)
                    .lineLimit(1)

                Text(song.artistText)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.64))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if page == .lyrics, !lyrics.isEmpty {
                Button(action: enterSkylineLyrics) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.title3.weight(.medium))
                        .frame(width: 40, height: 40)
                        .background(.white.opacity(0.13), in: .circle)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("打开全屏天际歌词")
            }

            NowPlayingSongActions(
                song: song
            )
        }
        .frame(height: 52)
    }

    private var pageContent: some View {
        ZStack {
            NowPlayingQueuePage(
                song: song,
                presentation: .landscape,
                artworkNamespace: artworkNamespace
            )
            .opacity(page == .queue ? 1 : 0)
            .allowsHitTesting(page == .queue)
            .accessibilityHidden(page != .queue)

            switch page {
            case .artwork:
                landscapeArtworkControls
                    .transition(.opacity)
            case .lyrics:
                NowPlayingLyricsPage(
                    song: song,
                    lyrics: lyrics,
                    errorMessage: lyricError,
                    highlightedLyricID: highlightedLyricID,
                    presentation: .landscape,
                    isInterfaceHidden: hidesLyricsControls,
                    artworkNamespace: artworkNamespace,
                    onInterfaceInteraction:
                        onInterfaceInteraction,
                    onInterfaceVisibilityChange:
                        onInterfaceVisibilityChange
                )
                .accessibilityAction(
                    named: lyricsInterfaceAccessibilityActionName
                ) {
                    onInterfaceInteraction()
                }
                .transition(.opacity)
            case .queue:
                EmptyView()
            }
        }
    }

    private var landscapeArtworkControls: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            NowPlayingProgressControl(song: song)
            NowPlayingTransportControls()
            NowPlayingVolumeControl()
            Spacer(minLength: 0)
        }
    }

    private func landscapeSpacing(for width: CGFloat) -> CGFloat {
        min(max(width * 0.035, 18), 38)
    }

    private var lyricsInterfaceAccessibilityActionName: String {
        if settings.lyricsStyle == .appleMusic {
            return "显示播放器控制"
        }
        return showsLyricsControls
            ? "隐藏播放器控制"
            : "显示播放器控制"
    }

    private func enterSkylineLyrics() {
        showsSkylineLyrics = true
    }

    private func exitSkylineLyrics() {
        showsSkylineLyrics = false
    }

    private var dismissalDragGesture: some Gesture {
        DragGesture(minimumDistance: 8)
            .onEnded { value in
                guard value.translation.height > 60,
                      abs(value.translation.height) > abs(value.translation.width) else {
                    return
                }
                onDismiss()
            }
    }
}
