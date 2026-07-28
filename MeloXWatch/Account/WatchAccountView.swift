import SwiftUI

struct WatchAccountView: View {
    @EnvironmentObject private var account: WatchAccountStore
    @EnvironmentObject private var connectivity: WatchConnectivityStore

    let api: WatchNeteaseAPI

    var body: some View {
        List {
            if account.isLoggedIn {
                Section {
                    HStack(spacing: 10) {
                        AsyncImage(
                            url: WatchArtworkURL.make(
                                from: account.profile?.avatarURLString,
                                dimension: 160
                            )
                        ) { phase in
                            if let image = phase.image {
                                image.resizable().scaledToFill()
                            } else {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.largeTitle)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .clipShape(.circle)

                        VStack(alignment: .leading) {
                            Text(account.profile?.nickname ?? "网易云账号")
                                .font(.headline)
                            Text(account.source.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("同步") {
                    Button {
                        connectivity.sendAccountToPhone()
                    } label: {
                        Label("同步登录到 iPhone", systemImage: "iphone")
                    }

                    Button {
                        account.usePhoneLogin()
                        connectivity.requestSnapshot()
                    } label: {
                        Label(
                            "改用 iPhone 登录",
                            systemImage: "applewatch.radiowaves.left.and.right"
                        )
                    }
                }

                Section {
                    Button("退出手表登录", role: .destructive) {
                        account.clear()
                    }
                }
            } else {
                Section {
                    NavigationLink {
                        WatchQRLoginView(api: api)
                    } label: {
                        Label("二维码登录", systemImage: "qrcode")
                    }

                    Button {
                        account.usePhoneLogin()
                        connectivity.requestSnapshot()
                    } label: {
                        Label(
                            "从 iPhone 同步",
                            systemImage: "arrow.triangle.2.circlepath"
                        )
                    }
                }

                Section {
                    Text("watchOS 不提供嵌入式 WebKit。MeloX 使用网易云原生二维码接口实现手表独立登录，也可以直接同步 iPhone 的登录 Cookie。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if let error = connectivity.lastErrorMessage {
                Section("连接状态") {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("网易云账号")
        .task {
            guard account.isLoggedIn,
                  account.profile == nil else {
                return
            }
            if let profile = try? await api.accountProfile() {
                account.updateProfile(profile)
            }
        }
    }
}
