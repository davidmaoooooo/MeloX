import SwiftUI

/// A resident trailing overlay whose real pages stay side by side. Keeping the
/// two page trees alive avoids rebuilding lyrics and queue content while the
/// window is expanding.
struct DesktopPlayerSidePanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var renderingSelection: DesktopInspector?

    let selection: DesktopInspector
    let isPresented: Bool

    var body: some View {
        surfacedPanel
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(selection.accessibilityTitle)
            .task(id: renderingRequest) {
                await updateRenderingSelection()
            }
    }

    @ViewBuilder
    private var surfacedPanel: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 0) {
                pagedContent
                    .glassEffect(
                        .regular,
                        in: .rect(cornerRadius: 0)
                    )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            pagedContent
                .background(.ultraThinMaterial)
        }
    }

    private var pagedContent: some View {
        GeometryReader { geometry in
            let pageWidth = max(geometry.size.width, 0)
            let pageHeight = max(geometry.size.height, 0)

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 0) {
                        ForEach(DesktopInspector.allCases) { inspector in
                            DesktopPlayerInspector(
                                kind: inspector,
                                isActive: renderingSelection == inspector
                            )
                            .frame(width: pageWidth, height: pageHeight)
                            .id(inspector)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollIndicators(.hidden)
                .onAppear {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(selection, anchor: .leading)
                    }
                }
                .onChange(of: selection) { _, newSelection in
                    withAnimation(
                        reduceMotion
                            ? nil
                            : DesktopMainWindowMetrics.presentationAnimation
                    ) {
                        proxy.scrollTo(newSelection, anchor: .leading)
                    }
                }
                .onChange(of: pageWidth) {
                    var transaction = Transaction(animation: nil)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        proxy.scrollTo(selection, anchor: .leading)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
    }

    private var renderingRequest: RenderingRequest {
        RenderingRequest(
            selection: selection,
            isPresented: isPresented
        )
    }

    private func updateRenderingSelection() async {
        commitRenderingSelection(nil)
        guard isPresented else { return }

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
