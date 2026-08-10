import SwiftUI

struct DesktopMessagesView: View {
    @Environment(DesktopAppModel.self) private var model
    @State private var conversations: [NeteasePrivateConversation] = []
    @State private var selectedContact: NeteaseMessageContact?
    @State private var phase: LoadingPhase = .loading
    @State private var isComposing = false

    private var currentUserID: Int { model.library.profile?.id ?? 0 }

    var body: some View {
        Group {
            if !model.library.isLoggedIn {
                ContentUnavailableView {
                    Label("需要登录", systemImage: "bubble.left.and.bubble.right")
                } description: {
                    Text("登录网易云音乐后可以读取和发送私信。")
                } actions: {
                    Button("登录") { model.ui.sheet = .login }
                        .buttonStyle(.borderedProminent)
                }
            } else {
                HSplitView {
                    conversationList
                        .frame(minWidth: 270, idealWidth: 330, maxWidth: 410)

                    if let selectedContact {
                        DesktopConversationPane(contact: selectedContact)
                            .id(selectedContact.id)
                    } else {
                        ContentUnavailableView(
                            "选择一段对话",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("你和网易云好友的私信会显示在这里。")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        }
        .navigationTitle("私信")
        .toolbar {
            if !model.ui.isNowPlayingPresented {
                ToolbarItemGroup {
                    Button {
                        Task { await load() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("刷新私信")
                    .disabled(!model.library.isLoggedIn)

                    Button {
                        isComposing = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .help("发起私信")
                    .disabled(!model.library.isLoggedIn)
                }
            }
        }
        .sheet(isPresented: $isComposing) {
            DesktopNewMessageSheet { contact in
                selectedContact = contact
            }
            .environment(model)
        }
        .task(id: model.settings.cookie) { await load() }
    }

    private var conversationList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("对话")
                    .font(.title2.bold())
                Spacer()
                Text(conversations.count.formatted())
                    .foregroundStyle(.secondary)
            }
            .padding(18)

            Divider()

            List {
                ForEach(conversations) { conversation in
                    let contact = conversation.participant(currentUserID: currentUserID)
                    Button {
                        selectedContact = contact
                        clearUnread(for: contact.id)
                    } label: {
                        HStack(spacing: 11) {
                            DesktopArtworkView(url: contact.artworkURL, cornerRadius: 999)
                                .frame(width: 44, height: 44)
                                .clipShape(.circle)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(contact.displayName)
                                        .font(.headline)
                                        .lineLimit(1)
                                    Spacer()
                                    if conversation.lastMessageTime > 0 {
                                        Text(messageTime(conversation.lastMessageTime))
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                                HStack {
                                    Text(conversation.lastMessage.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                    Spacer()
                                    if conversation.unreadCount > 0 {
                                        Text(conversation.unreadCount.formatted())
                                            .font(.caption2.bold())
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(.red, in: .capsule)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(
                        selectedContact?.id == contact.id
                            ? Color.accentColor.opacity(0.12)
                            : Color.clear
                    )
                }
            }
            .listStyle(.plain)
            .overlay {
                switch phase {
                case .loading where conversations.isEmpty:
                    Color.clear
                        .desktopLoadingStatus(
                            "正在读取私信…",
                            isPresented: true
                        )
                case .failed(let message) where conversations.isEmpty:
                    ContentUnavailableView(
                        "无法读取私信",
                        systemImage: "wifi.exclamationmark",
                        description: Text(message)
                    )
                case .loaded where conversations.isEmpty:
                    ContentUnavailableView(
                        "暂无私信",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("收到和发起的会话会显示在这里。")
                    )
                default:
                    EmptyView()
                }
            }
        }
    }

    private func load() async {
        guard model.library.isLoggedIn else {
            conversations = []
            phase = .loaded
            return
        }
        phase = .loading
        do {
            conversations = try await model.api.privateMessageConversations()
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func clearUnread(for contactID: Int) {
        guard let index = conversations.firstIndex(where: {
            $0.participant(currentUserID: currentUserID).id == contactID
        }) else { return }
        conversations[index].unreadCount = 0
    }

    private func messageTime(_ milliseconds: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1_000)
        if Calendar.current.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct DesktopConversationPane: View {
    @Environment(DesktopAppModel.self) private var model
    let contact: NeteaseMessageContact
    @State private var messages: [NeteasePrivateMessage] = []
    @State private var draft = ""
    @State private var phase: LoadingPhase = .loading
    @State private var isSending = false

    private var currentUserID: Int { model.library.profile?.id ?? 0 }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                DesktopArtworkView(url: contact.artworkURL, cornerRadius: 999)
                    .frame(width: 38, height: 38)
                    .clipShape(.circle)
                VStack(alignment: .leading, spacing: 1) {
                    Text(contact.displayName)
                        .font(.headline)
                    if let signature = contact.signature, !signature.isEmpty {
                        Text(signature)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 18)
            .frame(height: 64)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            messageBubble(message)
                                .id(message.id)
                        }
                    }
                    .padding(20)
                }
                .onChange(of: messages.count) {
                    guard let id = messages.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.22)) {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
                .overlay {
                    switch phase {
                    case .loading where messages.isEmpty:
                        Color.clear
                            .desktopLoadingStatus(
                                "正在读取对话…",
                                isPresented: true
                            )
                    case .failed(let message) where messages.isEmpty:
                        ContentUnavailableView(
                            "无法读取对话",
                            systemImage: "wifi.exclamationmark",
                            description: Text(message)
                        )
                    default:
                        EmptyView()
                    }
                }
            }

            Divider()

            HStack(alignment: .bottom, spacing: 10) {
                TextField("发私信给 \(contact.displayName)", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .padding(10)
                    .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: 10))
                    .onSubmit { send() }

                Button(action: send) {
                    if isSending {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.up")
                    }
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
            }
            .padding(14)
        }
        .task { await load() }
    }

    @ViewBuilder
    private func messageBubble(_ message: NeteasePrivateMessage) -> some View {
        let outgoing = message.isOutgoing(currentUserID: currentUserID)
        HStack {
            if outgoing { Spacer(minLength: 90) }
            VStack(alignment: outgoing ? .trailing : .leading, spacing: 4) {
                if let resource = message.payload.resource {
                    Button {
                        navigate(to: resource)
                    } label: {
                        HStack(spacing: 9) {
                            DesktopArtworkView(url: resource.artworkURL, cornerRadius: 6)
                                .frame(width: 44, height: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resource.kindTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(resource.title)
                                    .font(.callout.weight(.semibold))
                                    .lineLimit(1)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
                if !message.payload.text.isEmpty {
                    Text(message.payload.text)
                        .textSelection(.enabled)
                }
                Text(Date(timeIntervalSince1970: TimeInterval(message.time) / 1_000).formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(
                outgoing ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.11),
                in: .rect(cornerRadius: 13)
            )
            if !outgoing { Spacer(minLength: 90) }
        }
    }

    private func load() async {
        phase = .loading
        do {
            messages = try await model.api.privateMessageHistory(userID: contact.id)
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        isSending = true
        Task {
            defer { isSending = false }
            do {
                try await model.api.sendPrivateText(text, to: [contact.id])
                draft = ""
                await load()
            } catch {
                phase = .failed(error.localizedDescription)
            }
        }
    }

    private func navigate(to resource: NeteaseShareResource) {
        switch resource {
        case .song(let song): model.ui.navigate(to: .song(song.id))
        case .playlist(let playlist): model.ui.navigate(to: .playlist(playlist.id))
        case .album(let album): model.ui.navigate(to: .album(album.id))
        }
    }
}

private struct DesktopNewMessageSheet: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let onSelect: (NeteaseMessageContact) -> Void
    @State private var contacts: [NeteaseMessageContact] = []
    @State private var query = ""

    private var filteredContacts: [NeteaseMessageContact] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return contacts }
        return contacts.filter {
            $0.displayName.localizedStandardContains(trimmed)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("发起私信")
                    .font(.title2.bold())
                Spacer()
                Button("完成") { dismiss() }
            }
            .padding(20)

            TextField("搜索关注的人", text: $query)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

            List(filteredContacts) { contact in
                Button {
                    onSelect(contact)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        DesktopArtworkView(url: contact.artworkURL, cornerRadius: 999)
                            .frame(width: 38, height: 38)
                            .clipShape(.circle)
                        VStack(alignment: .leading) {
                            Text(contact.displayName)
                            if let signature = contact.signature {
                                Text(signature)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 480, height: 600)
        .task {
            let loadingMessage = "正在读取联系人…"
            model.ui.setPresentedLoadingMessage(loadingMessage)
            defer {
                model.ui.clearPresentedLoadingMessage(
                    ifMatching: loadingMessage
                )
            }
            guard let id = model.library.profile?.id else { return }
            contacts = (try? await model.api.messageContacts(userID: id)) ?? []
        }
    }
}
