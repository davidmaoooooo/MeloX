import SwiftUI

/// A resident trailing overlay whose real pages stay mounted. Keeping both page
/// trees alive preserves lyrics and queue state while their visibility fades.
struct DesktopPlayerSidePanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var renderingSelection: DesktopInspector?

    let selection: DesktopInspector
    let isPresented: Bool

    var body: some View {
        surfacedPanel
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.container, edges: .top)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(selection.accessibilityTitle)
            .task(id: renderingRequest) {
                await updateRenderingSelection()
            }
    }

    @ViewBuilder
    private var surfacedPanel: some View {
        if #available(macOS 26.0, *) {
            crossfadingContent
                .background {
                    Color.clear
                        .glassEffect(
                            .regular,
                            in: .rect(cornerRadius: 0)
                        )
                }
        } else {
            crossfadingContent
                .background {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
        }
    }

    private var crossfadingContent: some View {
        ZStack {
            ForEach(DesktopInspector.allCases) { inspector in
                let isSelected = selection == inspector

                DesktopPlayerInspector(
                    kind: inspector,
                    isActive: renderingSelection == inspector
                )
                .opacity(isSelected ? 1 : 0)
                .allowsHitTesting(isSelected)
                .accessibilityHidden(!isSelected)
                .zIndex(isSelected ? 1 : 0)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(
            reduceMotion
                ? nil
                : DesktopMainWindowMetrics.presentationAnimation,
            value: selection
        )
        .clipped()
    }

    private var renderingRequest: RenderingRequest {
        RenderingRequest(
            selection: selection,
            isPresented: isPresented
        )
    }

    private func updateRenderingSelection() async {
        guard isPresented else {
            commitRenderingSelection(nil)
            return
        }

        if renderingSelection != nil {
            commitRenderingSelection(selection)
            return
        }

        if reduceMotion {
            await Task.yield()
        } else {
            do {
                try await Task.sleep(
                    for: .seconds(
                        DesktopMainWindowMetrics.presentationDuration
                    )
                )
            } catch {
                return
            }
        }
        guard !Task.isCancelled else { return }
        commitRenderingSelection(selection)
    }

    private func commitRenderingSelection(
        _ selection: DesktopInspector?
    ) {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            renderingSelection = selection
        }
    }
}

private struct RenderingRequest: Hashable {
    let selection: DesktopInspector
    let isPresented: Bool
}

private extension DesktopInspector {
    var accessibilityTitle: String {
        switch self {
        case .lyrics:
            "歌词"
        case .queue:
            "播放列表"
        }
    }
}
