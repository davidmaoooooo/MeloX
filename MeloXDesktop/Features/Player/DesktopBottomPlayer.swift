import SwiftUI

private enum DesktopBottomPlayerMetrics {
    static let collapsedProgressHorizontalScale: CGFloat = 0.97
    static let regularGlobalInsetHeight: CGFloat = 70
    static let issueGlobalInsetHeight: CGFloat = 100
}

/// Renders the single player bar in the selected tab's content coordinate
/// space. The tab page owns selection gating so hidden tabs do not keep extra
/// player trees alive.
struct DesktopTabBottomPlayer: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        if model.player.currentSong != nil {
            HStack(spacing: 0) {
                Spacer(minLength: 0)
                DesktopBottomPlayer()
                    .frame(maxWidth: 780)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.leading, 24)
            .padding(.trailing, 24 + reservedTrailingWidth)
            .padding(.bottom, 10)
        }
    }

    private var reservedTrailingWidth: CGFloat {
        model.ui.inspector == nil
            ? 0
            : DesktopMainWindowMetrics.playerSidePanelWidth
    }
}

/// Reserves content space for the single player bar rendered by the app shell.
struct DesktopTabBottomPlayerInset: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        if model.player.currentSong != nil {
            Color.clear
                .frame(height: insetHeight)
                .accessibilityHidden(true)
        }
    }

    private var insetHeight: CGFloat {
        model.player.playbackIssue == nil
            ? DesktopBottomPlayerMetrics.regularGlobalInsetHeight
            : DesktopBottomPlayerMetrics.issueGlobalInsetHeight
    }
}

struct DesktopBottomPlayer: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        surfacedPlayer
            .shadow(color: .black.opacity(0.10), radius: 14, y: 7)
    }

    @ViewBuilder
    private var surfacedPlayer: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 12) {
                playerContent
                    .glassEffect(
                        .regular,
                        in: .rect(cornerRadius: 31)
                    )
            }
        } else {
            playerContent
                .background(
                    .regularMaterial,
                    in: .rect(cornerRadius: 31, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 31, style: .continuous)
                        .stroke(.white.opacity(0.42), lineWidth: 0.65)
                }
        }
    }

    private var playerContent: some View {
        VStack(spacing: 0) {
            if let issue = model.player.playbackIssue {
                HStack {
                    Label(issue.message, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                    Spacer()
                    Button("重试") { Task { await model.player.retry() } }
                    Button {
                        model.player.dismissPlaybackIssue()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
            }

            HStack(spacing: 10) {
                DesktopPlaybackControls()
                    .frame(width: 132)

                if let song = model.player.currentSong {
                    DesktopBottomMetadataSlot(song: song) {
                        model.ui.isNowPlayingPresented = true
                    }
                    .frame(maxWidth: .infinity)
                }

                playerMenu

                inspectorButton(
                    .lyrics,
                    systemImage: "quote.bubble",
                    title: "显示歌词"
                )

                inspectorButton(
                    .queue,
                    systemImage: "list.bullet",
                    title: "显示播放列表"
                )

                DesktopVolumeControl()
            }
            .padding(.horizontal, 15)
            .frame(height: 60)
        }
    }

    private var playerMenu: some View {
        Menu {
            if let song = model.player.currentSong {
                Button(
                    model.library.contains(song: song) ? "取消喜欢" : "喜欢",
                    systemImage: model.library.contains(song: song) ? "star.fill" : "star"
                ) {
                    model.library.toggle(song: song)
                }
                Button("下载", systemImage: "arrow.down.circle") {
                    model.downloads.start(song, quality: model.settings.quality)
                }
                Button("前往当前歌曲", systemImage: "arrow.right.circle") {
                    model.ui.navigate(to: .song(song.id))
                }
                Button("歌词", systemImage: "quote.bubble") {
                    model.ui.toggleInspector(.lyrics)
                }
                Button("播放队列", systemImage: "list.bullet") {
                    model.ui.toggleInspector(.queue)
                }
                DesktopPlaybackQualityMenu(model: model)
                Divider()
                Button("迷你播放器", systemImage: "pip") {
                    Task { @MainActor in
                        openWindow(id: "mini-player")
                        await DesktopMiniPlayerWindowCoordinator
                            .bringToFrontAfterOpening()
                    }
                }
                Button("全屏正在播放", systemImage: "arrow.up.left.and.arrow.down.right") {
                    model.ui.isNowPlayingPresented = true
                }
                Button("桌面歌词", systemImage: "text.quote") {
                    openWindow(id: "floating-lyrics")
                }
                Button("一起听", systemImage: "person.2.wave.2") {
                    model.ui.sheet = .listenTogether
                }
                Button("睡眠定时器", systemImage: "moon.zzz") {
                    model.ui.sheet = .sleepTimer
                }
                if let url = URL(string: "https://music.163.com/#/song?id=\(song.id)") {
                    ShareLink(item: url) {
                        Label("分享", systemImage: "square.and.arrow.up")
                    }
                }
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 26, height: 26)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    private func inspectorButton(
        _ destination: DesktopInspector,
        systemImage: String,
        title: String
    ) -> some View {
        let isSelected = model.ui.inspector == destination

        return Button {
            model.ui.toggleInspector(destination)
        } label: {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.14))
                    .opacity(isSelected ? 1 : 0)
                    .scaleEffect(isSelected ? 1 : 0.84)
                    .animation(
                        .snappy(duration: 0.24, extraBounce: 0.04),
                        value: isSelected
                    )

                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.red : Color.primary)
            }
            .frame(width: 30, height: 30)
            .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "已选择" : "未选择")
    }
}

private struct DesktopBottomMetadataSlot: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let song: Song
    let openNowPlaying: () -> Void
    @State private var isProgressExpanded = false
    @State private var isArtworkHovered = false
    @GestureState private var isProgressPressed = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Button(action: openNowPlaying) {
                HStack(spacing: 9) {
                    artwork

                    VStack(alignment: .leading, spacing: 1) {
                        Text(song.name)
                            .font(.system(size: 12.5, weight: .semibold))
                            .lineLimit(1)
                        Text("\(song.artistText) — \(song.album?.name ?? "")")
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
            .frame(maxHeight: .infinity, alignment: .center)
            .blur(radius: isProgressExpanded ? 7 : 0)
            .allowsHitTesting(!isProgressExpanded)

            VStack(spacing: 4) {
                if isProgressExpanded {
                    HStack {
                        Text(format(model.player.progress))
                        Spacer()
                        Text(
                            "−\(format(max(model.player.duration - model.player.progress, 0)))"
                        )
                    }
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.primary)
                    .frame(height: 15)
                    .transition(
                        .blurReplace.combined(
                            with: .scale(0.94, anchor: .bottom)
                        )
                    )
                }

                DesktopBottomSeekBar(
                    isExpanded: isProgressExpanded,
                    isPressed: isProgressPressed
                )
                .frame(height: 14)
                .contentShape(.rect)
            }
            .padding(.bottom, 1)
            .scaleEffect(
                x: isProgressPressed
                    ? 1.022
                    : isProgressExpanded
                        ? 1
                        : DesktopBottomPlayerMetrics
                            .collapsedProgressHorizontalScale,
                y: isProgressPressed ? 1.06 : 1,
                anchor: .bottom
            )
        }
        .frame(height: 54)
        .contentShape(.rect)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .updating($isProgressPressed) { _, pressed, _ in
                    guard isProgressExpanded else { return }
                    pressed = true
                }
        )
        .animation(
            reduceMotion ? nil : DesktopPlayerMotion.progressPress,
            value: isProgressPressed
        )
        .onContinuousHover { phase in
            switch phase {
            case .active(let location):
                if isProgressExpanded
                    || (!isArtworkHovered && location.y >= 38) {
                    setProgressExpanded(true)
                }
            case .ended:
                setProgressExpanded(false)
            }
        }
    }

    private var artwork: some View {
        ZStack {
            DesktopArtworkView(
                url: song.album?.artworkURL,
                cornerRadius: 6
            )

            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.black.opacity(isArtworkHovered ? 0.32 : 0))

            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.36), radius: 2, y: 1)
                .opacity(isArtworkHovered ? 1 : 0)
                .blur(radius: isArtworkHovered ? 0 : 1.8)
                .scaleEffect(isArtworkHovered ? 1 : 0.62)
        }
        .frame(width: 36, height: 36)
        .scaleEffect(isArtworkHovered ? 1.18 : 1)
        .shadow(
            color: .black.opacity(isArtworkHovered ? 0.26 : 0),
            radius: isArtworkHovered ? 8 : 0,
            y: isArtworkHovered ? 4 : 0
        )
        .zIndex(2)
        .onHover(perform: setArtworkHovered)
        .accessibilityAddTraits(.isButton)
    }

    private func setArtworkHovered(_ hovered: Bool) {
        guard isArtworkHovered != hovered else { return }
        withAnimation(
            reduceMotion
                ? nil
                : hovered
                    ? DesktopPlayerMotion.artworkHover
                    : DesktopPlayerMotion.artworkRest
        ) {
            isArtworkHovered = hovered
        }
    }

    private func setProgressExpanded(_ expanded: Bool) {
        guard isProgressExpanded != expanded else { return }
        withAnimation(
            reduceMotion
                ? nil
                : DesktopPlayerMotion.progress(expanded: expanded)
        ) {
            isProgressExpanded = expanded
            model.ui.isPlayerProgressHovered = expanded
        }
    }

    private func format(_ time: TimeInterval) -> String {
        guard time.isFinite else { return "0:00" }
        let seconds = max(Int(time), 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct DesktopBottomSeekBar: View {
    private static let idleTrackHeight: CGFloat = 2
    private static let expandedTrackHeight: CGFloat = 8

    @Environment(DesktopAppModel.self) private var model
    let isExpanded: Bool
    let isPressed: Bool

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                progressTrack(width: geometry.size.width)
                    .frame(maxHeight: .infinity, alignment: .center)
            }
            .allowsHitTesting(false)

            hiddenInteractionSlider
                .opacity(0.001)
        }
        .frame(maxWidth: .infinity)
    }

    private func progressTrack(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.primary.opacity(trackOpacity))

            Rectangle()
                .fill(.primary.opacity(fillOpacity))
                .frame(width: width * progressFraction)
        }
        .clipShape(.capsule)
        .frame(width: width, height: trackHeight)
        .scaleEffect(
            x: isExpanded
                ? 1
                : 1 / DesktopBottomPlayerMetrics
                    .collapsedProgressHorizontalScale,
            y: isPressed ? 1.14 : 1
        )
    }

    @ViewBuilder
    private var hiddenInteractionSlider: some View {
        if #available(macOS 26.0, *) {
            interactionSlider.sliderThumbVisibility(.hidden)
        } else {
            interactionSlider
        }
    }

    private var interactionSlider: some View {
        Slider(
            value: Binding(
                get: {
                    min(
                        model.player.progress,
                        max(model.player.duration, 0)
                    )
                },
                set: { model.player.seek(to: $0) }
            ),
            in: 0...max(model.player.duration, 1)
        )
        .controlSize(.large)
        .accessibilityLabel("播放进度")
    }

    private var progressFraction: CGFloat {
        let duration = max(model.player.duration, 0)
        guard duration > 0 else { return 0 }
        return CGFloat(
            min(max(model.player.progress / duration, 0), 1)
        )
    }

    private var trackHeight: CGFloat {
        isExpanded
            ? Self.expandedTrackHeight
            : Self.idleTrackHeight
    }

    private var trackOpacity: Double {
        isExpanded ? 0.30 : 0.24
    }

    private var fillOpacity: Double {
        isExpanded ? 0.86 : 0.70
    }
}
