import AppKit
import SwiftUI

enum DesktopMainWindowMetrics {
    static let minimumContentWidth: CGFloat = 980
    static let minimumContentHeight: CGFloat = 540
    static let playerSidePanelWidth: CGFloat = 360
    static let presentationDuration: TimeInterval = 0.28
    static let presentationAnimation: Animation = .easeInOut(
        duration: presentationDuration
    )

    static func minimumContentWidth(
        isPlayerSidePanelPresented: Bool
    ) -> CGFloat {
        minimumContentWidth
            + (isPlayerSidePanelPresented ? playerSidePanelWidth : 0)
    }
}

/// Keeps the main page width stable while the player side panel is presented.
///
/// SwiftUI's inspector consumes space inside the current window. Apple Music
/// instead grows its window first, then presents the panel in the newly added
/// trailing area. The probe below only coordinates the native window frame;
/// the panel and its background remain entirely SwiftUI-owned.
struct DesktopMainWindowConfiguration: NSViewRepresentable {
    let isPlayerSidePanelPresented: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> DesktopMainWindowProbe {
        let probe = DesktopMainWindowProbe()
        probe.windowDidChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        context.coordinator.update(
            isPlayerSidePanelPresented: isPlayerSidePanelPresented
        )
        return probe
    }

    func updateNSView(
        _ nsView: DesktopMainWindowProbe,
        context: Context
    ) {
        context.coordinator.update(
            isPlayerSidePanelPresented: isPlayerSidePanelPresented
        )
        context.coordinator.attach(to: nsView.window)
    }

    static func dismantleNSView(
        _ nsView: DesktopMainWindowProbe,
        coordinator: Coordinator
    ) {
        nsView.windowDidChange = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private weak var installedWindow: NSWindow?
        private var requestedPresentation = false
        private var appliedPresentation = false
        private var presentationFrameAdjustment: FrameAdjustment?

        func update(
            isPlayerSidePanelPresented: Bool
        ) {
            requestedPresentation = isPlayerSidePanelPresented
            applyPresentationChangeIfNeeded()
        }

        func attach(to window: NSWindow?) {
            guard installedWindow !== window else {
                applyMinimumContentSize()
                return
            }

            installedWindow = window
            appliedPresentation = false
            presentationFrameAdjustment = nil
            applyPresentationChangeIfNeeded()
            applyMinimumContentSize()
        }

        func detach() {
            installedWindow = nil
            appliedPresentation = false
            presentationFrameAdjustment = nil
        }

        private func applyPresentationChangeIfNeeded() {
            guard let window = installedWindow else { return }
            guard appliedPresentation != requestedPresentation else {
                if !requestedPresentation {
                    contractIfNeeded(window)
                }
                applyMinimumContentSize()
                return
            }

            if requestedPresentation {
                expandIfNeeded(window)
            } else if appliedPresentation {
                // Release the expanded minimum before removing the width
                // that was added for the panel.
                applyMinimumContentSize()
                contractIfNeeded(window)
            }
            appliedPresentation = requestedPresentation
            applyMinimumContentSize()
        }

        private func expandIfNeeded(_ window: NSWindow) {
            let initialFrame = window.frame

            guard !window.styleMask.contains(.fullScreen) else { return }

            var targetFrame = initialFrame
            let requestedWidth = initialFrame.width
                + DesktopMainWindowMetrics.playerSidePanelWidth

            if let visibleFrame = window.screen?.visibleFrame {
                targetFrame.size.width = min(
                    requestedWidth,
                    max(initialFrame.width, visibleFrame.width)
                )

                if targetFrame.maxX > visibleFrame.maxX {
                    targetFrame.origin.x -= targetFrame.maxX
                        - visibleFrame.maxX
                }
                targetFrame.origin.x = max(
                    targetFrame.origin.x,
                    visibleFrame.minX
                )
            } else {
                targetFrame.size.width = requestedWidth
            }

            setFrame(targetFrame, on: window)
            presentationFrameAdjustment = FrameAdjustment(
                originX: targetFrame.origin.x - initialFrame.origin.x,
                width: targetFrame.width - initialFrame.width
            )
        }

        private func contractIfNeeded(_ window: NSWindow) {
            guard let adjustment = presentationFrameAdjustment else { return }
            guard !window.styleMask.contains(.fullScreen) else { return }

            var targetFrame = window.frame
            targetFrame.origin.x -= adjustment.originX
            targetFrame.size.width -= adjustment.width

            let minimumContentRect = NSRect(
                origin: .zero,
                size: NSSize(
                    width: DesktopMainWindowMetrics.minimumContentWidth,
                    height: DesktopMainWindowMetrics.minimumContentHeight
                )
            )
            let minimumFrameWidth = window.frameRect(
                forContentRect: minimumContentRect
            ).width
            targetFrame.size.width = max(
                targetFrame.width,
                minimumFrameWidth
            )

            setFrame(targetFrame, on: window)
            presentationFrameAdjustment = nil
        }

        private func applyMinimumContentSize() {
            guard let window = installedWindow else { return }

            let requestedWidth = DesktopMainWindowMetrics.minimumContentWidth(
                isPlayerSidePanelPresented: requestedPresentation
            )
            let availableWidth = window.screen.map { screen in
                window.contentRect(forFrameRect: screen.visibleFrame).width
            }
            let minimumWidth = min(
                requestedWidth,
                max(
                    DesktopMainWindowMetrics.minimumContentWidth,
                    availableWidth ?? requestedWidth
                )
            )

            window.contentMinSize = NSSize(
                width: minimumWidth,
                height: DesktopMainWindowMetrics.minimumContentHeight
            )
        }

        private func setFrame(_ frame: NSRect, on window: NSWindow) {
            guard frame != window.frame else { return }
            // Animating NSWindow's frame forces the complete SwiftUI tree to
            // relayout on every animation tick. Apply the native window size
            // once, then let only the lightweight side panel animate.
            window.setFrame(frame, display: true)
        }

        private struct FrameAdjustment {
            let originX: CGFloat
            let width: CGFloat
        }
    }
}

final class DesktopMainWindowProbe: NSView {
    var windowDidChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowDidChange?(window)
    }
}
