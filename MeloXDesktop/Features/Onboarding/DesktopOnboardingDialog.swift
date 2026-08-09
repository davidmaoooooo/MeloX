import SwiftUI

struct DesktopOnboardingDialog: View {
    @Environment(DesktopAppModel.self) private var model
    @State private var page = 0
    @State private var showsLogin = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(pageTitle)
                    .font(.system(size: 30, weight: .bold))
                Spacer()
                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index == page ? Color.red : Color.secondary.opacity(0.22))
                            .frame(width: 8, height: 8)
                    }
                }
            }
            .padding(.horizontal, 34)
            .padding(.top, 30)
            .padding(.bottom, 22)

            Divider()

            Group {
                switch page {
                case 0: welcomePage
                case 1: experiencePage
                default: accountPage
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentTransition(.opacity)

            Divider()

            HStack {
                if page > 0 {
                    Button("返回") {
                        withAnimation(.easeInOut(duration: 0.22)) { page -= 1 }
                    }
                }

                Spacer()

                if page < 2 {
                    Button("继续") {
                        withAnimation(.easeInOut(duration: 0.22)) { page += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else if model.library.isLoggedIn {
                    Button("开始使用 MeloX") { finish() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                } else {
                    Button("稍后登录") { finish() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    Button("登录网易云音乐") { showsLogin = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            }
            .padding(.horizontal, 34)
            .frame(height: 76)
        }
        .frame(width: 760, height: 650)
        .background(Color(nsColor: .windowBackgroundColor))
        .interactiveDismissDisabled()
        .sheet(isPresented: $showsLogin) {
            DesktopLoginView()
                .environment(model)
        }
    }

    private var pageTitle: String {
        switch page {
        case 0: "欢迎"
        case 1: "设置 MeloX"
        default: "网易云音乐账户"
        }
    }

    private var welcomePage: some View {
        VStack(spacing: 28) {
            Spacer()

            Image("MeloXLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 132, height: 132)
                .clipShape(.rect(cornerRadius: 28))
                .shadow(color: .black.opacity(0.14), radius: 16, y: 8)

            VStack(spacing: 10) {
                Text("MeloX")
                    .font(.system(size: 38, weight: .bold))
                Text("为 Mac 独立构建的网易云音乐播放器")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 30) {
                onboardingFeature("完整资料库", symbol: "music.note.list")
                onboardingFeature("动态歌词", symbol: "quote.bubble")
                onboardingFeature("下载与云盘", symbol: "icloud.and.arrow.down")
            }

            Text("MeloX 是非官方第三方客户端，与网易云音乐及其关联公司不存在隶属、合作或授权关系。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 520)

            Spacer()
        }
        .padding(.horizontal, 42)
    }

    private var experiencePage: some View {
        @Bindable var settings = model.settings
        @Bindable var recognition = model.settings.songRecognition

        return Form {
            Section("外观") {
                Picker("外观", selection: $settings.appearance) {
                    ForEach(AppAppearance.allCases) { appearance in
                        Label(appearance.title, systemImage: appearance.systemImage)
                            .tag(appearance)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("播放") {
                Picker("播放音质", selection: $settings.quality) {
                    ForEach(MusicQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
                Toggle("暂停时缩小封面", isOn: $settings.shrinksPausedArtwork)
                Toggle("背景响应节拍", isOn: $settings.playerBackgroundBeatEffectsEnabled)
            }

            Section("听歌识曲") {
                Picker("默认时长", selection: $recognition.duration) {
                    ForEach(SongRecognitionDuration.allCases) { duration in
                        Text(duration.title).tag(duration)
                    }
                }
                Text("听歌识曲只会发送在这台 Mac 上生成的音频指纹。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
    }

    private var accountPage: some View {
        VStack(spacing: 28) {
            Spacer()

            if let profile = model.library.profile {
                DesktopCircularArtworkView(url: profile.artworkURL)
                    .frame(width: 112, height: 112)
                    .clipShape(.circle)
                VStack(spacing: 7) {
                    Text(profile.nickname)
                        .font(.title.bold())
                    Label("已登录", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 82, weight: .regular))
                    .foregroundStyle(.red)
                VStack(spacing: 9) {
                    Text("连接网易云音乐")
                        .font(.title.bold())
                    Text("登录后即可同步喜欢的音乐、歌单、播客、云盘、播放历史、私信和一起听。登录不是使用 MeloX 的必要条件。")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 500)
                }
            }

            VStack(alignment: .leading, spacing: 17) {
                Label("直接连接网易云音乐原始接口", systemImage: "network")
                Label("登录 Cookie 只保存在本机", systemImage: "lock.macwindow")
                Label("手机端与桌面端界面和设置相互独立", systemImage: "macbook.and.iphone")
            }
            .font(.body)

            Spacer()
        }
        .padding(.horizontal, 44)
    }

    private func onboardingFeature(_ title: String, symbol: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol)
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.red)
            Text(title)
                .font(.headline)
        }
        .frame(width: 150)
    }

    private func finish() {
        model.settings.completeOnboarding()
        model.ui.sheet = nil
        Task { await model.refreshAll() }
    }
}
