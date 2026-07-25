import Foundation

enum LyricsLiveActivitySharedStorage {
    static let appGroupIdentifier = "group.moye.MeloX"
    static let artworkDirectoryName = "LyricsLiveActivityArtwork"

    static func artworkURL(for fileName: String) -> URL? {
        FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        )?
        .appendingPathComponent(
            artworkDirectoryName,
            isDirectory: true
        )
        .appendingPathComponent(fileName, isDirectory: false)
    }
}
