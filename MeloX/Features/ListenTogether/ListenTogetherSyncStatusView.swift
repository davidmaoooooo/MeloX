import SwiftUI

struct ListenTogetherSyncStatusView: View {
    @Environment(ListenTogetherStore.self) private var listenTogether

    @State private var isRefreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 13) {
                statusIcon

                VStack(alignment: .leading, spacing: 3) {
                    Text(statusTitle)
                        .font(.headline)

                    Text(statusDetail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                Text(listenTogether.isHost ? "房主" : "参与者")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        statusColor.opacity(0.12),
                        in: .capsule
                    )
            }

            Divider()

            HStack(spacing: 12) {
                lastSyncLabel

                Spacer()

                Button {
                    refresh()
                } label: {
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("正在同步")
                    } else {
                        Label(
                            "立即同步",
                            systemImage: "arrow.clockwise"
                        )
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(isRefreshing)
            }
            .font(.footnote)
        }
        .padding(.vertical, 5)
        .animation(
            .default,
            value: listenTogether.connectionState
        )
    }

    @ViewBuilder
    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(statusColor.opacity(0.14))

            if listenTogether.connectionState == .reconnecting {
                ProgressView()
                    .tint(statusColor)
                    .controlSize(.small)
            } else {
                Image(systemName: statusSystemImage)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
        }
        .frame(width: 42, height: 42)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var lastSyncLabel: some View {
        if let lastSyncDate = listenTogether.lastSyncDate {
            Label {
                HStack(spacing: 3) {
                    Text("最近同步")
                    Text(lastSyncDate, style: .relative)
                }
            } icon: {
                Image(systemName: "clock")
            }
            .foregroundStyle(.secondary)
        } else {
            Label(
                "等待首次同步",
                systemImage: "clock"
            )
            .foregroundStyle(.secondary)
        }
    }

    private var statusTitle: String {
        switch listenTogether.connectionState {
        case .idle:
            "正在准备同步"
        case .connected:
            "播放已与房间同步"
        case .reconnecting:
            "正在恢复房间连接"
        }
    }

    private var statusDetail: String {
        switch listenTogether.connectionState {
        case .idle:
            "正在读取房间的播放状态。"
        case .connected:
            "播放、进度与队列会自动保持一致。"
        case .reconnecting:
            "连接恢复后会自动继续，无需重新加入。"
        }
    }

    private var statusSystemImage: String {
        switch listenTogether.connectionState {
        case .idle:
            "clock"
        case .connected:
            "checkmark"
        case .reconnecting:
            "arrow.clockwise"
        }
    }

    private var statusColor: Color {
        switch listenTogether.connectionState {
        case .idle:
            .secondary
        case .connected:
            .green
        case .reconnecting:
            .orange
        }
    }

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        Task { @MainActor in
            await listenTogether.refresh()
            isRefreshing = false
        }
    }
}
