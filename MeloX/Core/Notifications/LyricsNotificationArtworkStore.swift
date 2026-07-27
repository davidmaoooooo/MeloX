import CryptoKit
import Foundation
import UserNotifications

@MainActor
final class LyricsNotificationArtworkStore {
    private struct Request: Equatable {
        let songID: Int
        let url: URL
    }

    private var request: Request?
    private var failedRequest: Request?
    private var task: Task<Void, Never>?

    deinit {
        task?.cancel()
    }

    func prepare(songID: Int, url: URL?) {
        guard let url else {
            cancelPreparation()
            return
        }

        let newRequest = Request(songID: songID, url: url)
        if cachedURL(songID: songID, url: url) != nil {
            if request != newRequest {
                cancelPreparation()
            }
            failedRequest = nil
            return
        }
        guard newRequest != failedRequest,
              request != newRequest || task == nil else {
            return
        }

        task?.cancel()
        request = newRequest
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let (data, response) =
                    try await URLSession.shared.data(from: url)
                try Task.checkCancellation()
                if let response = response as? HTTPURLResponse {
                    guard (200..<300).contains(
                        response.statusCode
                    ) else {
                        throw URLError(.badServerResponse)
                    }
                }

                let jpegData = await Task.detached(
                    priority: .utility
                ) {
                    ArtworkThumbnailEncoder.jpegData(
                        from: data
                    )
                }.value
                try Task.checkCancellation()
                guard let jpegData,
                      let destination = destinationURL(
                        songID: songID,
                        url: url
                      )
                else {
                    throw URLError(
                        .cannotDecodeContentData
                    )
                }

                try jpegData.write(
                    to: destination,
                    options: .atomic
                )
                try Task.checkCancellation()
                guard request == newRequest else { return }

                cleanArtworkDirectory(
                    keeping: destination
                )
                failedRequest = nil
                request = nil
                task = nil
            } catch is CancellationError {
                guard request == newRequest else { return }
                request = nil
                task = nil
                return
            } catch {
                guard request == newRequest else { return }
                failedRequest = newRequest
                request = nil
                task = nil
            }
        }
    }

    func attachment(
        songID: Int,
        url: URL?
    ) async -> UNNotificationAttachment? {
        guard let url else {
            return nil
        }

        let expectedRequest = Request(
            songID: songID,
            url: url
        )
        prepare(songID: songID, url: url)

        if request == expectedRequest,
           let task {
            await task.value
        }
        guard !Task.isCancelled,
              let fileURL = cachedURL(
                songID: songID,
                url: url
              )
        else {
            return nil
        }
        return try? UNNotificationAttachment(
            identifier:
                LyricsNotificationConstants
                    .artworkAttachmentID,
            url: fileURL
        )
    }

    func cancelPreparation() {
        task?.cancel()
        task = nil
        request = nil
    }

    private func cachedURL(
        songID: Int,
        url: URL
    ) -> URL? {
        guard let destination = destinationURL(
            songID: songID,
            url: url
        ),
            FileManager.default.fileExists(
                atPath: destination.path
            )
        else {
            return nil
        }
        return destination
    }

    private func destinationURL(
        songID: Int,
        url: URL
    ) -> URL? {
        guard let cacheDirectory =
            FileManager.default.urls(
                for: .cachesDirectory,
                in: .userDomainMask
            ).first
        else {
            return nil
        }

        let directory = cacheDirectory.appending(
            path: "LyricsNotificationArtwork",
            directoryHint: .isDirectory
        )
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory.appending(
                path: fileName(
                    songID: songID,
                    url: url
                ),
                directoryHint: .notDirectory
            )
        } catch {
            return nil
        }
    }

    private func fileName(
        songID: Int,
        url: URL
    ) -> String {
        let digest = SHA256.hash(
            data: Data(url.absoluteString.utf8)
        )
        let suffix = digest.prefix(8).map {
            String(format: "%02x", $0)
        }
        .joined()
        return "\(songID)-\(suffix).jpg"
    }

    private func cleanArtworkDirectory(
        keeping retainedURL: URL
    ) {
        let directory =
            retainedURL.deletingLastPathComponent()
        guard let files =
            try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            )
        else {
            return
        }
        for file in files where file != retainedURL {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
