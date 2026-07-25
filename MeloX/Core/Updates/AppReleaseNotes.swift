import Foundation

struct AppReleaseNotes: Decodable, Equatable, Identifiable, Sendable {
    let schemaVersion: Int
    let version: String
    let sourceRevision: String
    let previousVersion: String?
    let entries: [String]

    var id: String {
        "\(version)-\(sourceRevision)"
    }

    var displayVersion: String {
        AppVersion.displayName(for: version)
    }

    var displayPreviousVersion: String? {
        guard let previousVersion else { return nil }
        return AppVersion.displayName(for: previousVersion)
    }
}

enum AppReleaseNotesLoader {
    static func load(from bundle: Bundle = .main) -> AppReleaseNotes? {
        guard let url = bundle.url(
            forResource: "ReleaseNotes",
            withExtension: "json"
        ),
        let data = try? Data(contentsOf: url),
        let releaseNotes = try? JSONDecoder().decode(
            AppReleaseNotes.self,
            from: data
        ),
        releaseNotes.schemaVersion == 1,
        !releaseNotes.version.isEmpty else {
            return nil
        }

        return releaseNotes
    }
}
