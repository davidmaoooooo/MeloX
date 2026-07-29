import SwiftUI

struct SongWikiSheet: View {
    @Environment(\.dismiss) private var dismiss

    let song: Song

    @Namespace private var navigationNamespace

    var body: some View {
        NavigationStack {
            SongWikiView(song: song)
                .musicDestinations(in: navigationNamespace)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .accessibilityLabel("关闭歌曲百科")
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
