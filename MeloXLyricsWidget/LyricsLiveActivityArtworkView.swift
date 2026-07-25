import SwiftUI
import UIKit

struct LyricsLiveActivityArtworkView: View {
    let state: LyricsLiveActivityAttributes.ContentState
    var cornerRadius: CGFloat

    var body: some View {
        Group {
            if state.presentation.showsArtwork {
                artwork
            } else {
                placeholder
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(.rect(cornerRadius: cornerRadius))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var artwork: some View {
        if let image = localImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else if let url = state.artworkURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var localImage: UIImage? {
        guard let fileName = state.artworkFileName,
              let url =
                LyricsLiveActivitySharedStorage.artworkURL(
                    for: fileName
                )
        else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.12)
            Image(systemName: "music.note")
                .foregroundStyle(.white.opacity(0.8))
        }
    }
}
