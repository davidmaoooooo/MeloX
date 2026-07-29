import SwiftUI
import UIKit

struct SongRecognitionView: View {
    @Environment(\.accessibilityReduceMotion)
    private var accessibilityReduceMotion
    @Environment(\.openURL) private var openURL
    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player
    @Environment(LibraryStore.self) private var library
    @Environment(AppSettings.self) private var settings

    @State private var recognition = SongRecognitionStore()

    var body: some View {
        Group {
            switch recognition.phase {
            case .ready:
                readyView
            case .requestingPermission:
                progressView(
                    title: "正在准备麦克风",
                    description: "首次使用时，请允许 MeloX 访问麦克风。"
                )
            case .listening:
                if recognition.isContinuous {
                    continuousListeningView
                } else {
                    listeningView
                }
            case .matching:
                progressView(
                    title: "正在识别",
                    description: "正在生成音频指纹并查询网易云音乐曲库。"
                )
            case .results:
                resultsView
            case .noMatch:
                noMatchView
            case .failed(let failure):
                failureView(failure)
            }
        }
        .navigationTitle("听歌识曲")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsRestartButton {
                ToolbarItem(placement: .primaryAction) {
                    Button(
                        "重新识别",
                        systemImage: "arrow.clockwise",
                        action: startRecognition
                    )
                }
            }
        }
        .alert(
            "收藏失败",
            isPresented: Binding(
                get: { library.errorMessage != nil },
                set: { if !$0 { library.clearError() } }
            )
        ) {
            Button("好", role: .cancel) {
                library.clearError()
            }
        } message: {
            Text(library.errorMessage ?? "未知错误")
        }
        .onDisappear {
            recognition.cancel()
        }
    }

    private var readyView: some View {
        ContentUnavailableView {
            Label("听歌识曲", systemImage: "waveform")
        } description: {
            Text(readyDescription)
        } actions: {
            Button(
                "开始识别",
                systemImage: "mic.fill",
                action: startRecognition
            )
            .buttonStyle(.borderedProminent)
        }
    }

    private var listeningView: some View {
        VStack(spacing: 22) {
            Spacer()

            listeningSymbol

            VStack(spacing: 8) {
                Text("正在聆听")
                    .font(.title2.bold())
                Text(
                    "请将设备靠近声源并尽量保持安静。识别到结果后会立即显示，最长聆听 \(settings.songRecognition.duration.title)。"
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button("取消", role: .cancel) {
                recognition.cancel()
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
    }

    private var continuousListeningView: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    listeningSymbol

                    VStack(spacing: 6) {
                        Text("正在持续识别")
                            .font(.title3.bold())
                        Text("新结果会持续加入列表，直到你手动停止。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button("停止识别", role: .cancel) {
                        recognition.stopContinuousRecognition()
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .listRowSeparator(.hidden)
            }

            if !recognition.results.isEmpty {
                Section("识别结果") {
                    ForEach(recognition.results) { result in
                        recognitionResultRow(result)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var resultsView: some View {
        List {
            Section("识别结果") {
                ForEach(recognition.results) { result in
                    recognitionResultRow(result)
                }
            }
        }
        .listStyle(.plain)
    }

    private var listeningSymbol: some View {
        Image(systemName: "waveform")
            .font(.system(size: 64, weight: .medium))
            .foregroundStyle(.tint)
            .symbolEffect(
                .variableColor.iterative,
                options: .repeating.speed(1.2),
                isActive: !accessibilityReduceMotion
            )
            .accessibilityHidden(true)
    }

    private func recognitionResultRow(
        _ result: SongRecognitionResult
    ) -> some View {
        Button {
            play(result)
        } label: {
            TrackRowView(
                song: result.song,
                showsArtwork: true
            )
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button {
                library.toggle(song: result.song)
            } label: {
                Label(
                    library.contains(song: result.song)
                        ? "取消收藏"
                        : "收藏",
                    systemImage:
                        library.contains(song: result.song)
                            ? "heart.slash"
                            : "heart"
                )
            }
            .tint(.pink)
        }
        .accessibilityHint("从识别到的位置开始播放")
    }

    private var noMatchView: some View {
        ContentUnavailableView {
            Label(
                "没有识别到歌曲",
                systemImage: "questionmark.circle"
            )
        } description: {
            Text("请靠近声源、减少环境噪声，或在设置中延长时长、选择持续识别后重试。")
        } actions: {
            Button(
                "再试一次",
                systemImage: "arrow.clockwise",
                action: startRecognition
            )
            .buttonStyle(.borderedProminent)
        }
    }

    private func failureView(
        _ failure: SongRecognitionFailure
    ) -> some View {
        ContentUnavailableView {
            Label(
                "无法完成识别",
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text(failure.message)
        } actions: {
            if failure.opensSystemSettings,
               let settingsURL = URL(
                   string: UIApplication.openSettingsURLString
               ) {
                Button("打开系统设置", systemImage: "gear") {
                    openURL(settingsURL)
                }
                .buttonStyle(.borderedProminent)

                Button(
                    "重试",
                    systemImage: "arrow.clockwise",
                    action: startRecognition
                )
                .buttonStyle(.bordered)
            } else {
                Button(
                    "重试",
                    systemImage: "arrow.clockwise",
                    action: startRecognition
                )
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func progressView(
        title: String,
        description: String
    ) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .controlSize(.large)
            Text(title)
                .font(.headline)
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("取消", role: .cancel) {
                recognition.cancel()
            }
            .buttonStyle(.bordered)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var showsRestartButton: Bool {
        switch recognition.phase {
        case .results, .noMatch, .failed:
            true
        case .ready,
             .requestingPermission,
             .listening,
             .matching:
            false
        }
    }

    private var readyDescription: String {
        let duration = settings.songRecognition.duration
        if duration.isContinuous {
            return "将 iPhone 靠近正在播放的音乐。MeloX 会持续聆听并不断展示识别结果，直到你手动停止。只会向网易云音乐发送设备端生成的音频指纹。"
        }
        return "将 iPhone 靠近正在播放的音乐。MeloX 最长会聆听 \(duration.title)，识别到结果后立即停止，并只向网易云音乐发送设备端生成的音频指纹。"
    }

    private func play(_ result: SongRecognitionResult) {
        recognition.prepareForResultPlayback()
        Task {
            await player.play(
                result.song,
                in: recognition.results.map(\.song),
                startAt: result.playbackPosition
            )
        }
    }

    private func startRecognition() {
        if player.isPlaying {
            player.togglePlayback()
        }
        recognition.start(
            api: api,
            duration: settings.songRecognition.duration
        )
    }
}
