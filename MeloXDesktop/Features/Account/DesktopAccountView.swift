import SwiftUI

struct DesktopAccountView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openSettings) private var openSettings
    @State private var showsLogoutConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("账户")
                .font(.system(size: 28, weight: .bold))
                .padding(.horizontal, 28)
                .padding(.top, 28)
                .padding(.bottom, 20)

            if let profile = model.library.profile {
                loggedInContent(profile)
            } else if model.library.isLoggedIn {
                ProgressView("正在读取网易云账户")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { await model.library.refresh(force: true) }
            } else {
                ContentUnavailableView {
                    Label("登录网易云音乐", systemImage: "person.crop.circle.badge.plus")
                } description: {
                    Text("登录后可同步喜欢的音乐、歌单、播客、云盘、播放记录、私信与一起听。登录 Cookie 只保存在这台 Mac。")
                } actions: {
                    Button("登录") { model.ui.sheet = .login }
                        .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack {
                Spacer()
                doneButton
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 500, height: 600)
        .confirmationDialog(
            "要退出当前网易云音乐账户吗？",
            isPresented: $showsLogoutConfirmation
        ) {
            Button("退出登录", role: .destructive) {
                model.logOut()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private func loggedInContent(_ profile: AccountProfile) -> some View {
        VStack(spacing: 12) {
            accountGroup {
                VStack(spacing: 0) {
                    accountAction("私信") {
                        model.ui.sheet = nil
                        model.ui.navigate(to: .section(.messages))
                    }
                    Divider()
                        .padding(.leading, 12)
                    accountAction("音乐云盘") {
                        model.ui.sheet = nil
                        model.ui.navigate(to: .section(.cloud))
                    }
                    Divider()
                        .padding(.leading, 12)
                    accountAction("下载") {
                        model.ui.sheet = nil
                        model.ui.navigate(to: .section(.downloads))
                    }
                }
            }

            accountGroup {
                accountAction("账户设置") {
                    dismiss()
                    openSettings()
                }
            }

            accountGroup {
                Button {
                    showsLogoutConfirmation = true
                } label: {
                    HStack {
                        Text("退出登录")
                        Spacer()
                        Text(profile.nickname)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.red)
                    .padding(.horizontal, 12)
                    .frame(height: 42)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
    }

    private func accountAction(
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .frame(height: 42)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    private var doneButton: some View {
        Button("完成") { dismiss() }
            .buttonStyle(.plain)
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
            .frame(width: 80, height: 30)
            .background(.red, in: .capsule)
            .contentShape(.capsule)
    }

    private func accountGroup<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .background(
                Color.primary.opacity(0.045),
                in: .rect(cornerRadius: 12, style: .continuous)
            )
    }
}
