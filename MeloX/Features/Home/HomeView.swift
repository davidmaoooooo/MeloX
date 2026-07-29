import SwiftUI

private enum HomeSection: String, CaseIterable, Identifiable {
    case recommended
    case music
    case podcasts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended:
            "推荐"
        case .music:
            "音乐"
        case .podcasts:
            "播客"
        }
    }
}

struct HomeView: View {
    @State private var section = HomeSection.recommended

    var body: some View {
        VStack(spacing: 0) {
            Picker("首页板块", selection: $section) {
                ForEach(HomeSection.allCases) { section in
                    Text(section.title)
                        .tag(section)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.background)

            sectionContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle("首页")
        .navigationBarTitleDisplayMode(.large)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch section {
        case .recommended:
            HomeRecommendedView()
        case .music:
            ExploreView(showsNavigationTitle: false)
        case .podcasts:
            PodcastHomeView(showsNavigationTitle: false)
        }
    }
}
