import SwiftUI

struct StorageManagementView: View {
    @Environment(DownloadStore.self) private var downloads
    @Environment(PlayerStore.self) private var player

    @State private var model = StorageManagementModel()

    var body: some View {
        List {
            overviewSection
            storageItemsSection
            cacheCleanupSection
            maintenanceSection
            if AppFeatureAvailability.downloads {
                destructiveSection
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("存储管理")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await model.refreshUsage()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.refreshUsage() }
                } label: {
                    if model.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(model.isRefreshing || model.isBusy)
                .accessibilityLabel("重新统计存储空间")
            }
        }
        .task {
            await model.refreshUsage()
        }
        .onChange(of: downloads.totalByteCount) {
            Task { await model.refreshUsage() }
        }
        .onChange(of: downloads.activeDownloads.count) {
            Task { await model.refreshUsage() }
        }
        .alert(
            "存储操作失败",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        model.errorMessage = nil
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "未知错误")
        }
    }

    private var overviewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "internaldrive.fill")
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("MeloX 管理的内容")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        if model.hasLoadedUsage {
                            Text(
                                formattedSize(
                                    displayedManagedByteCount
                                )
                            )
                            .font(.title2.weight(.semibold))
                            .contentTransition(.numericText())
                        } else {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }

                deviceCapacityView
            }
            .padding(.vertical, 6)

            LabeledContent(
                "可重新生成的缓存",
                value: formattedSize(
                    model.usage.reclaimableCacheBytes
                )
            )

            if let operationMessage = model.operationMessage {
                Label(
                    operationMessage,
                    systemImage: "checkmark.circle.fill"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
        } header: {
            Text("总览")
        } footer: {
            Text(
                AppFeatureAvailability.downloads
                    ? "统计包含下载、MeloX 数据库、网络缓存和临时播放文件，不包含 App 本体与系统管理的其他空间。"
                    : "统计包含 MeloX 数据库、网络缓存和临时播放文件，不包含 App 本体与系统管理的其他空间。"
            )
        }
    }

    @ViewBuilder
    private var deviceCapacityView: some View {
        if let total = model.usage.deviceTotalBytes,
           let available = model.usage.deviceAvailableBytes,
           total > 0 {
            let used = max(total - available, 0)

            ProgressView(
                value: Double(used),
                total: Double(total)
            )
            .tint(.accentColor)

            HStack {
                Text("设备已使用 \(formattedSize(used))")
                Spacer()
                Text("可用 \(formattedSize(available))")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var storageItemsSection: some View {
        Section("存储项目") {
            if AppFeatureAvailability.downloads {
                NavigationLink {
                    DownloadsView()
                } label: {
                    storageUsageRow(
                        title: "下载与自动缓存",
                        subtitle:
                            "\(downloads.downloads.count) 首歌曲",
                        systemImage: "arrow.down.circle.fill",
                        byteCount: model.usage.downloadsBytes
                    )
                }
            }

            storageUsageRow(
                title: "网络与图片缓存",
                subtitle: "封面与网络响应，可按需重新获取",
                systemImage: "photo.stack",
                byteCount: model.usage.networkCacheBytes
            )

            storageUsageRow(
                title: "临时播放文件",
                subtitle: "自动混音分析与歌词附件",
                systemImage: "waveform.path",
                byteCount: model.usage.temporaryFilesBytes
            )

            storageUsageRow(
                title: "本地数据库",
                subtitle:
                    AppFeatureAvailability.downloads
                        ? "下载记录与自动缓存计数"
                        : "播放与应用数据",
                systemImage: "cylinder.split.1x2",
                byteCount: model.usage.databaseBytes
            )
        }
    }

    private var cacheCleanupSection: some View {
        Section {
            cleanupButton(
                action: .allCaches,
                title: "清理所有可重建缓存",
                subtitle: "网络、图片和非活动临时文件",
                systemImage: "eraser",
                byteCount: model.usage.reclaimableCacheBytes
            )

            cleanupButton(
                action: .networkCache,
                title: "清理网络与图片缓存",
                subtitle: "之后浏览时会按需重新获取",
                systemImage: "photo.on.rectangle.angled",
                byteCount: model.usage.networkCacheBytes
            )

            cleanupButton(
                action: .temporaryFiles,
                title: "清理临时播放文件",
                subtitle:
                    AppFeatureAvailability.downloads
                        ? "保留正在下载与正在使用的文件"
                        : "保留正在使用的文件",
                systemImage: "waveform",
                byteCount: model.usage.temporaryFilesBytes
            )
        } header: {
            Text("缓存清理")
        } footer: {
            Text(
                AppFeatureAvailability.downloads
                    ? "缓存清理不会删除已下载歌曲、收藏、账号信息或播放队列。正在使用的文件可能会被保留或立即重新生成。"
                    : "缓存清理不会删除收藏、账号信息或播放队列。正在使用的文件可能会被保留或立即重新生成。"
            )
        }
    }

    private var maintenanceSection: some View {
        Section {
            if AppFeatureAvailability.downloads {
                cleanupButton(
                    action: .repairDownloads,
                    title: "修复下载存储",
                    subtitle: "清除缺失记录与未登记文件",
                    systemImage: "wrench.and.screwdriver",
                    byteCount: nil,
                    disabled: !downloads.activeDownloads.isEmpty
                )

                cleanupButton(
                    action: .automaticCacheHistory,
                    title: "重置自动缓存计数",
                    subtitle: "重新计算歌曲的播放触发次数",
                    systemImage: "arrow.counterclockwise",
                    byteCount: nil
                )
            }

            Button {
                Task {
                    await model.perform(
                        .optimizeDatabase,
                        downloads: downloads,
                        player: player
                    )
                }
            } label: {
                operationLabel(
                    action: .optimizeDatabase,
                    title: "压缩本地数据库",
                    subtitle: "回收已删除记录留下的空间",
                    systemImage: "cylinder.split.1x2",
                    byteCount: model.usage.databaseBytes
                )
            }
            .disabled(
                model.isBusy
                    || (
                        AppFeatureAvailability.downloads
                            && !downloads.activeDownloads.isEmpty
                    )
            )
        } header: {
            Text("维护")
        } footer: {
            if AppFeatureAvailability.downloads,
               !downloads.activeDownloads.isEmpty {
                Text("下载任务完成或取消后，才能修复下载存储或压缩数据库。")
            }
        }
    }

    private var destructiveSection: some View {
        Section {
            Button(role: .destructive) {
                model.confirmation = .allDownloads
            } label: {
                operationLabel(
                    action: .allDownloads,
                    title: "删除所有下载",
                    subtitle: "同时取消正在进行的下载任务",
                    systemImage: "trash",
                    byteCount: model.usage.downloadsBytes
                )
            }
            .disabled(
                model.isBusy
                    || (
                        downloads.downloads.isEmpty
                            && downloads.activeDownloads.isEmpty
                    )
            )
            .confirmationDialog(
                StorageCleanupAction.allDownloads.title,
                isPresented:
                    confirmationIsPresented(
                        for: .allDownloads
                    ),
                titleVisibility: .visible
            ) {
                confirmationActions(for: .allDownloads)
            } message: {
                Text(
                    StorageCleanupAction
                        .allDownloads
                        .confirmationMessage
                )
            }
        } header: {
            Text("危险操作")
        } footer: {
            Text("删除的歌曲文件无法恢复，但不会影响网易云音乐中的收藏和歌单。")
        }
    }

    private func storageUsageRow(
        title: String,
        subtitle: String,
        systemImage: String,
        byteCount: Int64
    ) -> some View {
        LabeledContent {
            Text(formattedSize(byteCount))
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
        } label: {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
            }
        }
    }

    private func cleanupButton(
        action: StorageCleanupAction,
        title: String,
        subtitle: String,
        systemImage: String,
        byteCount: Int64?,
        disabled: Bool = false
    ) -> some View {
        Button {
            model.confirmation = action
        } label: {
            operationLabel(
                action: action,
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                byteCount: byteCount
            )
        }
        .disabled(model.isBusy || disabled)
        .confirmationDialog(
            action.title,
            isPresented:
                confirmationIsPresented(for: action),
            titleVisibility: .visible
        ) {
            confirmationActions(for: action)
        } message: {
            Text(action.confirmationMessage)
        }
    }

    private func operationLabel(
        action: StorageCleanupAction,
        title: String,
        subtitle: String,
        systemImage: String,
        byteCount: Int64?
    ) -> some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage)
            }

            Spacer(minLength: 8)

            if model.activeOperation == action {
                ProgressView()
                    .controlSize(.small)
            } else if let byteCount {
                Text(formattedSize(byteCount))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
        }
        .contentShape(.rect)
    }

    private func confirmationIsPresented(
        for action: StorageCleanupAction
    ) -> Binding<Bool> {
        Binding(
            get: { model.confirmation == action },
            set: { isPresented in
                if !isPresented,
                   model.confirmation == action {
                    model.confirmation = nil
                }
            }
        )
    }

    @ViewBuilder
    private func confirmationActions(
        for action: StorageCleanupAction
    ) -> some View {
        Button(
            action.confirmButtonTitle,
            role: .destructive
        ) {
            Task {
                await model.perform(
                    action,
                    downloads: downloads,
                    player: player
                )
            }
        }
        Button("取消", role: .cancel) {}
    }

    private func formattedSize(_ byteCount: Int64) -> String {
        byteCount.formatted(.byteCount(style: .file))
    }

    private var displayedManagedByteCount: Int64 {
        guard !AppFeatureAvailability.downloads else {
            return model.usage.totalManagedBytes
        }
        return max(
            model.usage.totalManagedBytes
                - model.usage.downloadsBytes,
            0
        )
    }
}
