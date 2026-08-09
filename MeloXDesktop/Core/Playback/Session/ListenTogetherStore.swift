import Foundation
import Observation

enum ListenTogetherConnectionState: Equatable {
    case idle
    case connected
    case reconnecting

    var title: String {
        switch self {
        case .idle:
            "未连接"
        case .connected:
            "已同步"
        case .reconnecting:
            "正在重新连接"
        }
    }

    var systemImage: String {
        switch self {
        case .idle:
            "circle"
        case .connected:
            "checkmark.circle.fill"
        case .reconnecting:
            "arrow.trianglehead.2.clockwise.rotate.90"
        }
    }
}

enum ListenTogetherOperation: Equatable {
    case creating
    case joining
    case leaving

    var title: String {
        switch self {
        case .creating:
            "正在创建"
        case .joining:
            "正在加入"
        case .leaving:
            "正在退出"
        }
    }
}

enum ListenTogetherSessionError: LocalizedError {
    case noCurrentSong
    case roomUnavailable(String?)
    case missingRoom
    case missingAccount
    case invalidPlaybackState

    var errorDescription: String? {
        switch self {
        case .noCurrentSong:
            "请先播放一首歌曲，再发起一起听。"
        case .roomUnavailable(let status):
            if status?.uppercased() == "FULL" {
                "一起听房间人数已满。"
            } else {
                "该一起听房间当前无法加入。"
            }
        case .missingRoom:
            "网易云音乐没有返回有效的一起听房间。"
        case .missingAccount:
            "无法读取当前网易云账号，请重新登录后再试。"
        case .invalidPlaybackState:
            "一起听房间暂时没有可同步的播放内容。"
        }
    }
}

@MainActor
@Observable
final class ListenTogetherStore {
    var room: ListenTogetherRoom?
    var isHost = false
    var connectionState:
        ListenTogetherConnectionState = .idle
    private(set) var operation: ListenTogetherOperation?
    var lastSyncDate: Date?
    var errorMessage: String?
    var noticeMessage: String?

    var isInRoom: Bool {
        room != nil
    }

    var isBusy: Bool {
        operation != nil
    }

    var invitationURL: URL? {
        guard let room,
              let inviterID = localUserID.map(String.init)
                ?? nonEmpty(room.creatorID),
              let songID = player.currentSong?.id else {
            return nil
        }
        var components = URLComponents(
            string: "https://st.music.163.com/listen-together/share/"
        )
        components?.queryItems = [
            URLQueryItem(name: "songId", value: String(songID)),
            URLQueryItem(name: "roomId", value: room.id),
            URLQueryItem(name: "inviterId", value: inviterID),
        ]
        return components?.url
    }

    @ObservationIgnored
    let api: NeteaseAPI

    @ObservationIgnored
    let player: PlayerStore

    @ObservationIgnored
    var localUserID: Int?

    @ObservationIgnored
    var clientSequence = 0

    @ObservationIgnored
    var monitorTask: Task<Void, Never>?

    @ObservationIgnored
    var queueReportTask: Task<Void, Never>?

    @ObservationIgnored
    var isApplyingRemoteState = false

    @ObservationIgnored
    var suppressReportsUntil = Date.distantPast

    @ObservationIgnored
    var lastPlaylistSignature: String?

    @ObservationIgnored
    var lastCommandSignature: String?

    @ObservationIgnored
    var consecutiveSyncFailures = 0

    init(api: NeteaseAPI, player: PlayerStore) {
        self.api = api
        self.player = player
    }

    func accountDidChange(hasCredentials: Bool) async {
        if isInRoom {
            clearSession()
        }
        guard hasCredentials else { return }
        await restoreSession()
    }

    func createRoom() async {
        guard !isBusy, !isInRoom else { return }
        guard player.currentSong != nil else {
            errorMessage =
                ListenTogetherSessionError.noCurrentSong.localizedDescription
            return
        }

        operation = .creating
        errorMessage = nil
        noticeMessage = nil
        defer { operation = nil }

        do {
            let profile = try await api.accountProfile()
            let payload = try await api.createListenTogetherRoom()
            guard let createdRoom = payload.roomInfo else {
                throw ListenTogetherSessionError.missingRoom
            }

            establishSession(
                room: createdRoom,
                localUserID: profile.id
            )
            do {
                try await sendPlaylistSnapshot()
                try await sendCurrentPlaybackCommand(type: .goTo)
                try await sendHeartbeat()
            } catch is CancellationError {
                startMonitoring()
                return
            } catch {
                connectionState = .reconnecting
                errorMessage =
                    "房间已创建，但首次同步失败：\(error.localizedDescription)"
            }
            startMonitoring()
        } catch is CancellationError {
            return
        } catch {
            if isInRoom {
                clearSession()
            }
            errorMessage = error.localizedDescription
        }
    }

    func joinRoom(invitationText: String) async {
        guard !isBusy, !isInRoom else { return }

        operation = .joining
        errorMessage = nil
        noticeMessage = nil
        defer { operation = nil }

        do {
            let invitation = try ListenTogetherInvitation(
                text: invitationText
            )
            let profile = try await api.accountProfile()
            let roomCheck = try await api.checkListenTogetherRoom(
                roomID: invitation.roomID
            )
            guard roomCheck.isJoinable else {
                throw ListenTogetherSessionError.roomUnavailable(
                    roomCheck.status
                )
            }

            let payload = try await api.acceptListenTogetherInvitation(
                roomID: invitation.roomID,
                inviterID: invitation.inviterID
            )
            let joinedRoom: ListenTogetherRoom
            if let acceptedRoom = payload.roomInfo {
                joinedRoom = acceptedRoom
            } else {
                let status = try await api.listenTogetherRoomStatus()
                guard status.isInRoom,
                      let statusRoom = status.roomInfo,
                      statusRoom.id == invitation.roomID else {
                    throw ListenTogetherSessionError.missingRoom
                }
                joinedRoom = statusRoom
            }

            establishSession(
                room: joinedRoom,
                localUserID: profile.id
            )
            do {
                try await synchronizeFromServer(initial: true)
                try await sendHeartbeat()
            } catch is CancellationError {
                startMonitoring()
                return
            } catch {
                connectionState = .reconnecting
                errorMessage =
                    "已加入房间，正在等待播放状态：\(error.localizedDescription)"
            }
            startMonitoring()
        } catch is CancellationError {
            return
        } catch {
            if isInRoom {
                clearSession()
            }
            errorMessage = error.localizedDescription
        }
    }

    func leaveRoom() async {
        guard !isBusy, let room else { return }

        operation = .leaving
        errorMessage = nil
        var leaveError: Error?
        do {
            try await api.endListenTogetherRoom(roomID: room.id)
        } catch is CancellationError {
            operation = nil
            return
        } catch {
            leaveError = error
        }

        clearSession()
        operation = nil
        if let leaveError {
            noticeMessage =
                "已停止本机同步，但网易云房间退出请求失败：\(leaveError.localizedDescription)"
        }
    }

    func refresh() async {
        guard !isBusy, isInRoom else { return }
        do {
            try await refreshRoomStatus()
            guard isInRoom else { return }
            try await synchronizeFromServer(initial: false)
            try await sendHeartbeat()
            connectionState = .connected
            consecutiveSyncFailures = 0
            lastSyncDate = .now
        } catch is CancellationError {
            return
        } catch {
            connectionState = .reconnecting
            errorMessage = error.localizedDescription
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func dismissNotice() {
        noticeMessage = nil
    }

    func establishSession(
        room: ListenTogetherRoom,
        localUserID: Int
    ) {
        monitorTask?.cancel()
        queueReportTask?.cancel()
        self.room = room
        self.localUserID = localUserID
        isHost = room.creatorID == String(localUserID)
        clientSequence = 0
        lastPlaylistSignature = nil
        lastCommandSignature = nil
        consecutiveSyncFailures = 0
        connectionState = .connected
        lastSyncDate = nil
        suppressReportsUntil = .distantFuture
        player.beginListenTogetherSession()
    }

    func clearSession(notice: String? = nil) {
        monitorTask?.cancel()
        monitorTask = nil
        queueReportTask?.cancel()
        queueReportTask = nil
        room = nil
        localUserID = nil
        isHost = false
        clientSequence = 0
        lastPlaylistSignature = nil
        lastCommandSignature = nil
        consecutiveSyncFailures = 0
        connectionState = .idle
        lastSyncDate = nil
        isApplyingRemoteState = false
        suppressReportsUntil = .distantPast
        player.endListenTogetherSession()
        if let notice {
            noticeMessage = notice
        }
    }

    private func restoreSession() async {
        guard !isInRoom else { return }
        do {
            async let profile = api.accountProfile()
            async let roomStatus = api.listenTogetherRoomStatus()
            let (loadedProfile, status) = try await (
                profile,
                roomStatus
            )
            guard status.isInRoom,
                  let restoredRoom = status.roomInfo,
                  !restoredRoom.id.isEmpty else {
                return
            }

            establishSession(
                room: restoredRoom,
                localUserID: loadedProfile.id
            )
            do {
                try await synchronizeFromServer(initial: true)
            } catch is CancellationError {
                startMonitoring()
                return
            } catch {
                connectionState = .reconnecting
            }
            startMonitoring()
        } catch is CancellationError {
            return
        } catch {
            // No active server-side session is a normal launch state.
            return
        }
    }

    private func nonEmpty(_ value: String) -> String? {
        value.isEmpty ? nil : value
    }
}
