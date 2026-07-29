import SwiftUI

struct SongWikiView: View {
    @Environment(NeteaseAPI.self) private var api

    let song: Song

    @State private var wiki: SongWiki?
    @State private var phase: LoadingPhase = .loading
    @State private var reloadToken = 0
    @State private var refreshErrorMessage: String?

    var body: some View {
        Group {
            switch phase {
            case .loading where wiki == nil:
                ProgressView("正在载入歌曲百科")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .failed(let message) where wiki == nil:
                ConnectionUnavailableView(message: message) {
                    reloadToken += 1
                }

            default:
                if let wiki, wiki.isEmpty {
                    ContentUnavailableView(
                        "暂无百科资料",
                        systemImage: "book.closed",
                        description: Text("这首歌曲暂时还没有可展示的百科内容。")
                    )
                } else if let wiki {
                    SongWikiContent(song: song, wiki: wiki)
                        .refreshable {
                            await load()
                        }
                }
            }
        }
        .navigationTitle("歌曲百科")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: reloadToken) {
            await load()
        }
        .alert(
            "无法更新歌曲百科",
            isPresented: Binding(
                get: { refreshErrorMessage != nil },
                set: { if !$0 { refreshErrorMessage = nil } }
            )
        ) {
            Button("好", role: .cancel) {
                refreshErrorMessage = nil
            }
        } message: {
            Text(refreshErrorMessage ?? "请稍后重试。")
        }
    }

    private func load() async {
        phase = .loading
        do {
            let loadedWiki = try await api.songWiki(id: song.id)
            try Task.checkCancellation()
            wiki = loadedWiki
            phase = .loaded
        } catch is CancellationError {
            return
        } catch {
            if wiki == nil {
                phase = .failed(error.localizedDescription)
            } else {
                phase = .loaded
                refreshErrorMessage = error.localizedDescription
            }
        }
    }
}
