import SwiftUI

struct ListenTogetherView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(LibraryStore.self) private var library
    @Environment(PlayerStore.self) private var player
    @Environment(ListenTogetherStore.self) private var listenTogether

    @State private var invitationText = ""
    @State private var showsLeaveConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                if let room = listenTogether.room {
                    activeRoomContent(room)
                } else {
                    inactiveContent
                }
            }
            .navigationTitle("一起听")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") {
                        dismiss()
                    }
                    .disabled(listenTogether.operation == .leaving)
                }

                if let operation = listenTogether.operation {
                    ToolbarItem(placement: .primaryAction) {
                        ProgressView()
                            .accessibilityLabel(operation.title)
                    }
                }
            }
            .disabled(listenTogether.isBusy)
            .confirmationDialog(
                listenTogether.isHost ? "结束一起听？" : "退出一起听？",
                isPresented: $showsLeaveConfirmation
            ) {
                Button(
                    listenTogether.isHost ? "结束一起听" : "退出一起听",
                    role: .destructive
                ) {
                    Task {
                        await listenTogether.leaveRoom()
                    }
                }
            } message: {
                Text(
                    listenTogether.isHost
                        ? "房间中的成员将停止同步播放。"
                        : "退出后，本机播放将不再与房间同步。"
                )
            }
            .alert(
                "一起听操作失败",
                isPresented: Binding(
                    get: { listenTogether.errorMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            listenTogether.dismissError()
                        }
                    }
                )
            ) {
                Button("好", role: .cancel) {
                    listenTogether.dismissError()
                }
            } message: {
                Text(
                    listenTogether.errorMessage
                        ?? "网易云音乐未完成操作。"
                )
            }
        }
    }

    @ViewBuilder
    private var inactiveContent: some View {
        Section {
            VStack(spacing: 14) {
                Image(systemName: "person.2.wave.2")
                    .font(.system(size: 44))
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)

                Text("和朋友同步听歌")
                    .font(.title3.weight(.semibold))

                Text("房间内的播放、暂停、切歌、播放进度和队列会自动同步。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .listRowBackground(Color.clear)
        }

        if library.isLoggedIn {
            Section {
                Button {
                    Task {
                        await listenTogether.createRoom()
                    }
                } label: {
                    Label(
                        "发起一起听",
                        systemImage: "person.2.badge.plus"
                    )
                }
                .disabled(player.currentSong == nil)
            } header: {
                Text("创建房间")
            } footer: {
                if player.currentSong == nil {
                    Text("请先播放一首歌曲。")
                } else {
                    Text("创建后可通过系统分享把网易云邀请链接发送给朋友。")
                }
            }

            Section {
                TextField(
                    "粘贴网易云一起听邀请链接",
                    text: $invitationText,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Button {
                    Task {
                        await listenTogether.joinRoom(
                            invitationText: invitationText
                        )
                    }
                } label: {
                    Label(
                        "加入房间",
                        systemImage: "rectangle.portrait.and.arrow.right"
                    )
                }
                .disabled(
                    invitationText.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            } header: {
                Text("加入房间")
            } footer: {
                Text("邀请链接需要同时包含房间 ID 与邀请者 ID。")
            }
        } else {
            Section {
                ContentUnavailableView {
                    Label(
                        "需要登录网易云音乐",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                } description: {
                    Text("请先在“设置”的网易云账号页面完成登录。")
                }
            }
        }
    }

    @ViewBuilder
    private func activeRoomContent(
        _ room: ListenTogetherRoom
    ) -> some View {
        Section("正在播放") {
            if let song = player.currentSong {
                HStack(spacing: 12) {
                    songArtwork(song)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(song.name)
                            .font(.headline)
                            .lineLimit(1)
                        Text(song.artistText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, 3)
                .accessibilityElement(children: .combine)
            } else {
                Label(
                    "正在等待房间播放内容",
                    systemImage: "music.note"
                )
                .foregroundStyle(.secondary)
            }
        }

        Section("房间同步") {
            ListenTogetherSyncStatusView()
        }

        Section {
            ListenTogetherMemberRows(room: room)
        } header: {
            Text("房间成员")
        } footer: {
            Text("\(room.users.count) 人在线")
        }

        Section {
            LabeledContent("房间 ID", value: room.id)
                .textSelection(.enabled)

            if let invitationURL = listenTogether.invitationURL {
                ShareLink(
                    item: invitationURL,
                    subject: Text("网易云音乐一起听邀请"),
                    message: Text("和我一起听歌")
                ) {
                    Label(
                        "邀请朋友",
                        systemImage: "square.and.arrow.up"
                    )
                }
            }
        } header: {
            Text("邀请")
        } footer: {
            Text("对方可使用网易云音乐打开链接，或将链接粘贴到 MeloX 加入。")
        }

        Section {
            Button(
                listenTogether.isHost ? "结束一起听" : "退出一起听",
                systemImage: "rectangle.portrait.and.arrow.right",
                role: .destructive
            ) {
                showsLeaveConfirmation = true
            }
        }
    }

    private func songArtwork(_ song: Song) -> some View {
        AsyncImage(url: song.album?.artworkURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Image(systemName: "music.note")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 52, height: 52)
        .background(.quaternary, in: .rect(cornerRadius: 8))
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityHidden(true)
    }

}
