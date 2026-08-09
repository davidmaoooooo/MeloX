import AppKit
import SwiftUI

extension View {
    func desktopLaunchExperience() -> some View {
        modifier(DesktopLaunchExperienceModifier())
    }
}

private struct DesktopLaunchExperienceModifier: ViewModifier {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @Environment(DesktopAppModel.self) private var model

    @State private var hasInspectedClipboard = false
    @State private var hasCheckedForUpdates = false
    @State private var detectedLink: NeteaseMusicLink?
    @State private var updateAlert: DesktopAutomaticUpdateAlert?

    func body(content: Content) -> some View {
        content
            .task {
                inspectClipboardIfNeeded()
                await checkForUpdatesIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                inspectClipboardIfNeeded()
            }
            .alert(
                detectedLink?.promptTitle ?? "剪贴板链接",
                isPresented: detectedLinkPresented
            ) {
                if let detectedLink {
                    Button(detectedLink.actionTitle) {
                        open(detectedLink)
                    }
                }
                Button("忽略", role: .cancel) {}
            } message: {
                Text(
                    detectedLink?.promptMessage
                        ?? "是否在 MeloX 中打开此链接？"
                )
            }
            .alert(item: $updateAlert) { alert in
                Alert(
                    title: Text("发现新版本"),
                    message: Text(alert.message),
                    primaryButton: .default(Text("打开发布页")) {
                        openURL(alert.releaseURL)
                    },
                    secondaryButton: .cancel(Text("稍后"))
                )
            }
    }

    private var detectedLinkPresented: Binding<Bool> {
        Binding(
            get: { detectedLink != nil },
            set: { isPresented in
                if !isPresented {
                    detectedLink = nil
                }
            }
        )
    }

    private func inspectClipboardIfNeeded() {
        guard !hasInspectedClipboard,
              scenePhase == .active else {
            return
        }
        hasInspectedClipboard = true

        guard model.settings.recognizesClipboardLinksOnLaunch,
              let text = NSPasteboard.general.string(forType: .string),
              let link = NeteaseMusicLinkParser.parse(text) else {
            return
        }
        detectedLink = link
    }

    private func open(_ link: NeteaseMusicLink) {
        switch link {
        case .song(let id):
            model.ui.isNowPlayingPresented = false
            model.ui.navigate(to: .song(id))
        case .listenTogether(let invitation):
            model.ui.sheet = .listenTogetherInvitation(invitation)
        }
    }

    private func checkForUpdatesIfNeeded() async {
        guard !hasCheckedForUpdates,
              model.settings.checksUpdatesOnLaunch else {
            return
        }
        hasCheckedForUpdates = true

        do {
            let result = try await AppUpdateService.checkLatestRelease(
                currentVersion: Bundle.main.appReleaseVersion
            )
            guard result.hasUpdate else { return }
            updateAlert = DesktopAutomaticUpdateAlert(
                message:
                    "当前版本 \(result.currentVersion)，最新版本 \(result.latestVersion)。可以前往发布页查看更新内容。",
                releaseURL: result.releaseURL
            )
        } catch {
            // Automatic checks should never block launching the player.
        }
    }
}

private struct DesktopAutomaticUpdateAlert: Identifiable {
    let id = UUID()
    let message: String
    let releaseURL: URL
}

private extension NeteaseMusicLink {
    var promptTitle: String {
        switch self {
        case .song: "发现网易云歌曲链接"
        case .listenTogether: "发现一起听邀请"
        }
    }

    var promptMessage: String {
        switch self {
        case .song: "是否在 MeloX 中打开剪贴板里的歌曲？"
        case .listenTogether:
            "是否查看剪贴板里的一起听邀请？加入前仍可核对邀请链接。"
        }
    }

    var actionTitle: String {
        switch self {
        case .song: "打开歌曲"
        case .listenTogether: "查看邀请"
        }
    }
}
