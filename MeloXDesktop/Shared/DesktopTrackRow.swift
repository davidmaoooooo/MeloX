import SwiftUI

struct DesktopTrackRow: View {
    @Environment(DesktopAppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let song: Song
    let index: Int
    let songs: [Song]
    var sourceID: Int?
    var showsArtwork = false
    var showsAlbumColumn = true
    var displayNumber: String?

    @State private var isHovered = false

    private var isCurrent: Bool {
        model.player.currentSong?.id == song.id
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    await model.player.play(
                        song,
                        in: songs,
                        sourceID: sourceID
                    )
                }
            } label: {
                ZStack {
                    if isHovered || isCurrent {
                        Image(
                            systemName: isCurrent && model.player.isPlaying
                                ? "waveform"
                                : "play.fill"
                        )
                        .foregroundStyle(isCurrent ? .red : .primary)
                    } else {
                        Text(displayNumber ?? "\(index + 1)")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 24)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.14),
                    value: isHovered
                )
            }
            .buttonStyle(.plain)
            .help("播放\(song.name)")

            if showsArtwork {
                DesktopArtworkView(url: song.album?.artworkURL, cornerRadius: 6)
                    .frame(width: 42, height: 42)
                    .scaleEffect(isHovered ? 1.025 : 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(song.name)
                    .font(.system(size: 13.5, weight: isCurrent ? .semibold : .regular))
                    .foregroundStyle(isCurrent ? .red : .primary)
                    .lineLimit(1)
                Text(song.artistText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if !showsArtwork, showsAlbumColumn {
                Text(song.album?.name ?? "")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 180, alignment: .leading)
            }

            Text(song.durationText)
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)

            songMenu
                .opacity(isHovered || isCurrent ? 1 : 0.16)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: showsArtwork ? 54 : 46)
        .background(
            isHovered ? Color.primary.opacity(0.045) : .clear,
            in: .rect(cornerRadius: 8)
        )
        .contentShape(.rect)
        .onHover { isHovered = $0 }
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.16),
            value: isHovered
        )
        .onTapGesture(count: 2) {
            Task {
                await model.player.play(song, in: songs, sourceID: sourceID)
            }
        }
        .contextMenu { songMenuContent }
    }

    private var songMenu: some View {
        Menu {
            songMenuContent
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 28, height: 28)
                .contentShape(.circle)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }

    @ViewBuilder
    private var songMenuContent: some View {
        Button("接下来播放", systemImage: "text.line.first.and.arrowtriangle.forward") {
            Task { await model.player.playNext(song) }
        }
        Button("添加到播放队列", systemImage: "text.badge.plus") {
            model.player.addToPlaybackQueue(song)
        }

        Menu("添加到播放列表", systemImage: "text.badge.plus") {
            if model.library.favoritePlaylists.isEmpty {
                Text("暂无可用播放列表")
            } else {
                ForEach(model.library.favoritePlaylists) { playlist in
                    Button(playlist.name) {
                        Task { try? await model.library.add(song: song, to: playlist) }
                    }
                }
            }
        }

        Divider()
        Button(
            model.library.contains(song: song) ? "取消喜欢" : "喜欢",
            systemImage: model.library.contains(song: song) ? "star.fill" : "star"
        ) {
            model.library.toggle(song: song)
        }
        Button("下载", systemImage: "arrow.down.circle") {
            model.downloads.start(song, quality: model.settings.quality)
        }

        Divider()
        Button("查看歌曲信息", systemImage: "info.circle") {
            model.ui.navigate(to: .song(song.id))
        }
        if let artist = song.artists.first {
            Button("前往艺人", systemImage: "music.mic") {
                model.ui.navigate(to: .artist(artist.id))
            }
        }
        if let album = song.album {
            Button("前往专辑", systemImage: "square.stack") {
                model.ui.navigate(to: .album(album.id))
            }
        }

        if let url = URL(string: "https://music.163.com/#/song?id=\(song.id)") {
            ShareLink(item: url) {
                Label("分享", systemImage: "square.and.arrow.up")
            }
        }
    }
}
