import SwiftUI

struct DesktopRootView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isNowPlayingRenderingActive = false

    var body: some View {
        @Bindable var ui = model.ui

        ZStack {
            DesktopSidebar()

            GeometryReader { proxy in
                nowPlayingLayer(
                    isPresented: ui.isNowPlayingPresented,
                    isRenderingActive: isNowPlayingRenderingActive
                )
                    .frame(
                        width: proxy.size.width,
                        height: proxy.size.height
                    )
                    .offset(
                        y: ui.isNowPlayingPresented
                            ? 0
                            : proxy.size.height
                    )
                    .allowsHitTesting(ui.isNowPlayingPresented)
                    .accessibilityHidden(!ui.isNowPlayingPresented)
            }
            .zIndex(1)
            .animation(
                reduceMotion
                    ? nil
                    : DesktopPlayerMotion.nowPlayingPresentation,
                value: ui.isNowPlayingPresented
            )
        }
        .toolbar(removing: .sidebarToggle)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .background {
            ZStack {
                DesktopMainWindowConfiguration(
                    isPlayerSidePanelPresented: ui.inspector != nil
                )

                DesktopNowPlayingLeadingAccessoryInstaller(
                    isPresented: ui.isNowPlayingPresented,
                    close: {
                        model.ui.isNowPlayingPresented = false
                    },
                    openMiniPlayer: {
                        model.ui.isNowPlayingPresented = false
                        Task { @MainActor in
                            await Task.yield()
                            openWindow(id: "mini-player")
                            await DesktopMiniPlayerWindowCoordinator
                                .bringToFrontAfterOpening()
                        }
                    }
                )

                DesktopNowPlayingTrailingAccessoryInstaller(
                    isPresented: ui.isNowPlayingPresented,
                    model: model
                )
            }
            .allowsHitTesting(false)
        }
        .containerBackground(for: .window) {
            Color(nsColor: .windowBackgroundColor)
        }
        .tint(.red)
        .desktopLaunchExperience()
        .task { await model.bootstrap() }
        .task(id: ui.isNowPlayingPresented) {
            await updateNowPlayingRenderingActivity(
                isPresented: ui.isNowPlayingPresented
            )
        }
        .task(id: model.player.currentSong?.id) {
            await model.synchronizeLyrics()
        }
        .sheet(item: $ui.sheet) { sheet in
            DesktopSheetView(sheet: sheet)
                .environment(model)
        }
        .alert(
            "操作未完成",
            isPresented: Binding(
                get: { model.library.operationErrorMessage != nil },
                set: {
                    if !$0 {
                        model.library.clearOperationError()
                    }
                }
            )
        ) {
            Button("好") { model.library.clearOperationError() }
        } message: {
            Text(
                model.library.operationErrorMessage
                    ?? "网易云音乐未完成操作。"
            )
        }
        .alert(
            "无法启动心动模式",
            isPresented: Binding(
                get: { model.launchErrorMessage != nil },
                set: { if !$0 { model.clearLaunchError() } }
            )
        ) {
            Button("好") { model.clearLaunchError() }
        } message: {
            Text(model.launchErrorMessage ?? "请稍后重试。")
        }
        .onExitCommand {
            if ui.isNowPlayingPresented {
                ui.isNowPlayingPresented = false
            }
        }
    }

    private func nowPlayingLayer(
        isPresented: Bool,
        isRenderingActive: Bool
    ) -> some View {
        ZStack {
            DesktopNowPlayingBackdrop(
                artworkURL: model.player.currentSong?.album?.artworkURL,
                player: model.player,
                settings: model.settings,
                isActive: isRenderingActive
            )
            .ignoresSafeArea()

            DesktopNowPlayingWindow(
                isActive: isPresented,
                isRenderingActive: isRenderingActive
            )
        }
    }

    private func updateNowPlayingRenderingActivity(
        isPresented: Bool
    ) async {
        guard isPresented else {
            if !reduceMotion {
                do {
                    try await Task.sleep(
                        for: DesktopPlayerMotion.nowPlayingContentDelay
                    )
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            commitNowPlayingRenderingActivity(false)
            return
        }

        if reduceMotion {
            await Task.yield()
        } else {
            do {
                try await Task.sleep(
                    for: DesktopPlayerMotion.nowPlayingContentDelay
                )
            } catch {
                return
            }
        }
        guard !Task.isCancelled else { return }
        commitNowPlayingRenderingActivity(true)
    }

    private func commitNowPlayingRenderingActivity(_ isActive: Bool) {
        guard isNowPlayingRenderingActive != isActive else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isNowPlayingRenderingActive = isActive
        }
    }
}

struct DesktopTabPage: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let section: DesktopSection

    var body: some View {
        @Bindable var ui = model.ui
        let isInspectorPresented = ui.inspector != nil

        let pageContent = NavigationStack(path: $ui.path) {
            DesktopSectionContentView(section: section)
                .navigationDestination(for: DesktopRoute.self) { route in
                    DesktopRouteView(route: route)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar(removing: .sidebarToggle)

        ZStack(alignment: .trailing) {
            pageContent
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    DesktopGlobalBottomPlayerInset()
                }

            DesktopPlayerSidePanel(
                selection: ui.retainedInspector,
                isPresented: isInspectorPresented
            )
            .frame(
                width: DesktopMainWindowMetrics.playerSidePanelWidth
            )
            .offset(
                x: isInspectorPresented
                    ? 0
                    : DesktopMainWindowMetrics.playerSidePanelWidth
            )
            .opacity(isInspectorPresented ? 1 : 0)
            .allowsHitTesting(isInspectorPresented)
            .accessibilityHidden(!isInspectorPresented)
            .zIndex(2)
            .animation(
                reduceMotion
                    ? nil
                    : DesktopMainWindowMetrics.presentationAnimation,
                value: isInspectorPresented
            )
        }
        .anchorPreference(
            key: DesktopTabContentBoundsPreferenceKey.self,
            value: .bounds
        ) { bounds in
            [section: bounds]
        }
    }
}

struct DesktopTabContentBoundsPreferenceKey: PreferenceKey {
    static var defaultValue: [DesktopSection: Anchor<CGRect>] = [:]

    static func reduce(
        value: inout [DesktopSection: Anchor<CGRect>],
        nextValue: () -> [DesktopSection: Anchor<CGRect>]
    ) {
        value.merge(nextValue()) { _, latest in latest }
    }
}

private struct DesktopSheetView: View {
    let sheet: DesktopSheet

    var body: some View {
        switch sheet {
        case .onboarding:
            DesktopOnboardingDialog()
        case .account:
            DesktopAccountView()
        case .login:
            DesktopLoginView()
        case .recognition:
            DesktopSongRecognitionView()
        case .listenTogether:
            DesktopListenTogetherView()
        case .listenTogetherInvitation(let invitation):
            DesktopListenTogetherView(
                invitationText: invitation.invitationText
            )
        case .sleepTimer:
            DesktopSleepTimerView()
        case .beatNetDebug:
            DesktopBeatNetDebugView()
        }
    }
}

struct DesktopSectionContentView: View {
    let section: DesktopSection

    var body: some View {
        switch section {
        case .search:
            DesktopSearchView()
        case .home:
            DesktopHomeView()
        case .discovery:
            DesktopDiscoveryView()
        case .radio:
            DesktopRadioView()
        case .recent,
             .songs,
             .playlists,
             .podcasts,
             .downloads,
             .cloud:
            DesktopLibraryView(section: section)
        case .messages:
            DesktopMessagesView()
        }
    }
}
