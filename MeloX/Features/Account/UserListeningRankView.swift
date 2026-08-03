import SwiftUI

struct UserListeningRankView: View {
    let userID: Int

    @Environment(NeteaseAPI.self) private var api
    @Environment(PlayerStore.self) private var player

    @State private var selectedPeriod = UserPlayRecordPeriod.week
    @State private var recordsByPeriod:
        [UserPlayRecordPeriod: [UserPlayRecord]] = [:]
    @State private var phasesByPeriod:
        [UserPlayRecordPeriod: LoadingPhase] = [:]
    @State private var refreshErrorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Picker("排行周期", selection: $selectedPeriod) {
                ForEach(UserPlayRecordPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            content
        }
        .navigationTitle("我的听歌排行")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: selectedPeriod) {
            await load(period: selectedPeriod)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task {
                        await load(period: selectedPeriod, force: true)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(currentPhase == .loading)
                .accessibilityLabel("刷新听歌排行")
            }
        }
        .alert(
            "无法更新听歌排行",
            isPresented: Binding(
                get: { refreshErrorMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        refreshErrorMessage = nil
                    }
                }
            )
        ) {
            Button("好", role: .cancel) {
                refreshErrorMessage = nil
            }
        } message: {
            Text(refreshErrorMessage ?? "请稍后重试。")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch currentPhase {
        case .loading:
            ProgressView("正在载入听歌排行")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            ConnectionUnavailableView(message: message) {
                Task {
                    await load(period: selectedPeriod, force: true)
                }
            }
        case .loaded:
            loadedContent
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if currentRecords.isEmpty {
            ContentUnavailableView(
                "暂无听歌排行",
                systemImage: "chart.bar.xaxis",
                description: Text(selectedPeriod.emptyDescription)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                Section {
                    Button {
                        Task { await player.playAll(currentSongs) }
                    } label: {
                        Label("播放全部", systemImage: "play.fill")
                    }
                } footer: {
                    Text(selectedPeriod.description)
                }

                ForEach(Array(currentRecords.enumerated()), id: \.element.song.id) {
                    index,
                    record in
                    Button {
                        Task {
                            await player.play(record.song, in: currentSongs)
                        }
                    } label: {
                        TrackRowView(
                            song: record.song,
                            index: index,
                            secondaryMetadata:
                                "播放 \(record.playCount.formatted()) 次"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.plain)
            .refreshable {
                await load(period: selectedPeriod, force: true)
            }
        }
    }

    private var currentRecords: [UserPlayRecord] {
        recordsByPeriod[selectedPeriod] ?? []
    }

    private var currentSongs: [Song] {
        currentRecords.map(\.song)
    }

    private var currentPhase: LoadingPhase {
        phasesByPeriod[selectedPeriod] ?? .loading
    }

    private func load(
        period: UserPlayRecordPeriod,
        force: Bool = false
    ) async {
        if !force, recordsByPeriod[period] != nil {
            phasesByPeriod[period] = .loaded
            return
        }

        let hasCachedRecords = recordsByPeriod[period] != nil
        if !hasCachedRecords {
            phasesByPeriod[period] = .loading
        }

        do {
            let records = try await api.userPlayRecords(
                userID: userID,
                period: period
            )
            try Task.checkCancellation()
            recordsByPeriod[period] = records
            phasesByPeriod[period] = .loaded
        } catch is CancellationError {
            return
        } catch {
            if hasCachedRecords {
                phasesByPeriod[period] = .loaded
                refreshErrorMessage = error.localizedDescription
            } else {
                phasesByPeriod[period] = .failed(
                    error.localizedDescription
                )
            }
        }
    }
}

private extension UserPlayRecordPeriod {
    var title: String {
        switch self {
        case .week:
            "最近一周"
        case .allTime:
            "所有时间"
        }
    }

    var description: String {
        switch self {
        case .week:
            "按最近一周的播放次数排序"
        case .allTime:
            "按账号全部听歌记录的播放次数排序"
        }
    }

    var emptyDescription: String {
        switch self {
        case .week:
            "最近一周还没有可显示的听歌记录。"
        case .allTime:
            "当前账号还没有可显示的听歌记录。"
        }
    }
}
