import SwiftUI

struct HeartModeNowPlayingBadge: View {
    @Environment(PlayerStore.self) private var player

    @State private var showsActions = false

    var body: some View {
        if player.isHeartModeActive {
            Button {
                showsActions = true
            } label: {
                Label("心动模式", systemImage: "heart.fill")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.14), in: .capsule)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel("当前正在使用心动模式")
            .accessibilityHint("轻点管理心动模式")
            .confirmationDialog(
                "心动模式",
                isPresented: $showsActions,
                titleVisibility: .visible
            ) {
                Button(role: .destructive) {
                    player.disableHeartMode()
                } label: {
                    Label("关闭心动模式", systemImage: "heart.slash")
                }

                Button("取消", role: .cancel) {}
            } message: {
                Text("关闭后会保留当前播放队列。")
            }
        }
    }
}
