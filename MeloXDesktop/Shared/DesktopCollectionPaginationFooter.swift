import SwiftUI

struct DesktopCollectionPaginationFooter: View {
    let isLoading: Bool
    let failureMessage: String?
    var loadingTitle = "正在加载更多歌曲"
    let action: () async -> Void

    var body: some View {
        Group {
            if let failureMessage {
                VStack(spacing: 8) {
                    Text(failureMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("重新加载") {
                        Task {
                            await action()
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(loadingTitle)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Button("加载更多", systemImage: "arrow.down.circle") {
                    Task {
                        await action()
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}
