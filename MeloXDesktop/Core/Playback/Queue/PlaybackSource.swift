import Foundation

struct PlaybackSource: Equatable, Sendable {
    let url: URL
    let bitrate: Int?
    let format: String?
    let quality: MusicQuality?
    let httpHeaders: [String: String]

    init(
        url: URL,
        bitrate: Int?,
        format: String?,
        quality: MusicQuality? = nil,
        httpHeaders: [String: String] = [:]
    ) {
        self.url = url
        self.bitrate = bitrate
        self.format = format
        self.quality = quality
        self.httpHeaders = httpHeaders
    }

    var preferredForwardBufferDuration: TimeInterval {
        guard !url.isFileURL else { return 0 }
        if quality?.prefersExtendedBuffering == true
            || (bitrate ?? 0) >= 1_000_000 {
            return 16
        }
        return 8
    }
}
