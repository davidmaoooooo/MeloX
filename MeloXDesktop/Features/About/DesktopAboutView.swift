import SwiftUI

struct DesktopAboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.openWindow) private var openWindow

    @State private var isCheckingUpdate = false
    @State private var updateAlert: DesktopAboutUpdateAlert?

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            Image("MeloXLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 176, height: 176)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 0) {
                Text("MeloX")
                    .font(.system(size: 34, weight: .semibold))

                Text(versionDescription)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .padding(.top, 10)

                Text("开发者：洛汐聚合体")
                    .foregroundStyle(.secondary)
                    .padding(.top, 6)

                Spacer(minLength: 20)

                Text(copyrightNotice)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 14)

                HStack(spacing: 8) {
                    Button {
                        Task {
                            await checkForUpdates()
                        }
                    } label: {
                        HStack(spacing: 5) {
                            if isCheckingUpdate {
                                ProgressView()
                                    .controlSize(.small)
                            }

                            Text(isCheckingUpdate ? "正在检查…" : "检查更新…")
                        }
                    }
                    .disabled(isCheckingUpdate)

                    Button("GitHub 仓库") {
                        openURL(AppUpdateService.repositoryURL)
                    }

                    Button("版权声明…") {
                        openWindow(id: "licenses")
                    }
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.top, 52)
        .padding(.horizontal, 40)
        .padding(.bottom, 28)
        .frame(width: 600, height: 320)
        .alert(item: $updateAlert) { alert in
            if let releaseURL = alert.releaseURL {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    primaryButton: .default(Text("打开发布页")) {
                        openURL(releaseURL)
                    },
                    secondaryButton: .cancel(Text("好"))
                )
            } else {
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("好"))
                )
            }
        }
    }

    private var versionDescription: String {
        "版本 \(Bundle.main.appReleaseVersion) (\(Bundle.main.appBuildNumber))"
    }

    private var copyrightNotice: String {
        let year = Calendar.current.component(.year, from: .now)
        return "© \(year) 洛汐聚合体。\nMeloX 是非官方第三方网易云音乐客户端。"
    }

    @MainActor
    private func checkForUpdates() async {
        guard !isCheckingUpdate else { return }

        isCheckingUpdate = true
        defer {
            isCheckingUpdate = false
        }

        do {
            let result = try await AppUpdateService.checkLatestRelease(
                currentVersion: Bundle.main.appReleaseVersion
            )

            if result.hasUpdate {
                updateAlert = DesktopAboutUpdateAlert(
                    title: "发现新版本",
                    message: "当前版本 \(result.currentVersion)，最新版本 \(result.latestVersion)。",
                    releaseURL: result.releaseURL
                )
            } else {
                updateAlert = DesktopAboutUpdateAlert(
                    title: "已是最新版本",
                    message: "当前版本 \(result.currentVersion) 已是最新版本。",
                    releaseURL: nil
                )
            }
        } catch {
            updateAlert = DesktopAboutUpdateAlert(
                title: "检查更新失败",
                message: error.localizedDescription,
                releaseURL: nil
            )
        }
    }
}

private struct DesktopAboutUpdateAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let releaseURL: URL?
}
