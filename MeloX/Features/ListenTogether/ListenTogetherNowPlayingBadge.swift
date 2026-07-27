import SwiftUI

struct ListenTogetherNowPlayingBadge: View {
    @Environment(ListenTogetherStore.self) private var listenTogether

    @State private var showsMembers = false

    var body: some View {
        if let room = listenTogether.room {
            Button {
                showsMembers = true
            } label: {
                Label("一起听", systemImage: "person.2.fill")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .foregroundStyle(.white)
                    .background(.white.opacity(0.14), in: .capsule)
            }
            .buttonStyle(.plain)
            .fixedSize()
            .accessibilityLabel("一起听，\(room.users.count) 位成员")
            .accessibilityHint("轻点查看房间成员")
            .popover(isPresented: $showsMembers) {
                ListenTogetherMembersView()
                    .presentationCompactAdaptation(.sheet)
            }
        }
    }
}
