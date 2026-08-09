import AppKit
import SwiftUI

/// Places the now-playing volume control in the titlebar's native right slot.
///
/// Toolbar placements are relative to SwiftUI's sidebar tracking separator and
/// can move to the leading side when that separator changes. A right titlebar
/// accessory has an explicit trailing anchor and is independent of the sidebar.
struct DesktopNowPlayingTrailingAccessoryInstaller: NSViewRepresentable {
    let isPresented: Bool
    let model: DesktopAppModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeNSView(context: Context) -> DesktopNowPlayingTrailingAccessoryProbe {
        let probe = DesktopNowPlayingTrailingAccessoryProbe()
        probe.windowDidChange = { [weak coordinator = context.coordinator] window in
            coordinator?.attach(to: window)
        }
        context.coordinator.update(
            isPresented: isPresented,
            model: model
        )
        return probe
    }

    func updateNSView(
        _ nsView: DesktopNowPlayingTrailingAccessoryProbe,
        context: Context
    ) {
        context.coordinator.update(
            isPresented: isPresented,
            model: model
        )
        context.coordinator.attach(to: nsView.window)
    }

    static func dismantleNSView(
        _ nsView: DesktopNowPlayingTrailingAccessoryProbe,
        coordinator: Coordinator
    ) {
        nsView.windowDidChange = nil
        coordinator.detach()
    }

    @MainActor
    final class Coordinator {
        private weak var installedWindow: NSWindow?
        private var isPresented = false
        private let accessoryController: NSTitlebarAccessoryViewController
        private let hostingView:
            NSHostingView<DesktopNowPlayingTrailingAccessoryContent>

        init(model: DesktopAppModel) {
            hostingView = NSHostingView(
                rootView: DesktopNowPlayingTrailingAccessoryContent(
                    model: model
                )
            )
            hostingView.frame = NSRect(x: 0, y: 0, width: 186, height: 36)

            accessoryController = NSTitlebarAccessoryViewController()
            accessoryController.layoutAttribute = .right
            accessoryController.view = hostingView
        }

        func update(
            isPresented: Bool,
            model: DesktopAppModel
        ) {
            self.isPresented = isPresented
            hostingView.rootView = DesktopNowPlayingTrailingAccessoryContent(
                model: model
            )
            reconcileInstallation()
        }

        func attach(to window: NSWindow?) {
            guard installedWindow !== window else {
                reconcileInstallation()
                return
            }

            detach()
            installedWindow = window
            reconcileInstallation()
        }

        func detach() {
            accessoryController.removeFromParent()
            installedWindow = nil
        }

        private func reconcileInstallation() {
            guard let window = installedWindow else { return }

            let isInstalled = window.titlebarAccessoryViewControllers
                .contains { $0 === accessoryController }
            if isPresented, !isInstalled {
                window.addTitlebarAccessoryViewController(accessoryController)
            } else if !isPresented, isInstalled {
                accessoryController.removeFromParent()
            }
        }
    }
}

final class DesktopNowPlayingTrailingAccessoryProbe: NSView {
    var windowDidChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        windowDidChange?(window)
    }
}

private struct DesktopNowPlayingTrailingAccessoryContent: View {
    let model: DesktopAppModel

    var body: some View {
        DesktopNowPlayingVolumeControl()
            .frame(width: 176, height: 36)
            .padding(.trailing, 10)
            .environment(model)
            .transaction { transaction in
                transaction.animation = nil
            }
    }
}
