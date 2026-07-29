import SwiftUI

enum HomeQuickAction: String, CaseIterable, Identifiable {
    case dailySongs
    case hotSongs
    case heartMode
    case privateRadar
    case privateRoaming
    case similarSongs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dailySongs:
            "每日推荐"
        case .hotSongs:
            "热歌榜"
        case .heartMode:
            "心动模式"
        case .privateRadar:
            "私人雷达"
        case .privateRoaming:
            "私人漫游"
        case .similarSongs:
            "相似歌曲"
        }
    }

    var systemImage: String {
        switch self {
        case .dailySongs:
            "calendar"
        case .hotSongs:
            "flame.fill"
        case .heartMode:
            "heart.fill"
        case .privateRadar:
            "dot.radiowaves.left.and.right"
        case .privateRoaming:
            "figure.walk.motion"
        case .similarSongs:
            "music.note.list"
        }
    }

    var eyebrow: String {
        switch self {
        case .dailySongs:
            "每日更新"
        case .hotSongs:
            "全站热门"
        case .heartMode:
            "为你心动"
        case .privateRadar:
            "持续发现"
        case .privateRoaming:
            "探索模式"
        case .similarSongs:
            "从当前歌曲出发"
        }
    }

    var subtitle: String {
        switch self {
        case .dailySongs:
            "为你定制的歌曲"
        case .hotSongs:
            "大家都在听"
        case .heartMode:
            "喜欢与惊喜交替播放"
        case .privateRadar:
            "发现符合你口味的歌单"
        case .privateRoaming:
            "漫游到新的好音乐"
        case .similarSongs:
            "播放更多相似歌曲"
        }
    }

    var colors: [Color] {
        switch self {
        case .dailySongs:
            [.pink, .red]
        case .hotSongs:
            [.orange, .red]
        case .heartMode:
            [.pink, .purple]
        case .privateRadar:
            [.indigo, .purple]
        case .privateRoaming:
            [.cyan, .blue]
        case .similarSongs:
            [.mint, .teal]
        }
    }
}

struct HomeQuickActionsView: View {
    let activeAction: HomeQuickAction?
    let perform: (HomeQuickAction) -> Void

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 16) {
                ForEach(HomeQuickAction.allCases) { action in
                    Button {
                        perform(action)
                    } label: {
                        HomeEditorialCard(
                            eyebrow: action.eyebrow,
                            title: action.title,
                            subtitle: action.subtitle,
                            systemImage: action.systemImage,
                            colors: action.colors
                        )
                        .overlay {
                            if activeAction == action {
                                ProgressView()
                                    .controlSize(.large)
                                    .padding(22)
                                    .background(.regularMaterial)
                                    .clipShape(.circle)
                            }
                        }
                    }
                    .containerRelativeFrame(.horizontal) {
                        length, _ in
                        length * 0.86
                    }
                    .buttonStyle(.plain)
                    .disabled(activeAction != nil)
                    .accessibilityHint(accessibilityHint(for: action))
                }
            }
            .scrollTargetLayout()
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
    }

    private func accessibilityHint(
        for action: HomeQuickAction
    ) -> String {
        switch action {
        case .dailySongs, .hotSongs, .privateRadar:
            "打开\(action.title)"
        case .heartMode, .privateRoaming, .similarSongs:
            "开始播放\(action.title)"
        }
    }
}
