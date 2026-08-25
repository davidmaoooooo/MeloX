import Foundation

struct ThirdPartySource: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var scriptURL: URL?
    var localFileName: String?
    var enabled: Bool
    let createdAt: Date

    var hasScript: Bool { scriptURL != nil || localFileName != nil }
}

struct ThirdPartyMusicInfo: Sendable {
    let id: Int
    let name: String
    let singer: String
    let albumName: String
    let intervalMS: Int
}
