import QRCode
import SwiftUI

struct WatchQRLoginView: View {
    @EnvironmentObject private var account: WatchAccountStore
    @EnvironmentObject private var connectivity: WatchConnectivityStore
    @Environment(\.dismiss) private var dismiss

    let api: WatchNeteaseAPI

    @State private var key: String?
    @State private var qrImage: CGImage?
    @State private var status = "正在生成二维码"
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let qrImage {
                    Image(
                        decorative: qrImage,
                        scale: 1,
                        orientation: .up
                    )
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(8)
                    .background(.white, in: .rect(cornerRadius: 14))
                    .accessibilityLabel("网易云音乐登录二维码")
                } else if isLoading {
                    ProgressView()
                        .frame(height: 120)
                }

                Text(status)
                    .font(.footnote)
                    .multilineTextAlignment(.center)

                Text("使用 iPhone 上的网易云音乐 App 扫码并确认")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)

                    Button("重新生成") {
                        Task { await generateAndPoll() }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 8)
        }
        .navigationTitle("二维码登录")
        .task {
            await generateAndPoll()
        }
    }

    private func generateAndPoll() async {
        isLoading = true
        errorMessage = nil
        status = "正在生成二维码"
        do {
            let key = try await api.makeQRLoginKey()
            self.key = key
            let url = "https://music.163.com/login?codekey=\(key)"
            qrImage = try? makeQRCode(url)
            isLoading = false
            status = "等待扫码"
            await poll(key: key)
        } catch is CancellationError {
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            status = "生成失败"
        }
    }

    private func poll(key: String) async {
        while !Task.isCancelled, self.key == key {
            do {
                let result = try await api.checkQRLogin(key: key)
                switch result.code {
                case 800:
                    status = "二维码已过期，正在刷新"
                    await generateAndPoll()
                    return
                case 801:
                    status = "等待扫码"
                case 802:
                    status = "已扫码，请在 iPhone 上确认"
                case 803:
                    guard !result.cookie.isEmpty else {
                        throw WatchNeteaseError.invalidResponse
                    }
                    status = "登录成功"
                    account.saveQRLogin(
                        cookie: result.cookie,
                        profile: nil
                    )
                    if let profile = try? await api.accountProfile() {
                        account.updateProfile(profile)
                    }
                    connectivity.sendAccountToPhone()
                    dismiss()
                    return
                default:
                    status = result.message ?? "等待网易云音乐确认"
                }
                try await Task.sleep(for: .seconds(1))
            } catch is CancellationError {
                return
            } catch {
                errorMessage = error.localizedDescription
                status = "检查登录状态失败"
                return
            }
        }
    }

    private func makeQRCode(_ string: String) throws -> CGImage {
        let document = try QRCode.Document(
            utf8String: string,
            errorCorrection: .medium
        )
        return try document.cgImage(dimension: 512)
    }
}
