import SwiftUI

struct DesktopListenTogetherView: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var invitationText: String
    @State private var confirmsLeaving = false

    init(invitationText: String = "") {
        _invitationText = State(initialValue: invitationText)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("一起听")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                if let operation = model.listenTogether.operation {
                    ProgressView()
                        .controlSize(.small)
                        .help(operation.title)
                }
                Button("完成") { dismiss() }
            }
            .padding(26)

            Divider()

            Group {
                if let room = model.listenTogether.room {
                    activeRoom(room)
                } else {
                    inactiveRoom
                }
            }
            .disabled(model.listenTogether.isBusy)
        }
        .frame(width: 620, height: 620)
        .alert(
            "一起听操作失败",
            isPresented: Binding(
                get: { model.listenTogether.errorMessage != nil },
                set: { if !$0 { model.listenTogether.dismissError() } }
            )
        ) {
            Button("好") { model.listenTogether.dismissError() }
        } message: {
            Text(model.listenTogether.errorMessage ?? "网易云音乐未完成操作。")
        }
        .confirmationDialog(
            model.listenTogether.isHost ? "结束一起听？" : "退出一起听？",
            isPresented: $confirmsLeaving
        ) {
            Button(
                model.listenTogether.isHost ? "结束一起听" : "退出一起听",
                role: .destructive
            ) {
                Task { await model.listenTogether.leaveRoom() }
            }
        }
    }

    private var inactiveRoom: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "person.2.wave.2")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(.red)
                    .padding(.top, 38)

                VStack(spacing: 8) {
                    Text("和朋友同步听歌")
                        .font(.title.bold())
                    Text("播放、暂停、切歌、进度和队列都会通过网易云一起听房间同步。")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                if model.library.isLoggedIn {
                    Button {
                        Task { await model.listenTogether.createRoom() }
                    } label: {
                        Label("发起一起听", systemImage: "person.2.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.player.currentSong == nil)

                    if model.player.currentSong == nil {
                        Text("请先播放一首歌曲。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("加入房间")
                            .font(.headline)
                        TextField(
                            "粘贴网易云一起听邀请链接",
                            text: $invitationText,
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)

                        Button("加入") {
                            Task {
                                await model.listenTogether.joinRoom(
                                    invitationText: invitationText
                                )
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(invitationText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(18)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 14))
                } else {
                    ContentUnavailableView {
                        Label("需要登录网易云音乐", systemImage: "person.crop.circle.badge.exclamationmark")
                    } description: {
                        Text("一起听使用你的网易云账户创建和加入房间。")
                    } actions: {
                        Button("登录") { model.ui.sheet = .login }
                    }
                }
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 36)
        }
    }

    private func activeRoom(_ room: ListenTogetherRoom) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    Image(systemName: model.listenTogether.connectionState.systemImage)
                        .foregroundStyle(model.listenTogether.connectionState == .connected ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.listenTogether.connectionState.title)
                            .font(.headline)
                        Text(model.listenTogether.isHost ? "你发起的房间" : "已加入好友的房间")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await model.listenTogether.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                if let song = model.player.currentSong {
                    HStack(spacing: 14) {
                        DesktopArtworkView(url: song.album?.artworkURL, cornerRadius: 8)
                            .frame(width: 72, height: 72)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("正在同步")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(song.name)
                                .font(.title3.bold())
                            Text(song.artistText)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 14))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("房间成员")
                        .font(.headline)
                    ForEach(room.users) { user in
                        HStack(spacing: 10) {
                            DesktopArtworkView(url: user.avatarURL, cornerRadius: 999)
                                .frame(width: 40, height: 40)
                                .clipShape(.circle)
                            Text(user.nickname)
                            if user.id == room.creatorID {
                                Text("房主")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 3)
                                    .background(.red.opacity(0.12), in: .capsule)
                                    .foregroundStyle(.red)
                            }
                            Spacer()
                        }
                    }
                }

                HStack {
                    if let url = model.listenTogether.invitationURL {
                        ShareLink(item: url) {
                            Label("分享邀请", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Button(
                        model.listenTogether.isHost ? "结束房间" : "退出房间",
                        role: .destructive
                    ) {
                        confirmsLeaving = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(28)
        }
    }
}
