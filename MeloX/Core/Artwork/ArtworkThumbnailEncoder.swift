import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ArtworkThumbnailEncoder {
    nonisolated static func jpegData(
        from data: Data,
        maximumPixelSize: Int = 180,
        compressionQuality: Double = 0.82
    ) -> Data? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            nil
        ) else {
            return nil
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize:
                maximumPixelSize,
        ]
        guard let thumbnail =
            CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                thumbnailOptions as CFDictionary
            )
        else {
            return nil
        }

        let output = NSMutableData()
        guard let destination =
            CGImageDestinationCreateWithData(
                output,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            )
        else {
            return nil
        }
        CGImageDestinationAddImage(
            destination,
            thumbnail,
            [
                kCGImageDestinationLossyCompressionQuality:
                    compressionQuality
            ] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return output as Data
    }
}
