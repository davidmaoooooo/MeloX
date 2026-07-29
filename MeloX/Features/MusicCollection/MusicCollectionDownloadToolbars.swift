import SwiftUI

struct MusicCollectionDownloadMenuContent: View {
    let coordinator: MusicCollectionDownloadCoordinator
    let downloadableSongCount: Int
    let onDownloadAll: (MusicQuality) -> Void

    var body: some View {
        Menu {
            ForEach(MusicQuality.allCases) { quality in
                Button(quality.title) {
                    onDownloadAll(quality)
                }
            }
        } label: {
            Label(
                "下载全部（\(downloadableSongCount) 首）",
                systemImage: "arrow.down.circle"
            )
        }
        .disabled(
            downloadableSongCount == 0
                || coordinator.isPreparing
        )

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                coordinator.beginSelection()
            }
        } label: {
            Label("多选", systemImage: "checklist")
        }
        .disabled(
            downloadableSongCount == 0
                || coordinator.isPreparing
        )
    }
}

struct MusicCollectionDownloadSelectionToolbar: ToolbarContent {
    let coordinator: MusicCollectionDownloadCoordinator
    let downloadableSongIDs: [Int]
    let onDownloadSelection: (MusicQuality) -> Void

    @ToolbarContentBuilder
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button("完成") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    coordinator.finishSelection()
                }
            }
            .disabled(coordinator.isPreparing)
        }

        ToolbarItemGroup(placement: .bottomBar) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    coordinator.toggleAll(
                        songIDs: Set(downloadableSongIDs)
                    )
                }
            } label: {
                Label(
                    hasSelectedAllDownloadableSongs
                        ? "取消全选"
                        : "全选",
                    systemImage: hasSelectedAllDownloadableSongs
                        ? "checkmark.circle.fill"
                        : "checkmark.circle"
                )
            }
            .disabled(
                downloadableSongIDs.isEmpty
                    || coordinator.isPreparing
            )

            Spacer()

            if coordinator.isPreparing {
                ProgressView()
                    .accessibilityLabel(
                        "正在准备下载 \(coordinator.preparingSongCount) 首歌曲"
                    )
            } else {
                Menu {
                    ForEach(MusicQuality.allCases) { quality in
                        Button(quality.title) {
                            onDownloadSelection(quality)
                        }
                    }
                } label: {
                    Label(
                        "下载 \(selectedDownloadCount) 首",
                        systemImage: "arrow.down.circle"
                    )
                }
                .disabled(selectedDownloadCount == 0)
            }
        }
    }

    private var selectedDownloadCount: Int {
        coordinator.selectedSongIDs
            .intersection(downloadableSongIDs)
            .count
    }

    private var hasSelectedAllDownloadableSongs: Bool {
        let downloadableSongIDSet = Set(downloadableSongIDs)
        return !downloadableSongIDSet.isEmpty
            && downloadableSongIDSet.isSubset(
                of: coordinator.selectedSongIDs
            )
    }
}
