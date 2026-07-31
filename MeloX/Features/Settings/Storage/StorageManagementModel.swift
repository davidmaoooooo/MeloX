import Foundation
import Observation

@MainActor
@Observable
final class StorageManagementModel {
    private(set) var usage = ManagedStorageUsage.empty
    private(set) var hasLoadedUsage = false
    private(set) var isRefreshing = false
    private(set) var activeOperation: StorageCleanupAction?
    var confirmation: StorageCleanupAction?
    private(set) var operationMessage: String?
    var errorMessage: String?

    var isBusy: Bool {
        activeOperation != nil
    }

    func refreshUsage() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer {
            isRefreshing = false
            hasLoadedUsage = true
        }

        let measuredUsage = await StorageMaintenance.usage()
        guard !Task.isCancelled else { return }
        usage = measuredUsage
    }

    func perform(
        _ action: StorageCleanupAction,
        downloads: DownloadStore,
        player: PlayerStore
    ) async {
        guard activeOperation == nil else { return }
        activeOperation = action
        operationMessage = nil
        downloads.clearError()

        defer {
            activeOperation = nil
        }
        do {
            switch action {
            case .allCaches:
                let networkBytes = usage.networkCacheBytes
                StorageMaintenance.clearNetworkAndArtworkCaches()
                await player.clearPlaybackAnalysisCache()
                let temporaryBytes =
                    try await StorageMaintenance
                        .clearTemporaryFiles(
                            preservingDownloadTransfers:
                                !downloads.activeDownloads.isEmpty
                        )
                operationMessage =
                    "已清理约 \(formattedSize(networkBytes + temporaryBytes))"

            case .networkCache:
                let byteCount = usage.networkCacheBytes
                StorageMaintenance.clearNetworkAndArtworkCaches()
                operationMessage =
                    "已清理 \(formattedSize(byteCount)) 网络与图片缓存"

            case .temporaryFiles:
                await player.clearPlaybackAnalysisCache()
                let byteCount =
                    try await StorageMaintenance
                        .clearTemporaryFiles(
                            preservingDownloadTransfers:
                                !downloads.activeDownloads.isEmpty
                        )
                operationMessage =
                    "已清理 \(formattedSize(byteCount)) 临时文件"

            case .repairDownloads:
                let result = downloads.repairStorage()
                try checkDownloadOperation(downloads)
                operationMessage =
                    repairMessage(for: result)

            case .automaticCacheHistory:
                downloads.resetAutomaticCacheHistory()
                try checkDownloadOperation(downloads)
                operationMessage = "已重置自动缓存播放计数"

            case .optimizeDatabase:
                downloads.optimizeStorageDatabase()
                try checkDownloadOperation(downloads)
                operationMessage = "本地数据库优化完成"

            case .allDownloads:
                let count = downloads.downloads.count
                downloads.removeAll()
                try checkDownloadOperation(downloads)
                operationMessage = "已删除 \(count) 首本地歌曲"
            }

            await refreshUsage()
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
            await refreshUsage()
        }
    }

    private func checkDownloadOperation(
        _ downloads: DownloadStore
    ) throws {
        guard let message = downloads.errorMessage else {
            return
        }
        downloads.clearError()
        throw StorageManagementError(message: message)
    }

    private func formattedSize(_ byteCount: Int64) -> String {
        byteCount.formatted(.byteCount(style: .file))
    }

    private func repairMessage(
        for result: DownloadStorageRepairResult
    ) -> String {
        guard result.repairedAnything else {
            return "下载存储检查完成，未发现异常"
        }

        var repairs: [String] = []
        if result.removedMissingRecordCount > 0 {
            repairs.append(
                "移除 \(result.removedMissingRecordCount) 条失效记录"
            )
        }
        if result.removedUntrackedByteCount > 0 {
            repairs.append(
                "清理 \(formattedSize(result.removedUntrackedByteCount)) 未登记文件"
            )
        }
        return repairs.joined(separator: "，")
    }
}

enum StorageCleanupAction: String, Identifiable {
    case allCaches
    case networkCache
    case temporaryFiles
    case repairDownloads
    case automaticCacheHistory
    case optimizeDatabase
    case allDownloads

    var id: String { rawValue }

    var title: String {
        switch self {
        case .allCaches:
            "清理所有可重建缓存？"
        case .networkCache:
            "清理网络与图片缓存？"
        case .temporaryFiles:
            "清理临时播放文件？"
        case .repairDownloads:
            "修复下载存储？"
        case .automaticCacheHistory:
            "重置自动缓存计数？"
        case .optimizeDatabase:
            "压缩本地数据库？"
        case .allDownloads:
            "删除所有下载？"
        }
    }

    var confirmButtonTitle: String {
        switch self {
        case .repairDownloads:
            "检查并修复"
        case .automaticCacheHistory:
            "重置计数"
        case .allDownloads:
            "删除所有下载"
        default:
            "立即清理"
        }
    }

    var confirmationMessage: String {
        switch self {
        case .allCaches:
            "将清除可重新下载的网络、图片和非活动临时文件，不会删除已下载歌曲或账号数据。"
        case .networkCache:
            "封面和网络响应会在之后使用时重新下载。"
        case .temporaryFiles:
            "将清理自动混音分析、歌词附件等临时内容；正在使用的文件会保留或按需重新生成。"
        case .repairDownloads:
            "将移除文件已缺失的下载记录，以及没有对应下载记录的本地文件。"
        case .automaticCacheHistory:
            "歌曲用于触发自动缓存的播放次数将从零重新计算，不会删除播放历史或已下载歌曲。"
        case .optimizeDatabase:
            "只会回收数据库中的空闲空间，不会删除记录。"
        case .allDownloads:
            "所有已下载歌曲和正在进行的下载任务都将从本机移除，此操作无法撤销。"
        }
    }
}

private struct StorageManagementError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
