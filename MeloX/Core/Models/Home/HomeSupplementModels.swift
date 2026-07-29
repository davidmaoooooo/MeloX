import Foundation

enum HomeMusicRegion: String {
    case all = "ALL"
    case chinese = "ZH"
    case western = "EA"
    case korean = "KR"
    case japanese = "JP"

    init(settingValue: String) {
        self = HomeMusicRegion(rawValue: settingValue) ?? .all
    }

    var areaID: Int {
        switch self {
        case .all:
            0
        case .chinese:
            7
        case .western:
            96
        case .korean:
            16
        case .japanese:
            8
        }
    }

    var title: String {
        switch self {
        case .all:
            "全部地区"
        case .chinese:
            "华语地区"
        case .western:
            "欧美地区"
        case .korean:
            "韩国地区"
        case .japanese:
            "日本地区"
        }
    }
}

struct HomeTopSongsResponse: Decodable {
    let code: Int
    let data: [Song]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, data, message, msg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(
            Int.self,
            forKey: .code
        ) ?? 200
        data = try container.decodeIfPresent(
            [Song].self,
            forKey: .data
        ) ?? []
        message =
            try container.decodeIfPresent(
                String.self,
                forKey: .message
            )
            ?? container.decodeIfPresent(
                String.self,
                forKey: .msg
            )
    }
}

struct HomePersonalizedNewSongsResponse: Decodable {
    let code: Int
    let result: [HomePersonalizedNewSong]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, result, message, msg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(
            Int.self,
            forKey: .code
        ) ?? 200
        result = try container.decodeIfPresent(
            [HomePersonalizedNewSong].self,
            forKey: .result
        ) ?? []
        message =
            try container.decodeIfPresent(
                String.self,
                forKey: .message
            )
            ?? container.decodeIfPresent(
                String.self,
                forKey: .msg
            )
    }
}

struct HomePersonalizedNewSong: Decodable {
    let song: Song?
}

struct HomeRecommendedProgramsResponse: Decodable {
    let code: Int
    let programs: [PodcastProgram]
    let message: String?

    enum CodingKeys: String, CodingKey {
        case code, programs, message, msg
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decodeIfPresent(
            Int.self,
            forKey: .code
        ) ?? 200
        programs = try container.decodeIfPresent(
            [PodcastProgram].self,
            forKey: .programs
        ) ?? []
        message =
            try container.decodeIfPresent(
                String.self,
                forKey: .message
            )
            ?? container.decodeIfPresent(
                String.self,
                forKey: .msg
            )
    }
}
