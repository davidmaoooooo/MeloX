import SwiftUI
import UIKit

private struct ClipboardListenTogetherInvitation: Identifiable {
    let invitationText: String
    let roomID: String

    var id: String { roomID }
}

private enum ClipboardLinkOpenError: LocalizedError {
    case songNotFound

    var errorDescription: String? {
        switch self {
        case .songNotFound:
            "网易云音乐没有返回这首歌曲的信息。"
        }
    }
}

struct ClipboardLinkRecognitionModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var settings
    @Environment(NeteaseAPI.self) private var api

    let onOpenSong: (Song) -> Void

    @State private var hasInspectedClipboardOnLaunch = false
    @State private var detectedLink: NeteaseClipboardLink?
    @State private var listenTogetherInvitation:
        ClipboardListenTogetherInvitation?
    @State private var isOpeningSong = false
    @State private var errorMessage: String?

    func body(content: Content) -> some View {
        content
            .task {
                inspectClipboardOnLaunchIfNeeded()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                inspectClipboardOnLaunchIfNeeded()
            }
            .alert(
                detectedLink?.promptTitle ?? "剪贴板链接",
                isPresented: detectedLinkPresented
            ) {
                if let link = detectedLink {
                    Button(link.actionTitle) {
                        open(link)
                    }
                }
                Button("忽略", role: .cancel) {}
            } message: {
                Text(
                    detectedLink?.promptMessage
                        ?? "是否在 MeloX 中打开此链接？"
                )
            }
            .sheet(item: $listenTogetherInvitation) { invitation in
                ListenTogetherView(
                    invitationText: invitation.invitationText
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .alert(
                "无法打开剪贴板链接",
                isPresented: errorPresented
            ) {
                Button("好", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "请稍后重试。")
            }
            .overlay {
                if isOpeningSong {
                    ProgressView("正在打开歌曲…")
                        .padding()
                        .background(
                            .regularMaterial,
                            in: .rect(cornerRadius: 14)
                        )
                        .accessibilityLabel("正在打开剪贴板中的歌曲")
                }
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

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    errorMessage = nil
                }
            }
        )
    }

    private func inspectClipboardOnLaunchIfNeeded() {
        guard !hasInspectedClipboardOnLaunch,
              scenePhase == .active else {
            return
        }
        hasInspectedClipboardOnLaunch = true

        guard settings.recognizesClipboardLinksOnLaunch,
              let text = UIPasteboard.general.string,
              let link = NeteaseClipboardLinkParser.parse(text) else {
            return
        }
        detectedLink = link
    }

    private func open(_ link: NeteaseClipboardLink) {
        switch link {
        case .song(let id):
            openSong(id: id)
        case .listenTogether(let invitationText, let roomID):
            listenTogetherInvitation = ClipboardListenTogetherInvitation(
                invitationText: invitationText,
                roomID: roomID
            )
        }
    }

    private func openSong(id: Int) {
        guard !isOpeningSong else { return }
        isOpeningSong = true

        Task {
            defer { isOpeningSong = false }
            do {
                let songs = try await api.songDetails(ids: [id])
                try Task.checkCancellation()
                guard let song = songs.first else {
                    throw ClipboardLinkOpenError.songNotFound
                }
                onOpenSong(song)
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private extension NeteaseClipboardLink {
    var promptTitle: String {
        switch self {
        case .song:
            "发现网易云歌曲链接"
        case .listenTogether:
            "发现一起听邀请"
        }
    }

    var promptMessage: String {
        switch self {
        case .song:
            "是否在 MeloX 中打开剪贴板里的歌曲？"
        case .listenTogether:
            "是否查看剪贴板里的一起听邀请？加入前仍可核对邀请链接。"
        }
    }

    var actionTitle: String {
        switch self {
        case .song:
            "打开歌曲"
        case .listenTogether:
            "查看邀请"
        }
    }
}

extension View {
    func recognizesClipboardLinksOnLaunch(
        onOpenSong: @escaping (Song) -> Void
    ) -> some View {
        modifier(
            ClipboardLinkRecognitionModifier(
                onOpenSong: onOpenSong
            )
        )
    }
}
