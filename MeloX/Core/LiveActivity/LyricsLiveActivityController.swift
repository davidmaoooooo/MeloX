import ActivityKit
import Foundation
import OSLog

struct LyricsLiveActivitySnapshot: Equatable {
    let songID: Int
    let title: String
    let subtitle: String
    let compactText: String
    let compactScrollDistance: Double
    let nextLyric: String?
    let artworkURL: URL?
    let presentation: LyricsLiveActivityPresentation
    let isPlaying: Bool
    let playbackPosition: TimeInterval
    let duration: TimeInterval
    let staleDate: Date?

    func contentState(
        artworkFileName: String?
    ) -> LyricsLiveActivityAttributes.ContentState {
        let safeDuration = max(duration, 0)
        let safePosition = safeDuration > 0
            ? min(max(playbackPosition, 0), safeDuration)
            : max(playbackPosition, 0)
        return LyricsLiveActivityAttributes.ContentState(
            title: limited(title),
            subtitle: limited(subtitle),
            compactText: limited(compactText),
            compactScrollOffset:
                LyricsLiveActivityCompactLayout.characterOffset(
                    text: compactText,
                    pointSize:
                        presentation.compactTextSize.pointSize,
                    travelDistance: compactScrollDistance
                ),
            compactScrollDistance: compactScrollDistance,
            nextLyric: nextLyric.map(limited),
            artworkFileName: artworkFileName,
            artworkURL: artworkURL,
            presentation: presentation,
            isPlaying: isPlaying,
            playbackPosition: safePosition,
            duration: safeDuration,
            updatedAt: .now
        )
    }

    private func limited(_ value: String) -> String {
        String(value.prefix(280))
    }
}

@MainActor
final class LyricsLiveActivityController {
    private static let failedRequestRetryInterval: TimeInterval = 10
    private static let logger = Logger(
        subsystem: "moye.MeloX",
        category: "LyricsLiveActivity"
    )

    private enum PendingCommand {
        case synchronize(LyricsLiveActivitySnapshot?)
    }

    private var currentActivity:
        Activity<LyricsLiveActivityAttributes>?
    private var pendingCommand: PendingCommand?
    private var isSynchronizing = false
    private var lastFailedRequestDate: Date?
    private var latestSnapshot: LyricsLiveActivitySnapshot?
    private let artworkStore = LyricsLiveActivityArtworkStore()

    init() {
        currentActivity =
            Activity<LyricsLiveActivityAttributes>.activities.first
    }

    func synchronize(with snapshot: LyricsLiveActivitySnapshot?) {
        latestSnapshot = snapshot
        pendingCommand = .synchronize(snapshot)
        guard !isSynchronizing else { return }

        isSynchronizing = true
        Task { @MainActor [weak self] in
            await self?.drainPendingCommands()
        }
    }

    private func drainPendingCommands() async {
        while let command = pendingCommand {
            pendingCommand = nil
            switch command {
            case .synchronize(let snapshot):
                await apply(snapshot)
            }
        }
        isSynchronizing = false
    }

    private func apply(
        _ snapshot: LyricsLiveActivitySnapshot?
    ) async {
        guard let snapshot else {
            await endAllActivities()
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            Self.logger.notice(
                "Live Activities are disabled by system authorization"
            )
            return
        }

        let artworkFileName = snapshot.presentation.showsArtwork
            ? artworkStore.cachedFileName(
                songID: snapshot.songID,
                url: snapshot.artworkURL
            )
            : nil
        let content = ActivityContent(
            state: snapshot.contentState(
                artworkFileName: artworkFileName
            ),
            staleDate: snapshot.staleDate,
            relevanceScore: 100
        )
        let activities = Activity<
            LyricsLiveActivityAttributes
        >.activities.filter(isUsable)

        if let activity = activities.first
            ?? usableCurrentActivity {
            currentActivity = activity
            lastFailedRequestDate = nil
            await activity.update(content)
            guard isUsable(activity) else {
                currentActivity = nil
                await requestActivity(
                    content: content,
                    snapshot: snapshot,
                    artworkFileName: artworkFileName
                )
                return
            }

            for duplicate in activities.dropFirst() {
                await duplicate.end(
                    nil,
                    dismissalPolicy: .immediate
                )
            }
            prepareArtworkIfNeeded(
                for: snapshot,
                currentFileName: artworkFileName
            )
            return
        }

        currentActivity = nil
        await requestActivity(
            content: content,
            snapshot: snapshot,
            artworkFileName: artworkFileName
        )
    }

    private func requestActivity(
        content: ActivityContent<
            LyricsLiveActivityAttributes.ContentState
        >,
        snapshot: LyricsLiveActivitySnapshot,
        artworkFileName: String?
    ) async {
        guard canAttemptActivityRequest() else { return }

        do {
            let activity = try Activity.request(
                attributes: LyricsLiveActivityAttributes(
                    sessionID: UUID()
                ),
                content: content,
                pushType: nil,
                style: .standard
            )
            currentActivity = activity
            lastFailedRequestDate = nil
            Self.logger.notice(
                "Started Live Activity \(activity.id, privacy: .public)"
            )
            prepareArtworkIfNeeded(
                for: snapshot,
                currentFileName: artworkFileName
            )
        } catch {
            currentActivity = nil
            lastFailedRequestDate = .now
            Self.logger.error(
                "Failed to start Live Activity: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func prepareArtworkIfNeeded(
        for snapshot: LyricsLiveActivitySnapshot,
        currentFileName: String?
    ) {
        guard snapshot.presentation.showsArtwork,
              currentFileName == nil else { return }
        artworkStore.prepare(
            songID: snapshot.songID,
            url: snapshot.artworkURL
        ) { [weak self] _ in
            guard let self,
                  let latestSnapshot = self.latestSnapshot,
                  latestSnapshot.songID == snapshot.songID,
                  latestSnapshot.artworkURL == snapshot.artworkURL
            else {
                return
            }
            self.synchronize(with: latestSnapshot)
        }
    }

    private func endAllActivities() async {
        let activities =
            Activity<LyricsLiveActivityAttributes>.activities
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
        lastFailedRequestDate = nil
    }

    private func canAttemptActivityRequest(
        at date: Date = .now
    ) -> Bool {
        guard let lastFailedRequestDate else { return true }
        return date.timeIntervalSince(lastFailedRequestDate)
            >= Self.failedRequestRetryInterval
    }

    private var usableCurrentActivity:
        Activity<LyricsLiveActivityAttributes>? {
        guard let currentActivity else { return nil }
        return isUsable(currentActivity)
            ? currentActivity
            : nil
    }

    private func isUsable(
        _ activity: Activity<LyricsLiveActivityAttributes>
    ) -> Bool {
        switch activity.activityState {
        case .pending, .active, .stale:
            return true
        case .ended, .dismissed:
            return false
        @unknown default:
            return false
        }
    }
}
