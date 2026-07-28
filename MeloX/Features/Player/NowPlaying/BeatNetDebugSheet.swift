import SwiftUI

struct BeatNetDebugSheet: View {
    @Environment(\.accessibilityDimFlashingLights)
    private var accessibilityDimFlashingLights
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.isLuminanceReduced)
    private var isLuminanceReduced
    @Environment(\.scenePhase) private var scenePhase
    @Environment(AppSettings.self) private var settings
    @Environment(PlayerStore.self) private var player

    @State private var retryGeneration = 0

    var body: some View {
        NavigationStack {
            Form {
                analysisSection
                modelSection

                Section {
                    TimelineView(
                        .periodic(
                            from: .now,
                            by: 0.08
                        )
                    ) { context in
                        BeatNetRealtimeDebugPanel(
                            snapshot:
                                player.beatDebugSnapshot(
                                    at: context.date
                                ),
                            outputGate: outputGate
                        )
                    }
                } header: {
                    Text("实时信号")
                } footer: {
                    Text(
                        "面板约每秒读取 12.5 次只读快照，关闭 Sheet 后立即停止；不会改变播放进度或背景状态。"
                    )
                }
            }
            .navigationTitle("BeatNet 调试")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .confirmationAction
                ) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .task(id: retryGeneration) {
            guard retryGeneration > 0 else {
                return
            }
            await player.analyzeCurrentSongBeats()
        }
    }

    private var analysisSection: some View {
        Section {
            LabeledContent(
                "歌曲",
                value:
                    player.currentSong?.name
                    ?? "没有正在播放的歌曲"
            )

            LabeledContent("状态") {
                analysisStatus
            }

            if case .ready(
                let bpm,
                let confidence
            ) = player.beatAnalysisStatus {
                LabeledContent(
                    "结果",
                    value:
                        "\(Int(bpm.rounded())) BPM · \(Int((confidence * 100).rounded()))%"
                )
            }

            if case .failed(let message) =
                player.beatAnalysisStatus {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            if showsAnalysisRetry {
                Button {
                    retryGeneration += 1
                } label: {
                    Label(
                        "重新分析全曲",
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(player.currentSong == nil)
            }
        } header: {
            Text("分析")
        } footer: {
            Text(
                "正常播放会在“重拍暗角”开启时自动分析；调试面板只读取同一份结果。手动重试用于诊断失败。"
            )
        }
    }

    private var modelSection: some View {
        Section {
            LabeledContent(
                "模型",
                value: "BeatNetBDA"
            )
            LabeledContent("输入") {
                Text("1 × 1600 × 272 · Float32")
                    .monospacedDigit()
            }
            LabeledContent("输出") {
                Text("1 × 1600 × 2 · Float16")
                    .monospacedDigit()
            }
            LabeledContent(
                "输出通道",
                value: "beat / downbeat"
            )
            LabeledContent(
                "计算单元",
                value: "CPU-only"
            )
            LabeledContent(
                "音频",
                value: "22.05 kHz · 单声道"
            )
            LabeledContent(
                "单次推理",
                value: "32 s · 50 fps"
            )
            LabeledContent(
                "覆盖范围",
                value: "全曲（自动合并）"
            )
        } header: {
            Text("Core ML 结构")
        } footer: {
            Text(
                "模型固定接收 32 秒输入，后台会使用 CPU-only 连续分段推理并合并成一条全曲时间轴。Onset 决定触发时刻，Beat 或 Downbeat 任一通道负责确认；Downbeat 只额外加深暗角。"
            )
        }
    }

    @ViewBuilder
    private var analysisStatus: some View {
        switch player.beatAnalysisStatus {
        case .idle:
            Text("等待分析")
                .foregroundStyle(.secondary)
        case .analyzing:
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)
                Text("正在分析全曲")
            }
            .foregroundStyle(.secondary)
        case .ready:
            Label(
                "已就绪",
                systemImage: "checkmark.circle.fill"
            )
            .foregroundStyle(.green)
        case .failed:
            Label(
                "分析失败",
                systemImage: "exclamationmark.triangle.fill"
            )
            .foregroundStyle(.orange)
        }
    }

    private var outputGate:
        BeatNetDebugOutputGate {
        guard settings.playerBackgroundStyle
            == .flowingLight else {
            return .blocked("背景样式不是流动光影")
        }
        guard settings
            .playerBackgroundBeatEffectsEnabled else {
            return .blocked("“重拍暗角”已关闭")
        }
        guard player.currentBeatTimeline != nil else {
            return .blocked("尚无可用的 BeatNet 时间轴")
        }
        guard player.isPlaying else {
            return .blocked("播放已暂停")
        }
        guard !accessibilityReduceMotion else {
            return .blocked("系统已开启“减少动态效果”")
        }
        guard !accessibilityDimFlashingLights else {
            return .blocked("系统已开启“调暗闪烁光线”")
        }
        guard !isLuminanceReduced else {
            return .blocked("屏幕亮度状态限制了动画")
        }
        guard scenePhase == .active else {
            return .blocked("应用当前不在前台")
        }
        return .active
    }

    private var showsAnalysisRetry: Bool {
        switch player.beatAnalysisStatus {
        case .idle, .failed:
            true
        case .analyzing, .ready:
            false
        }
    }

}

private struct BeatNetRealtimeDebugPanel: View {
    let snapshot: PlaybackBeatDebugSnapshot?
    let outputGate: BeatNetDebugOutputGate

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 13
        ) {
            LabeledContent("播放器输出") {
                Label(
                    outputGate.title,
                    systemImage: outputGate.systemImage
                )
                .foregroundStyle(
                    outputGate.color
                )
            }

            if case .blocked(let reason) =
                outputGate {
                Text(reason)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if let snapshot {
                timelineRows(for: snapshot)

                Divider()

                LabeledContent(
                    "输入特征",
                    value:
                        "max \(featureText(snapshot.featureStatistics.maximum)) · mean \(featureText(snapshot.featureStatistics.mean))"
                )
                LabeledContent(
                    "输入有限值",
                    value:
                        "\(snapshot.featureStatistics.finiteValueCount.formatted()) / \(snapshot.featureStatistics.valueCount.formatted())"
                )
                LabeledContent(
                    "输入非零值",
                    value:
                        "\(snapshot.featureStatistics.nonzeroValueCount.formatted()) / \(snapshot.featureStatistics.valueCount.formatted())"
                )
                LabeledContent(
                    "推理路径",
                    value: "CPU-only"
                )
                LabeledContent(
                    "CPU 全零片段",
                    value:
                        "\(snapshot.finalAllZeroSegmentCount)/\(snapshot.analyzedSegmentCount)"
                )

                Divider()

                LabeledContent(
                    "全曲原始峰值",
                    value:
                        "Beat \(activationText(snapshot.maximumBeatActivation, fractionLength: 5)) · Downbeat \(activationText(snapshot.maximumDownbeatActivation, fractionLength: 5))"
                )
                LabeledContent(
                    "原始非零帧",
                    value:
                        "Beat \(snapshot.nonzeroBeatFrameCount) · Downbeat \(snapshot.nonzeroDownbeatFrameCount)"
                )

                activationMeter(
                    "Beat 原始峰值（\(modelPeakHoldMilliseconds) ms）",
                    value:
                        snapshot
                            .recentBeatActivation,
                    tint: .blue,
                    fractionLength: 5
                )
                activationMeter(
                    "Downbeat 原始峰值（\(modelPeakHoldMilliseconds) ms）",
                    value:
                        snapshot
                            .recentDownbeatActivation,
                    tint: .orange,
                    fractionLength: 5
                )
                activationMeter(
                    "Beat 当前值（联合门）",
                    value:
                        snapshot
                            .currentBeatActivation,
                    tint: .blue,
                    fractionLength: 5
                )
                activationMeter(
                    "Downbeat 当前值（联合门）",
                    value:
                        snapshot
                            .currentDownbeatActivation,
                    tint: .orange,
                    fractionLength: 5
                )
                activationMeter(
                    "Onset 激活（联合门）",
                    value:
                        snapshot
                            .normalizedOnsetActivation,
                    tint: .pink
                )
                LabeledContent(
                    "暗角触发条件",
                    value:
                        "Beat/Downbeat ≥ \(thresholdText(PlaybackBeatTimeline.modelVignetteTriggerThreshold)) 且 Onset ≥ \(thresholdText(PlaybackBeatTimeline.onsetVignetteTriggerThreshold))"
                )
                LabeledContent(
                    "匹配与防抖",
                    value:
                        "±\(modelToleranceMilliseconds) ms · \(minimumRetriggerMilliseconds) ms"
                )
                LabeledContent(
                    "Downbeat 加深阈值",
                    value:
                        thresholdText(
                            PlaybackBeatTimeline
                                .downbeatVignetteAccentThreshold
                        )
                )
                LabeledContent("最近联合门") {
                    Label(
                        snapshot
                            .jointVignetteGateIsActive
                            ? "已满足"
                            : "未满足",
                        systemImage:
                            snapshot
                                .jointVignetteGateIsActive
                            ? "checkmark.circle.fill"
                            : "circle"
                    )
                    .foregroundStyle(
                        snapshot
                            .jointVignetteGateIsActive
                            ? .green
                            : .secondary
                    )
                }

                Divider()

                activationMeter(
                    "最近触发强度（\(modelPeakHoldMilliseconds) ms）",
                    value:
                        snapshot
                            .recentVignetteTriggerActivation,
                    tint: .pink
                )
                activationMeter(
                    "应用的暗角包络",
                    value:
                        snapshot
                            .appliedVignettePulse,
                    tint: .pink
                )
                activationMeter(
                    "最终暗角输入（1:1）",
                    value: snapshot.vignettePulse,
                    tint: .purple
                )
            } else {
                ContentUnavailableView(
                    "暂无实时数据",
                    systemImage: "waveform.slash",
                    description:
                        Text("等待 BeatNet 完成分析。")
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func timelineRows(
        for snapshot: PlaybackBeatDebugSnapshot
    ) -> some View {
        LabeledContent(
            "播放位置",
            value: timeText(snapshot.playbackTime)
        )
        LabeledContent(
            "分析范围",
            value:
                "\(timeText(snapshot.regionStart))–\(timeText(snapshot.regionEnd))"
        )
        LabeledContent("当前帧") {
            if let frameIndex =
                snapshot.frameIndex {
                Text(
                    "\(frameIndex + 1) / \(snapshot.frameCount)"
                )
                .monospacedDigit()
            } else {
                Text("超出歌曲范围")
                    .foregroundStyle(.orange)
            }
        }
        LabeledContent(
            "解码事件",
            value:
                "\(snapshot.decodedBeatCount) beat · \(snapshot.decodedDownbeatCount) downbeat"
        )
        LabeledContent("节拍位置") {
            if let beatOrdinal =
                snapshot.beatOrdinal,
               let beatInBar =
                snapshot.beatInBar {
                Text(
                    "第 \(beatOrdinal) 拍 · \(beatInBar)/4"
                )
                .monospacedDigit()
            } else {
                Text("尚未到首拍")
                    .foregroundStyle(.secondary)
            }
        }
        LabeledContent("距上一拍") {
            if let seconds =
                snapshot.secondsSinceBeat {
                Text(
                    seconds.formatted(
                        .number.precision(
                            .fractionLength(3)
                        )
                    ) + " s"
                )
                .monospacedDigit()
            } else {
                Text("—")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func activationMeter(
        _ title: String,
        value: Double,
        tint: Color,
        fractionLength: Int = 3
    ) -> some View {
        let clampedValue = min(
            max(value, 0),
            1
        )

        return VStack(
            alignment: .leading,
            spacing: 5
        ) {
            LabeledContent(title) {
                Text(
                    clampedValue.formatted(
                        .number.precision(
                            .fractionLength(
                                fractionLength
                            )
                        )
                    )
                )
                .monospacedDigit()
            }

            ProgressView(
                value: clampedValue,
                total: 1
            )
            .tint(tint)
        }
    }

    private func activationText(
        _ value: Double,
        fractionLength: Int = 3
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(
                    fractionLength
                )
            )
        )
    }

    private func featureText(
        _ value: Float
    ) -> String {
        Double(value).formatted(
            .number.precision(
                .fractionLength(5)
            )
        )
    }

    private func thresholdText(
        _ value: Double
    ) -> String {
        value.formatted(
            .number.precision(
                .fractionLength(3)
            )
        )
    }

    private var modelPeakHoldMilliseconds:
        Int {
        Int(
            (
                PlaybackBeatTimeline
                    .debugModelPeakHoldDuration
                    * 1_000
            ).rounded()
        )
    }

    private var modelToleranceMilliseconds:
        Int {
        Int(
            (
                PlaybackBeatTimeline
                    .vignetteModelTolerance
                    * 1_000
            ).rounded()
        )
    }

    private var minimumRetriggerMilliseconds:
        Int {
        Int(
            (
                PlaybackBeatTimeline
                    .vignetteMinimumRetriggerInterval
                    * 1_000
            ).rounded()
        )
    }

    private func timeText(
        _ time: TimeInterval
    ) -> String {
        let safeTime = max(time, 0)
        let minutes = Int(safeTime) / 60
        let seconds =
            safeTime
                - Double(minutes * 60)
        return String(
            format: "%d:%05.2f",
            minutes,
            seconds
        )
    }
}

private enum BeatNetDebugOutputGate:
    Equatable
{
    case active
    case blocked(String)

    var title: String {
        switch self {
        case .active:
            "正在输出"
        case .blocked:
            "已阻止"
        }
    }

    var systemImage: String {
        switch self {
        case .active:
            "checkmark.circle.fill"
        case .blocked:
            "pause.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .active:
            .green
        case .blocked:
            .orange
        }
    }
}
