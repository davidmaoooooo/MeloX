import SwiftUI

struct DesktopSleepTimerView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    private let choices: [(String, TimeInterval)] = [
        ("15 分钟", 15 * 60),
        ("30 分钟", 30 * 60),
        ("45 分钟", 45 * 60),
        ("1 小时", 60 * 60),
        ("2 小时", 120 * 60),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("睡眠定时器")
                .font(.title.bold())

            if let endDate = model.player.sleepTimer.endDate {
                Label(
                    "将在 \(endDate.formatted(date: .omitted, time: .shortened)) 停止播放",
                    systemImage: "moon.zzz.fill"
                )
                .foregroundStyle(.secondary)
            }

            ForEach(choices, id: \.1) { choice in
                Button(choice.0) {
                    model.player.sleepTimer.start(duration: choice.1)
                    dismiss()
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }

            if model.player.sleepTimer.isActive {
                Button("关闭定时器", role: .destructive) {
                    model.player.sleepTimer.cancel()
                    dismiss()
                }
            }
        }
        .padding(28)
        .frame(width: 360)
    }
}
