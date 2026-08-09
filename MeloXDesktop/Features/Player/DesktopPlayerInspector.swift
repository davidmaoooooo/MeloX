import SwiftUI

struct DesktopPlayerInspector: View {
    let kind: DesktopInspector
    var isActive = true

    var body: some View {
        inspectorContent
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var inspectorContent: some View {
        switch kind {
        case .lyrics:
            DesktopPlaybackPositionedLyricsView(
                compact: true,
                allowsLyricBlur: false,
                isActive: isActive
            )
        case .queue:
            DesktopQueueView(presentation: .inspector)
        }
    }
}

enum DesktopQueuePresentation {
    case inspector
    case nowPlaying
    case miniPlayer
}

private struct DesktopQueueMetrics {
    let modeHorizontalPadding: CGFloat
    let headerHorizontalPadding: CGFloat
    let dividerHorizontalPadding: CGFloat
    let rowLeadingInset: CGFloat
    let rowTrailingInset: CGFloat
    let modeSpacing: CGFloat
    let modeTopPadding: CGFloat
    let modeBottomPadding: CGFloat
    let modeHeight: CGFloat
    let modeFont: Font
    let headerSpacing: CGFloat
    let headerTitleFont: Font
    let headerSubtitleFont: Font
    let headerBottomPadding: CGFloat
    let listTopPadding: CGFloat
    let artworkSize: CGFloat
    let rowOuterSpacing: CGFloat
    let rowContentSpacing: CGFloat
    let rowVerticalInset: CGFloat
    let rowTitleFont: Font
    let rowSubtitleFont: Font
    let menuSize: CGFloat
    let clearFont: Font
    let bottomFadeHeight: CGFloat
    let showsHeaderDivider: Bool
    let usesProminentSelection: Bool

    init(presentation: DesktopQueuePresentation) {
        switch presentation {
        case .nowPlaying:
            modeHorizontalPadding = 20
            headerHorizontalPadding = 32
            dividerHorizontalPadding = 0
            rowLeadingInset = 16
            rowTrailingInset = 16
            modeSpacing = 12
            modeTopPadding = 0
            modeBottomPadding = 12
            modeHeight = 36
            modeFont = .system(size: 14, weight: .semibold)
            headerSpacing = 3
            headerTitleFont = .system(size: 15, weight: .bold)
            headerSubtitleFont = .system(size: 13, weight: .regular)
            headerBottomPadding = 8
            listTopPadding = 0
            artworkSize = 34
            rowOuterSpacing = 12
            rowContentSpacing = 12
            rowVerticalInset = 7
            rowTitleFont = .system(size: 14, weight: .regular)
            rowSubtitleFont = .system(size: 12, weight: .regular)
            menuSize = 28
            clearFont = .system(size: 14, weight: .medium)
            bottomFadeHeight = 72
            showsHeaderDivider = true
            usesProminentSelection = true
        case .inspector, .miniPlayer:
            let horizontalPadding: CGFloat =
                presentation == .miniPlayer ? 12 : 14
            modeHorizontalPadding = horizontalPadding
            headerHorizontalPadding = horizontalPadding
            dividerHorizontalPadding = horizontalPadding
            rowLeadingInset = horizontalPadding
            rowTrailingInset = horizontalPadding - 4
            modeSpacing = 10
            modeTopPadding = presentation == .inspector ? 8 : 14
            modeBottomPadding = 12
            modeHeight = 32
            modeFont = .system(size: 12, weight: .medium)
            headerSpacing = 2
            headerTitleFont = .headline
            headerSubtitleFont = .caption
            headerBottomPadding = 10
            listTopPadding = 0
            artworkSize = 38
            rowOuterSpacing = 8
            rowContentSpacing = 10
            rowVerticalInset = 3
            rowTitleFont = .body
            rowSubtitleFont = .caption
            menuSize = 24
            clearFont = .body
            bottomFadeHeight = 48
            showsHeaderDivider = false
            usesProminentSelection = false
        }
    }
}

private struct DesktopQueueEntry: Identifiable {
    let queueIndex: Int
    let song: Song

    var id: Int { queueIndex }
}

struct DesktopQueueView: View {
    @Environment(DesktopAppModel.self) private var model
    var presentation: DesktopQueuePresentation = .inspector

    private var metrics: DesktopQueueMetrics {
        DesktopQueueMetrics(presentation: presentation)
    }

    private var entries: [DesktopQueueEntry] {
        model.player.upcomingQueueEntries.map {
            DesktopQueueEntry(queueIndex: $0.queueIndex, song: $0.song)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: metrics.modeSpacing) {
                modeButton(
                    "自动连播",
                    systemImage: "infinity",
                    iconWeight: .semibold,
                    isSelected: model.player.isAutoplayEnabled
                ) {
                    model.player.toggleAutoplay()
                }
                modeButton(
                    "自动过渡",
                    systemImage: "infinity",
                    iconWeight: .black,
                    isSelected: model.player.isAutoMixEnabled
                ) {
                    model.player.setAutoMixEnabled(
                        !model.player.isAutoMixEnabled
                    )
                }
            }
            .padding(.horizontal, metrics.modeHorizontalPadding)
            .padding(.top, metrics.modeTopPadding)
            .padding(.bottom, metrics.modeBottomPadding)

            HStack {
                VStack(alignment: .leading, spacing: metrics.headerSpacing) {
                    Text("继续播放")
                        .font(metrics.headerTitleFont)
                    Text("来自：\(model.player.currentSong?.album?.name ?? "当前播放队列")")
                        .font(metrics.headerSubtitleFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Button("清除") { model.player.clearUpcomingQueue() }
                    .buttonStyle(.plain)
                    .font(metrics.clearFont)
                    .foregroundStyle(.red)
            }
            .padding(.horizontal, metrics.headerHorizontalPadding)
            .padding(.bottom, metrics.headerBottomPadding)

            if metrics.showsHeaderDivider {
                Divider()
                    .padding(
                        .horizontal,
                        metrics.dividerHorizontalPadding
                    )
            }

            List(entries) { entry in
                DesktopQueueRow(
                    entry: entry,
                    presentation: presentation,
                    metrics: metrics
                )
                .listRowInsets(
                    EdgeInsets(
                        top: metrics.rowVerticalInset,
                        leading: metrics.rowLeadingInset,
                        bottom: metrics.rowVerticalInset,
                        trailing: metrics.rowTrailingInset
                    )
                )
                .listRowBackground(Color.clear)
                .listRowSeparatorTint(rowSeparatorColor)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.top, metrics.listTopPadding)
            .mask {
                VStack(spacing: 0) {
                    Color.black
                    LinearGradient(
                        colors: [.black, .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: metrics.bottomFadeHeight)
                }
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "队列已播放完",
                        systemImage: "text.line.last.and.arrowtriangle.forward"
                    )
                }
            }
        }
    }

    private func modeButton(
        _ title: String,
        systemImage: String,
        iconWeight: Font.Weight,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(
                        .system(
                            size: 16,
                            weight: iconWeight
                        )
                    )
                Text(title)
                    .font(metrics.modeFont)
            }
            .foregroundStyle(modeForeground(isSelected: isSelected))
            .frame(maxWidth: .infinity)
            .frame(height: metrics.modeHeight)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .background(
            modeBackground(isSelected: isSelected),
            in: .capsule
        )
        .overlay {
            Capsule()
                .stroke(.primary.opacity(0.07), lineWidth: 0.5)
        }
        .accessibilityValue(isSelected ? "已开启" : "已关闭")
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    private func modeForeground(isSelected: Bool) -> Color {
        guard metrics.usesProminentSelection else { return .primary }
        return isSelected
            ? .black.opacity(0.78)
            : .white.opacity(0.88)
    }

    private func modeBackground(isSelected: Bool) -> Color {
        guard metrics.usesProminentSelection else {
            return .primary.opacity(isSelected ? 0.15 : 0.07)
        }
        return .white.opacity(isSelected ? 0.88 : 0.10)
    }

    private var rowSeparatorColor: Color {
        switch presentation {
        case .nowPlaying:
            .white.opacity(0.13)
        case .inspector, .miniPlayer:
            .primary.opacity(0.10)
        }
    }
}

private struct DesktopQueueRow: View {
    @Environment(DesktopAppModel.self) private var model

    let entry: DesktopQueueEntry
    let presentation: DesktopQueuePresentation
    let metrics: DesktopQueueMetrics

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: metrics.rowOuterSpacing) {
            Button {
                playEntry()
            } label: {
                HStack(spacing: metrics.rowContentSpacing) {
                    DesktopArtworkView(
                        url: entry.song.album?.artworkURL,
                        cornerRadius: 5
                    )
                    .frame(
                        width: metrics.artworkSize,
                        height: metrics.artworkSize
                    )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.song.name)
                            .font(metrics.rowTitleFont)
                            .lineLimit(1)
                        Text(
                            [
                                entry.song.artistText,
                                entry.song.album?.name,
                            ]
                            .compactMap { $0 }
                            .joined(separator: " — ")
                        )
                        .font(metrics.rowSubtitleFont)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    }

                    Spacer()
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            Menu {
                Button("立即播放", systemImage: "play.fill") {
                    playEntry()
                }
                Button(
                    "从队列中移除",
                    systemImage: "minus.circle",
                    role: .destructive
                ) {
                    model.player.removeFromPlaybackQueue(
                        at: entry.queueIndex
                    )
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(menuColor)
                    .frame(
                        width: metrics.menuSize,
                        height: metrics.menuSize
                    )
                    .contentShape(.rect)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .tint(menuColor)
        }
        .onHover { isHovered = $0 }
    }

    private var menuColor: Color {
        switch presentation {
        case .nowPlaying:
            isHovered ? .red : .white.opacity(0.68)
        case .inspector, .miniPlayer:
            .primary
        }
    }

    private func playEntry() {
        Task {
            await model.player.playFromQueue(
                at: entry.queueIndex
            )
        }
    }
}
