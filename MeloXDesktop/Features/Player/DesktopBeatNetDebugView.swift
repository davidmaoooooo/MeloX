import SwiftUI

struct DesktopBeatNetDebugView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var retryGeneration = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("BeatNet 调试")
                    .font(.system(size: 24, weight: .bold))
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(22)

            Divider()

            Form {
                analysisSection

                Section("实时信号") {
                    TimelineView(.periodic(from: .now, by: 0.08)) {
                        context in
                        realtimePanel(
                            snapshot: model.player.beatDebugSnapshot(
                                at: context.date
                            )
                        )
                    }
                }

                Section("模型") {
                    LabeledContent("模型", value: "BeatNetBDA")
                    LabeledContent("输入", value: "1 × 1600 × 272 · Float32")
                    LabeledContent("输出", value: "beat / downbeat")
                    LabeledContent("音频", value: "22.05 kHz · 单声道")
                    LabeledContent("计算单元", value: "CPU-only")
                }
            }
            .formStyle(.grouped)
            .padding(12)
        }
        .frame(width: 680, height: 640)
        .task(id: retryGeneration) {
            guard retryGeneration > 0 else { return }
            await model.player.analyzeCurrentSongBeats()
        }
    }

    private var analysisSection: some View {
        Section("分析") {
            LabeledContent(
                "歌曲",
                value: model.player.currentSong?.name ?? "没有正在播放的歌曲"
            )

            LabeledContent("状态") {
                analysisStatus
            }

            if case .ready(let bpm, let confidence) =
                model.player.beatAnalysisStatus {
                LabeledContent(
                    "结果",
                    value:
                        "\(Int(bpm.rounded())) BPM · \(percentage(confidence))"
                )
            }

            if case .failed(let message) = model.player.beatAnalysisStatus {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Button("重新分析全曲", systemImage: "arrow.clockwise") {
                model.player.clearCurrentSongBeatAnalysis()
                retryGeneration += 1
            }
            .disabled(
                model.player.currentSong == nil
                    || model.player.beatAnalysisStatus == .analyzing
            )
        }
    }

    @ViewBuilder
    private var analysisStatus: some View {
        switch model.player.beatAnalysisStatus {
        case .idle:
            Text("等待分析")
                .foregroundStyle(.secondary)
        case .analyzing:
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)
                Text("正在分析全曲")
            }
        case .ready:
            Label("已就绪", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Label("分析失败", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
    }

    @ViewBuilder
    private func realtimePanel(
        snapshot: PlaybackBeatDebugSnapshot?
    ) -> some View {
        if let snapshot {
            LabeledContent(
                "播放位置",
                value: seconds(snapshot.playbackTime)
            )
            LabeledContent(
                "BPM / 置信度",
                value:
                    "\(Int(snapshot.bpm.rounded())) / \(percentage(snapshot.confidence))"
            )
            LabeledContent(
                "节拍",
                value: snapshot.beatInBar.map {
                    "第 \($0) 拍"
                } ?? "—"
            )
            LabeledContent(
                "Beat / Downbeat",
                value:
                    "\(activation(snapshot.recentBeatActivation)) / \(activation(snapshot.recentDownbeatActivation))"
            )
            LabeledContent(
                "Onset",
                value: activation(snapshot.normalizedOnsetActivation)
            )
            LabeledContent(
                "暗角触发",
                value: snapshot.jointVignetteGateIsActive ? "触发" : "未触发"
            )
            LabeledContent(
                "暗角强度",
                value: activation(snapshot.appliedVignettePulse)
            )
            LabeledContent(
                "分析帧",
                value: snapshot.frameIndex.map {
                    "\($0 + 1) / \(snapshot.frameCount)"
                } ?? "超出分析区间"
            )
        } else {
            Text("当前还没有可读取的 BeatNet 时间轴。")
                .foregroundStyle(.secondary)
        }
    }

    private func percentage(_ value: Double) -> String {
        value.formatted(
            .percent.precision(.fractionLength(0))
        )
    }

    private func activation(_ value: Double) -> String {
        value.formatted(
            .number.precision(.fractionLength(3))
        )
    }

    private func seconds(_ value: TimeInterval) -> String {
        value.formatted(
            .number.precision(.fractionLength(2))
        ) + " s"
    }
}
