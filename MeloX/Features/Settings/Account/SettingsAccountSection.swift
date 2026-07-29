import SwiftUI

private enum SettingsAccountSheet: String, Identifiable {
    case neteaseLogin

    var id: String { rawValue }
}

struct SettingsAccountSection: View {
    @Environment(AppSettings.self) private var settings
    @Environment(LibraryStore.self) private var library

    @State private var presentedSheet: SettingsAccountSheet?
    @State private var showsLogoutConfirmation = false

    var body: some View {
        VStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 10) {
                accountOverview

                if !library.isLoggedIn {
                    Text("登录 Cookie 仅保存在本机，用于同步收藏、云盘和账号内容。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                }
            }

            if library.isLoggedIn {
                logoutCard
            }
        }
        .task(id: settings.cookie) {
            await library.refresh()
        }
        .sheet(item: $presentedSheet) { destination in
            switch destination {
            case .neteaseLogin:
                NavigationStack {
                    NeteaseLoginView()
                }
            }
        }
        .confirmationDialog(
            "退出当前网易云账号？",
            isPresented: $showsLogoutConfirmation
        ) {
            Button("退出登录", role: .destructive) {
                logout()
            }
        } message: {
            Text("本机保存的网易云登录 Cookie 和已加载的账号数据将被清除，已下载歌曲不会被删除。")
        }
    }

    @ViewBuilder
    private var accountOverviewContent: some View {
        if library.isLoggedIn, let profile = library.profile {
            NavigationLink(value: SettingsRoute.accountHome) {
                HStack(spacing: 16) {
                    accountAvatar(profile)

                    VStack(alignment: .leading, spacing: 5) {
                        Text(profile.nickname)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Text(accountSubtitle(profile))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("打开账号信息与个人主页")
        } else if library.isLoggedIn {
            HStack(spacing: 16) {
                ProgressView()
                    .frame(width: 60, height: 60)

                VStack(alignment: .leading, spacing: 5) {
                    Text("网易云音乐账号")
                        .font(.title3.weight(.semibold))
                    Text("正在读取账号信息")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Button {
                presentedSheet = .neteaseLogin
            } label: {
                HStack(spacing: 16) {
                    Image(
                        systemName:
                            "person.crop.circle.badge.plus"
                    )
                    .font(.system(size: 36))
                    .foregroundStyle(.tint)
                    .frame(width: 60, height: 60)
                    .background(.quaternary, in: .circle)

                    VStack(alignment: .leading, spacing: 5) {
                        Text("登录网易云音乐")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text("同步收藏、云盘与播放记录")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .layoutPriority(1)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.forward")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
        }
    }

    private var accountOverview: some View {
        accountOverviewContent
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(
                maxWidth: .infinity,
                minHeight: 100,
                alignment: .leading
            )
            .background {
                RoundedRectangle(
                    cornerRadius: 28,
                    style: .continuous
                )
                .fill(
                    Color(
                        uiColor:
                            .secondarySystemGroupedBackground
                    )
                )
            }
    }

    private var logoutCard: some View {
        Button(role: .destructive) {
            showsLogoutConfirmation = true
        } label: {
            HStack(spacing: 14) {
                Image(
                    systemName:
                        "rectangle.portrait.and.arrow.right"
                )
                .font(.title3.weight(.medium))
                .frame(width: 30)

                Text("退出登录")
                    .font(.body.weight(.medium))

                Spacer(minLength: 8)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(minHeight: 60)
            .contentShape(.rect)
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(
                cornerRadius: 26,
                style: .continuous
            )
            .fill(
                Color(
                    uiColor:
                        .secondarySystemGroupedBackground
                )
            )
        }
    }

    private func accountAvatar(_ profile: AccountProfile) -> some View {
        AsyncImage(url: profile.artworkURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Image(systemName: "person.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 60, height: 60)
        .background(.quaternary, in: .circle)
        .clipShape(.circle)
        .accessibilityHidden(true)
    }

    private func accountSubtitle(_ profile: AccountProfile) -> String {
        if let detail = library.accountDetail, detail.level > 0 {
            return "Lv.\(detail.level) · 用户 ID \(profile.id)"
        }
        return "用户 ID \(profile.id) · 账号信息与同步"
    }

    private func logout() {
        settings.clearAccount()
        library.clearAccountData()
        Task {
            await NeteaseWebCookieStore.clear()
        }
    }
}
