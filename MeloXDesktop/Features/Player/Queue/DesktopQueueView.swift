import SwiftUI

struct DesktopQueueView: View {
    @Environment(DesktopAppModel.self) private var model
    var presentation: DesktopQueuePresentation = .inspector

    private let continueHeaderID = "apple-music-continue-header"

    private var metrics: DesktopQueueMetrics {
        DesktopQueueMetrics(presentation: presentation)
    }

    private var historyEntries: [DesktopQueueEntry] {
        model.player.historyQueueEntries.map {
            DesktopQueueEntry(
                section: .history,
                queueIndex: $0.queueIndex,
                song: $0.song
            )
        }
    }

    private var upcomingEntries: [DesktopQueueEntry] {
        model.player.upcomingQueueEntries.map {
            DesktopQueueEntry(
                section: .upcoming,
                queueIndex: $0.queueIndex,
                song: $0.song
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            modeControlRow
                .padding(.horizontal, metrics.modeHorizontalPadding)
                .padding(.top, metrics.modeTopPadding)

            queueList
                .padding(.bottom, metrics.bottomInset)
        }
    }

    private var queueList: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                List {
                    if !historyEntries.isEmpty {
                        Section {
                            queueRows(historyEntries)
                        } header: {
                            queueHeader(
                                title: "历史记录",
                                actionTitle: "清除",
                                isActionDisabled: historyEntries.count <= 1,
                                action: {
                                    model.player.clearPlaybackHistory()
                                }
                            )
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    }

                    Section {
                        if upcomingEntries.isEmpty {
                            Text("队列中无音乐。")
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(.secondary)
                                .frame(
                                    maxWidth: .infinity,
                                    minHeight: max(
                                        geometry.size.height
                                            - metrics.headerHeight,
                                        55
                                    )
                                )
                                .listRowInsets(EdgeInsets())
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                        } else {
                            queueRows(upcomingEntries)
                        }
                    } header: {
                        queueHeader(
                            title: "继续播放",
                            actionTitle: "清除",
                            isActionDisabled: upcomingEntries.isEmpty,
                            action: {
                                model.player.clearUpcomingQueue()
                            }
                        )
                        .id(continueHeaderID)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .mask(alignment: .top) {
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
                .task(id: initialScrollRequestID) {
                    await Task.yield()
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(continueHeaderID, anchor: .top)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func queueRows(
        _ entries: [DesktopQueueEntry]
    ) -> some View {
        ForEach(entries) { entry in
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
    }

    private func queueHeader(
        title: String,
        actionTitle: String,
        isActionDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
            Spacer()
            Button(actionTitle, action: action)
                .buttonStyle(.plain)
                .font(metrics.clearFont)
                .foregroundStyle(.red)
                .disabled(isActionDisabled)
        }
        .padding(.horizontal, metrics.headerHorizontalPadding)
        .frame(height: metrics.headerHeight)
        .textCase(nil)
    }

    private var modeControlRow: some View {
        HStack(spacing: metrics.modeSpacing) {
            modeButton(
                "自动连播",
                iconWeight: .semibold,
                isSelected: model.player.isAutoplayEnabled
            ) {
                model.player.toggleAutoplay()
            }
            modeButton(
                "自动过渡",
                iconWeight: .black,
                isSelected: model.player.isAutoMixEnabled
            ) {
                model.player.setAutoMixEnabled(
                    !model.player.isAutoMixEnabled
                )
            }
        }
    }

    private func modeButton(
        _ title: String,
        iconWeight: Font.Weight,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: "infinity")
                .font(.system(size: 16, weight: iconWeight))
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
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "已开启" : "已关闭")
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    private func modeForeground(isSelected: Bool) -> Color {
        guard metrics.usesProminentSelection else { return .primary }
        return isSelected ? .white : .primary.opacity(0.88)
    }

    private func modeBackground(isSelected: Bool) -> Color {
        guard metrics.usesProminentSelection else {
            return .primary.opacity(isSelected ? 0.15 : 0.07)
        }
        return isSelected ? .red : .primary.opacity(0.10)
    }

    private var rowSeparatorColor: Color {
        switch presentation {
        case .nowPlaying:
            .white.opacity(0.13)
        case .inspector, .miniPlayer:
            .primary.opacity(0.10)
        }
    }

    private var initialScrollRequestID: String {
        "\(presentation)-\(model.player.currentSong?.id ?? 0)"
    }
}
