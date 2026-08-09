import SwiftUI

struct DesktopArtworkView: View {
    let url: URL?
    var cornerRadius: CGFloat = 10
    var contentMode: ContentMode = .fill

    var body: some View {
        AsyncImage(url: url, transaction: Transaction(animation: .easeInOut)) {
            phase in
            switch phase {
            case .empty:
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary.opacity(0.35))
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                Image("MeloXLogo")
                    .resizable()
                    .scaledToFit()
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.quaternary.opacity(0.35))
            @unknown default:
                EmptyView()
            }
        }
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
    }
}

struct DesktopCircularArtworkView: View {
    let url: URL?

    var body: some View {
        DesktopArtworkView(url: url, cornerRadius: 10_000)
            .clipShape(.circle)
    }
}
