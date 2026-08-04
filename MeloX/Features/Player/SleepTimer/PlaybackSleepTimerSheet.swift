import SwiftUI

struct PlaybackSleepTimerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PlayerStore.self) private var player

    var body: some View {
        NavigationStack {
            Form {
                if let endDate = player.sleepTimer.endDate {
                    activeTimerSection(endDate: endDate)
                }

                Section {
                    ForEach(PlaybackSleepTimerPreset.allCases) { preset in
                        Button {
                            player.sleepTimer.start(
                                duration: preset.duration
                            )
                            dismiss()
                        } label: {
                            Label(
                                preset.title,
                                systemImage: "clock"
                            )
                        }
                    }
                } header: {
                    Text(
                        player.sleepTimer.isActive
                            ? "重新设置"
                            : "关闭时间"
                    )
                } footer: {
                    Text("倒计时结束后将暂停播放，并保留当前播放列表与进度。")
                }

                if player.sleepTimer.isActive {
                    Section {
                        Button("取消定时关闭", role: .destructive) {
                            player.sleepTimer.cancel()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("定时关闭")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func activeTimerSection(endDate: Date) -> some View {
        Section {
            LabeledContent("剩余时间") {
                Text(
                    timerInterval:
                        min(Date.now, endDate)...endDate,
                    countsDown: true
                )
                .monospacedDigit()
            }

            LabeledContent("预计停止") {
                Text(
                    endDate,
                    format: .dateTime.hour().minute()
                )
            }
        } header: {
            Text("当前计时")
        }
    }
}

private enum PlaybackSleepTimerPreset: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case fortyFiveMinutes = 45
    case sixtyMinutes = 60
    case ninetyMinutes = 90

    var id: Int { rawValue }

    var title: String {
        "\(rawValue) 分钟后"
    }

    var duration: TimeInterval {
        TimeInterval(rawValue * 60)
    }
}
