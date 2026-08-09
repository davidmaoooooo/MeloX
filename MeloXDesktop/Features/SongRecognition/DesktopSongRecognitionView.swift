import AppKit
import SwiftUI

struct DesktopSongRecognitionView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var recognition = SongRecognitionStore()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("听歌识曲")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                if showsRestartButton {
                    Button("重新识别", systemImage: "arrow.clockwise") {
                        startRecognition()
                    }
                }
                Button("完成") { dismiss() }
            }
            .padding(24)

            Divider()

            Group {
                switch recognition.phase {
                case .ready:
                    readyView
                case .requestingPermission:
                    progressView("正在准备麦克风", detail: "首次使用时，请允许 MeloX 访问麦克风。")
                case .listening:
                    listeningView
                case .matching:
                    progressView("正在识别", detail: "正在本机生成音频指纹，并通过网易云原始接口查询曲库。")
                case .results:
                    resultList
                case .noMatch:
                    noMatchView
                case .failed(let failure):
                    failureView(failure)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 660)
        .onDisappear { recognition.cancel() }
    }

    private var readyView: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 88, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.red)
            VStack(spacing: 8) {
                Text("识别身边正在播放的音乐")
                    .font(.title.bold())
                Text(readyDescription)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 470)
            }
            Picker("识别时长", selection: settingsDuration) {
                ForEach(SongRecognitionDuration.allCases) { duration in
                    Text("\(duration.title) · \(duration.detail)").tag(duration)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 540)

            Button("开始识别", systemImage: "mic.fill") {
                startRecognition()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding(36)
    }

    private var listeningView: some View {
        VStack(spacing: 22) {
            if recognition.isContinuous, !recognition.results.isEmpty {
                resultList
            } else {
                Spacer()
                Image(systemName: "waveform")
                    .font(.system(size: 76, weight: .medium))
                    .foregroundStyle(.red)
                    .symbolEffect(
                        .variableColor.iterative,
                        options: .repeating.speed(1.2),
                        isActive: !reduceMotion
                    )
                Text(recognition.isContinuous ? "正在持续识别" : "正在聆听")
                    .font(.title.bold())
                Text("让 Mac 靠近声源并尽量减少环境噪声。")
                    .foregroundStyle(.secondary)
                Spacer()
            }

            Button(recognition.isContinuous ? "停止识别" : "取消", role: .cancel) {
                if recognition.isContinuous {
                    recognition.stopContinuousRecognition()
                } else {
                    recognition.cancel()
                }
            }
            .buttonStyle(.bordered)
            .padding(.bottom, 24)
        }
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("识别结果")
                        .font(.title2.bold())
                    Spacer()
                    Text("\(recognition.results.count) 首")
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 12)

                ForEach(Array(recognition.results.enumerated()), id: \.element.id) { index, result in
                    Button {
                        play(result)
                    } label: {
                        HStack(spacing: 12) {
                            DesktopArtworkView(url: result.song.album?.artworkURL, cornerRadius: 7)
                                .frame(width: 54, height: 54)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.song.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text("\(result.song.artistText) — \(result.song.album?.name ?? "")")
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button {
                                model.library.toggle(song: result.song)
                            } label: {
                                Image(systemName: model.library.contains(song: result.song) ? "heart.fill" : "heart")
                            }
                            .buttonStyle(.borderless)
                            .foregroundStyle(model.library.contains(song: result.song) ? .red : .secondary)
                            Image(systemName: "play.fill")
                                .foregroundStyle(.red)
                        }
                        .padding(.vertical, 8)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    if index < recognition.results.count - 1 { Divider() }
                }
            }
            .padding(24)
        }
    }

    private var noMatchView: some View {
        ContentUnavailableView {
            Label("没有识别到歌曲", systemImage: "questionmark.circle")
        } description: {
            Text("请靠近声源、减少环境噪声，或延长识别时长后重试。")
        } actions: {
            Button("再试一次", systemImage: "arrow.clockwise") { startRecognition() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func failureView(_ failure: SongRecognitionFailure) -> some View {
        ContentUnavailableView {
            Label("无法完成识别", systemImage: "exclamationmark.triangle")
        } description: {
            Text(failure.message)
        } actions: {
            if failure.opensSystemSettings {
                Button("打开麦克风设置", systemImage: "gear") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            Button("重试", systemImage: "arrow.clockwise") { startRecognition() }
                .buttonStyle(.bordered)
        }
    }

    private func progressView(_ title: String, detail: String) -> some View {
        VStack(spacing: 16) {
            ProgressView().controlSize(.large)
            Text(title).font(.headline)
            Text(detail)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("取消", role: .cancel) { recognition.cancel() }
        }
        .padding(36)
    }

    private var settingsDuration: Binding<SongRecognitionDuration> {
        Binding(
            get: { model.settings.songRecognition.duration },
            set: { model.settings.songRecognition.duration = $0 }
        )
    }

    private var showsRestartButton: Bool {
        switch recognition.phase {
        case .results, .noMatch, .failed: true
        default: false
        }
    }

    private var readyDescription: String {
        let duration = model.settings.songRecognition.duration
        if duration.isContinuous {
            return "MeloX 会持续聆听并不断展示新结果，直到你手动停止；原始录音不会上传。"
        }
        return "MeloX 最长聆听 \(duration.title)，只会向网易云音乐发送设备端生成的音频指纹。"
    }

    private func startRecognition() {
        if model.player.isPlaying { model.player.togglePlayback() }
        recognition.start(api: model.api, duration: model.settings.songRecognition.duration)
    }

    private func play(_ result: SongRecognitionResult) {
        recognition.prepareForResultPlayback()
        Task {
            await model.player.play(
                result.song,
                in: recognition.results.map(\.song),
                startAt: result.playbackPosition
            )
        }
    }
}
