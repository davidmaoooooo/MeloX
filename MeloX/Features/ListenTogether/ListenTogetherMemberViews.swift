import SwiftUI

struct ListenTogetherMemberRows: View {
    let room: ListenTogetherRoom

    @ViewBuilder
    var body: some View {
        if room.users.isEmpty {
            Label(
                "正在读取房间成员",
                systemImage: "person.2"
            )
            .foregroundStyle(.secondary)
        } else {
            ForEach(room.users) { user in
                ListenTogetherMemberRow(
                    user: user,
                    isHost: user.id == room.creatorID
                )
            }
        }
    }
}

struct ListenTogetherMembersView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ListenTogetherStore.self) private var listenTogether

    var body: some View {
        NavigationStack {
            List {
                if let room = listenTogether.room {
                    Section {
                        ListenTogetherMemberRows(room: room)
                    } header: {
                        Text("\(room.users.count) 人在线")
                    }
                } else {
                    ContentUnavailableView(
                        "房间已结束",
                        systemImage: "person.2.slash"
                    )
                }
            }
            .navigationTitle("一起听成员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    invitationShareButton
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .frame(minWidth: 300, minHeight: 340)
    }

    @ViewBuilder
    private var invitationShareButton: some View {
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
        } else {
            Button(
                "邀请朋友",
                systemImage: "square.and.arrow.up"
            ) {}
            .disabled(true)
            .accessibilityHint("当前没有可分享的播放歌曲")
        }
    }
}

private struct ListenTogetherMemberRow: View {
    let user: ListenTogetherUser
    let isHost: Bool

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: user.avatarURL) { phase in
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
            .frame(width: 40, height: 40)
            .background(.quaternary, in: .circle)
            .clipShape(.circle)
            .accessibilityHidden(true)

            Text(user.nickname)
                .lineLimit(1)

            Spacer()

            if isHost {
                Text("房主")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}
