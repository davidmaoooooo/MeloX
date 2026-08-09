import SwiftUI

private extension Color {
    init(rgb: SIMD3<Double>) {
        self.init(red: rgb.x, green: rgb.y, blue: rgb.z)
    }
}

struct DesktopNowPlayingWindow: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var page: DesktopInspector? = .lyrics
    @State private var palette = ArtworkDetailPalette.fallback(
        prefersDarkAppearance: true
    )
    let isActive: Bool
    let isRenderingActive: Bool

    private var artworkURL: URL? {
        model.player.currentSong?.album?.artworkURL
    }

    private var artworkInfluencedForeground: Color {
        let white = SIMD3<Double>(repeating: 1)
        return Color(rgb: white * 0.88 + palette.backgroundRGB * 0.12)
    }

    private var keepsScreenAwake: Bool {
        guard isActive, model.player.isPlaying else { return false }
        switch model.settings.playerScreenAwakeMode {
        case .disabled:
            return false
        case .player:
            return true
        case .lyrics:
            return page == .lyrics
        case .hiddenLyricsInterface:
            return false
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                nowPlayingContent(in: proxy)

                playerChrome
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .topLeading
                    )
                    .zIndex(100)
            }
            .frame(
                width: proxy.size.width,
                height: proxy.size.height,
                alignment: .topLeading
            )
            .clipped()
        }
        .ignoresSafeArea(.container, edges: .top)
        .environment(\.colorScheme, .dark)
        .frame(minWidth: 980, minHeight: 540)
        .keepsScreenAwake(keepsScreenAwake)
        .task(id: artworkURL) {
            palette = await ArtworkAccentColorProvider.shared.detailPalette(
                for: artworkURL,
                fallbackPrefersDarkAppearance: true
            )
        }
    }

    private func nowPlayingContent(
        in proxy: GeometryProxy
    ) -> some View {
        let layout = DesktopNowPlayingLayout(viewport: proxy.size)

        return Group {
            if let page {
                HStack(alignment: .top, spacing: layout.panelSpacing) {
                    playerColumn(layout: layout)
                        .frame(
                            width: layout.playerWidth,
                            height: layout.contentHeight,
                            alignment: .top
                        )

                    nowPlayingPanel(page)
                        .frame(
                            maxWidth: .infinity,
                            maxHeight: layout.contentHeight,
                            alignment: .topLeading
                        )
                        .transition(
                            .opacity.combined(
                                with: .scale(
                                    scale: 0.985,
                                    anchor: .topLeading
                                )
                            )
                        )
                }
                .padding(.leading, layout.leading)
                .padding(.trailing, layout.trailing)
                .padding(.top, layout.chromeHeight)
                .frame(
                    width: proxy.size.width,
                    height: proxy.size.height,
                    alignment: .topLeading
                )
            } else {
                playerColumn(layout: layout)
                    .frame(
                        width: layout.playerWidth,
                        height: layout.contentHeight,
                        alignment: .top
                    )
                    .padding(.top, layout.chromeHeight)
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height,
                        alignment: .top
                    )
            }
        }
        .animation(
            reduceMotion ? nil : .smooth(duration: 0.38),
            value: page
        )
    }

    @ViewBuilder
    private func nowPlayingPanel(_ page: DesktopInspector) -> some View {
        switch page {
        case .lyrics:
            DesktopPlaybackPositionedLyricsView(
                compact: false,
                foregroundColor: artworkInfluencedForeground,
                isActive: isRenderingActive,
                isPresented: isActive,
                keepsPlaybackFocusSynchronized: true
            )
            .padding(.trailing, 72)
        case .queue:
            DesktopQueueView(presentation: .nowPlaying)
        }
    }

    private var playerChrome: some View {
        DesktopNowPlayingPageSwitcher(page: $page)
            .padding(.trailing, 10)
            .padding(.bottom, 10)
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottomTrailing
            )
        .allowsHitTesting(true)
    }

    private func playerColumn(layout: DesktopNowPlayingLayout) -> some View {
        VStack(alignment: .leading, spacing: 0) {

            DesktopNowPlayingArtwork(
                artworkURL: model.player.currentSong?.album?.artworkURL,
                songName: model.player.currentSong?.name,
                pausedSize: layout.artworkSize,
                isPlaying: model.player.isPlaying,
                shrinksWhenPaused: model.settings.shrinksPausedArtwork
            )
            .frame(maxWidth: .infinity)
            .padding(.top, layout.artworkTopInset)

            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.player.currentSong?.name ?? "未在播放")
                        .font(.system(size: 18, weight: .bold))
                        .lineLimit(1)
                    Text(
                        [
                            model.player.currentSong?.artistText,
                            model.player.currentSong?.album?.name,
                        ]
                        .compactMap { $0 }
                        .joined(separator: " — ")
                    )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.60))
                    .lineLimit(1)
                }

                Spacer(minLength: 6)

                Button {
                    guard let song = model.player.currentSong else { return }
                    model.library.toggle(song: song)
                } label: {
                    Image(
                        systemName: model.player.currentSong.map {
                            model.library.contains(song: $0)
                        } == true ? "star.fill" : "star"
                    )
                    .frame(width: 28, height: 28)
                    .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .modifier(DesktopNowPlayingCircularGlass())

                Menu {
                    if let song = model.player.currentSong {
                        Button("下载", systemImage: "arrow.down.circle") {
                            model.downloads.start(song, quality: model.settings.quality)
                        }
                        DesktopPlaybackQualityMenu(model: model)
                        Button("桌面歌词", systemImage: "text.quote") {
                            openWindow(id: "floating-lyrics")
                        }
                        Button("一起听", systemImage: "person.2.wave.2") {
                            model.ui.sheet = .listenTogether
                        }
                        if model.settings.beatNetDebugEnabled {
                            Divider()
                            Button(
                                "BeatNet 调试",
                                systemImage: "waveform.path.ecg"
                            ) {
                                model.ui.sheet = .beatNetDebug
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 28, height: 28)
                        .contentShape(.circle)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .tint(.white)
                .foregroundStyle(.white)
                .modifier(DesktopNowPlayingCircularGlass())
            }
            .padding(.top, layout.metadataTopInset)

            DesktopNowPlayingProgress(
                tint: artworkInfluencedForeground,
                isActive: isActive
            )
                .padding(.top, 23)

            DesktopPlaybackControls(
                prominent: true,
                tint: .white,
                prominentWidth: layout.playerWidth
            )
                .frame(maxWidth: .infinity)
                .padding(.top, 22)

            Spacer()
        }
    }
}

struct DesktopNowPlayingWindowControls: View {
    let close: () -> Void
    let openMiniPlayer: () -> Void

    var body: some View {
        surfacedContent
    }

    @ViewBuilder
    private var surfacedContent: some View {
        content.modifier(DesktopNowPlayingGlassCapsule())
    }

    private var content: some View {
        HStack(spacing: 0) {
            Button(action: close) {
                Label("退出播放器", systemImage: "xmark")
                    .labelStyle(.iconOnly)
                    .frame(width: 36, height: 36)
                    .contentShape(.rect)
            }
            .accessibilityLabel("退出播放器")
            Button(action: openMiniPlayer) {
                Label("打开迷你播放器", systemImage: "pip.exit")
                    .labelStyle(.iconOnly)
                    .frame(width: 36, height: 36)
                    .contentShape(.rect)
            }
            .accessibilityLabel("打开迷你播放器")
            .help("打开迷你播放器")
        }
        .buttonStyle(.plain)
        .font(.system(size: 17, weight: .medium))
        .foregroundStyle(.white)
    }
}

struct DesktopNowPlayingVolumeControl: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        if model.playbackVolume.isControlVisible {
            surfacedContent
        }
    }

    @ViewBuilder
    private var surfacedContent: some View {
        content.modifier(DesktopNowPlayingGlassCapsule())
    }

    private var content: some View {
        HStack(spacing: 10) {
            indicatedVolumeSlider

            Button {
                model.playbackVolume.toggleMuted(minimumRestoreVolume: 0.2)
            } label: {
                Label(
                    currentVolume > 0.001 ? "静音" : "取消静音",
                    systemImage: volumeSymbol
                )
                    .labelStyle(.iconOnly)
                    .font(.system(size: 17, weight: .semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(currentVolume > 0.001 ? "静音" : "取消静音")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .frame(height: 36)
    }

    @ViewBuilder
    private var indicatedVolumeSlider: some View {
        if #available(macOS 26.0, *) {
            volumeSlider
                .sliderThumbVisibility(.visible)
        } else {
            volumeSlider
        }
    }

    private var volumeSlider: some View {
        Slider(
            value: volumeBinding,
            in: 0...1
        )
        .tint(.white)
        .controlSize(.mini)
        .frame(width: 120, height: 24)
        .contentShape(.rect)
        .accessibilityLabel("音量")
    }

    private var volumeBinding: Binding<Double> {
        Binding(
            get: { currentVolume },
            set: { model.playbackVolume.setVolume($0) }
        )
    }

    private var currentVolume: Double {
        model.playbackVolume.volume
    }

    private var volumeSymbol: String {
        switch currentVolume {
        case ...0.001: "speaker.slash.fill"
        case ..<0.35: "speaker.wave.1.fill"
        case ..<0.7: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
    }
}

private struct DesktopNowPlayingPageSwitcher: View {
    @Binding var page: DesktopInspector?

    var body: some View {
        surfacedContent
    }

    @ViewBuilder
    private var surfacedContent: some View {
        content.modifier(DesktopNowPlayingGlassCapsule())
    }

    private var content: some View {
        HStack(spacing: 0) {
            switchButton(.lyrics, systemImage: "quote.bubble")
            switchButton(.queue, systemImage: "list.bullet")
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
    }

    private func switchButton(
        _ destination: DesktopInspector,
        systemImage: String
    ) -> some View {
        Button {
            withAnimation(.snappy(duration: 0.28, extraBounce: 0.08)) {
                page = page == destination ? nil : destination
            }
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 32, height: 32)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(
            page == destination
                ? .black.opacity(0.78)
                : .white
        )
        .accessibilityLabel(
            destination == .lyrics ? "显示歌词" : "显示播放列表"
        )
        .accessibilityValue(page == destination ? "已选择" : "未选择")
        .background(
            page == destination ? .white.opacity(0.88) : .clear,
            in: .circle
        )
    }
}

private struct DesktopNowPlayingGlassCapsule: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content.glassEffect(
                .clear.interactive(),
                in: .capsule
            )
        } else {
            content
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.32), lineWidth: 0.75)
                        .allowsHitTesting(false)
                }
        }
    }
}

private struct DesktopNowPlayingCircularGlass: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(width: 28, height: 28)
            .foregroundStyle(.white)
            .background(.white.opacity(0.12), in: .circle)
            .overlay {
                Circle()
                    .stroke(.white.opacity(0.10), lineWidth: 0.5)
            }
            .contentShape(.circle)
    }
}
