import SwiftUI

struct ListenTogetherAppCoordinationModifier: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player
    @Environment(ListenTogetherStore.self) private var listenTogether

    func body(content: Content) -> some View {
        content
            .task(id: settings.cookie) {
                await listenTogether.accountDidChange(
                    hasCredentials: hasCredentials
                )
            }
            .onChange(of: player.currentSong?.id) {
                previousSongID,
                currentSongID in
                listenTogether.playerSongDidChange(
                    from: previousSongID,
                    to: currentSongID
                )
            }
            .onChange(of: player.isPlaying) { _, isPlaying in
                listenTogether.playerPlaybackDidChange(
                    isPlaying: isPlaying
                )
            }
            .onChange(of: player.seekRevision) {
                listenTogether.playerDidSeek()
            }
            .onChange(of: player.queue.map(\.id)) {
                listenTogether.playerQueueDidChange()
            }
            .onChange(of: player.isShuffled) {
                listenTogether.playerQueueDidChange()
            }
            .alert(
                "一起听",
                isPresented: noticePresented
            ) {
                Button("好", role: .cancel) {
                    listenTogether.dismissNotice()
                }
            } message: {
                Text(
                    listenTogether.noticeMessage
                        ?? "一起听状态已更新。"
                )
            }
    }

    private var hasCredentials: Bool {
        !settings.cookie
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private var noticePresented: Binding<Bool> {
        Binding(
            get: { listenTogether.noticeMessage != nil },
            set: { isPresented in
                if !isPresented {
                    listenTogether.dismissNotice()
                }
            }
        )
    }
}

extension View {
    func coordinateListenTogether() -> some View {
        modifier(ListenTogetherAppCoordinationModifier())
    }
}
