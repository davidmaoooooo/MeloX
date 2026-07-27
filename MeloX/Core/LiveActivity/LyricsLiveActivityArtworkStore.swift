import CryptoKit
import Foundation

@MainActor
final class LyricsLiveActivityArtworkStore {
    private struct Request: Equatable {
        let songID: Int
        let url: URL
    }

    private var request: Request?
    private var failedRequest: Request?
    private var task: Task<Void, Never>?

    func cachedFileName(songID: Int, url: URL?) -> String? {
        guard let url else { return nil }
        let fileName = fileName(songID: songID, url: url)
        guard let fileURL =
            LyricsLiveActivitySharedStorage.artworkURL(
                for: fileName
            ),
            FileManager.default.fileExists(atPath: fileURL.path)
        else {
            return nil
        }
        return fileName
    }

    func prepare(
        songID: Int,
        url: URL?,
        completion: @escaping @MainActor (String) -> Void
    ) {
        guard let url else { return }
        let newRequest = Request(songID: songID, url: url)
        guard newRequest != failedRequest else { return }

        if cachedFileName(songID: songID, url: url) != nil {
            return
        }
        guard request != newRequest || task == nil else { return }

        task?.cancel()
        request = newRequest
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let (data, response) =
                    try await URLSession.shared.data(from: url)
                try Task.checkCancellation()
                if let response = response as? HTTPURLResponse {
                    guard (200..<300).contains(response.statusCode) else {
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
                guard let jpegData,
                      let destination = destinationURL(
                        songID: songID,
                        url: url
                      )
                else {
                    throw URLError(.cannotDecodeContentData)
                }

                try jpegData.write(
                    to: destination,
                    options: .atomic
                )
                try Task.checkCancellation()
                cleanArtworkDirectory(keeping: destination)
                request = nil
                task = nil
                completion(destination.lastPathComponent)
            } catch is CancellationError {
                return
            } catch {
                failedRequest = newRequest
                request = nil
                task = nil
            }
        }
    }

    private func destinationURL(
        songID: Int,
        url: URL
    ) -> URL? {
        let fileName = fileName(songID: songID, url: url)
        guard let destination =
            LyricsLiveActivitySharedStorage.artworkURL(
                for: fileName
            )
        else {
            return nil
        }
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            return destination
        } catch {
            return nil
        }
    }

    private func fileName(songID: Int, url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let suffix = digest.prefix(8).map {
            String(format: "%02x", $0)
        }
        .joined()
        return "\(songID)-\(suffix).jpg"
    }

    private func cleanArtworkDirectory(keeping retainedURL: URL) {
        let directory = retainedURL.deletingLastPathComponent()
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ) else {
            return
        }
        for file in files where file != retainedURL {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
