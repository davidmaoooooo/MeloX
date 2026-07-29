import SwiftUI

struct PodcastProgramDetailView: View {
    let program: PodcastProgram

    @Environment(PlayerStore.self) private var player

    var body: some View {
        List {
            header

            Section("播客") {
                NavigationLink(
                    value: MusicRoute.podcast(
                        program.podcastSummary
                    )
                ) {
                    LabeledContent(
                        "来自",
                        value: program.radio.name
                    )
                }
            }

            Section("节目信息") {
                if let createTime = program.createTime {
                    LabeledContent(
                        "发布日期",
                        value: createTime.podcastDateText
                    )
                }

                if program.durationMS > 0 {
                    LabeledContent(
                        "时长",
                        value: program.durationMS.podcastDurationText
                    )
                }

                if program.listenerCount > 0 {
                    LabeledContent(
                        "播放",
                        value:
                            "\(program.listenerCount.podcastCountText) 次"
                    )
                }

                if program.likedCount > 0 {
                    LabeledContent(
                        "点赞",
                        value: program.likedCount.podcastCountText
                    )
                }

                if program.commentCount > 0 {
                    LabeledContent(
                        "评论",
                        value: program.commentCount.podcastCountText
                    )
                }
            }

            if let description = program
                .programDescription?
                .podcastNonempty {
                Section("节目简介") {
                    Text(description)
                        .textSelection(.enabled)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("节目")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        Section {
            VStack(spacing: 16) {
                ArtworkImage(
                    url: program.artworkURL,
                    cornerRadius: 14
                )
                .frame(width: 210, height: 210)
                .shadow(
                    color: .black.opacity(0.17),
                    radius: 16,
                    y: 8
                )

                Text(program.name)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                if let hostName = program.host?.nickname {
                    Text(hostName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button(action: play) {
                    Label(
                        isCurrent && player.isPlaying
                            ? "暂停"
                            : "播放节目",
                        systemImage:
                            isCurrent && player.isPlaying
                            ? "pause.fill"
                            : "play.fill"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(program.playbackSong == nil)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private var isCurrent: Bool {
        guard let song = program.playbackSong else { return false }
        return player.currentSong?.id == song.id
    }

    private func play() {
        guard let song = program.playbackSong else { return }
        if isCurrent {
            player.togglePlayback()
            return
        }

        Task {
            await player.play(
                song,
                in: [song],
                sourceID: program.radio.id
            )
        }
    }
}
