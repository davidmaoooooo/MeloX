import SwiftUI

struct DesktopSidebar: View {
    @Environment(DesktopAppModel.self) private var model

    private let primarySections: [DesktopSection] = [
        .search,
        .home,
        .discovery,
        .radio,
    ]
    private let librarySections: [DesktopSection] = [
        .songs,
        .playlists,
        .podcasts,
        .downloads,
        .cloud,
        .recent,
    ]

    var body: some View {
        @Bindable var ui = model.ui

        TabView(selection: $ui.selection) {
            ForEach(primarySections) { section in
                tab(for: section)
            }

            TabSection("音乐库") {
                ForEach(librarySections) { section in
                    tab(for: section)
                }
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tabViewSidebarBottomBar {
            DesktopSidebarAccountFooter()
        }
        .toolbar(removing: .sidebarToggle)
        .background {
            DesktopSidebarVisibilityLock()
                .frame(width: 0, height: 0)
        }
    }

    private func tab(
        for section: DesktopSection
    ) -> some TabContent<DesktopSection> {
        Tab(
            section.title,
            systemImage: section.systemImage,
            value: section
        ) {
            DesktopTabPage(section: section)
                .toolbar(removing: .sidebarToggle)
        }
    }
}

struct DesktopSidebarAccountFooter: View {
    @Environment(DesktopAppModel.self) private var model

    var body: some View {
        Button {
            model.ui.sheet = .account
        } label: {
            HStack(spacing: 9) {
                if let profile = model.library.profile {
                    DesktopCircularArtworkView(url: profile.artworkURL)
                        .frame(width: 30, height: 30)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.48, green: 0.63, blue: 0.88).gradient)
                        Text("洛")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 30, height: 30)
                }

                Text(model.library.profile?.nickname ?? "洛汐聚合体")
                    .font(.system(size: 13.5, weight: .semibold))
                    .lineLimit(1)

                Spacer(minLength: 0)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .frame(height: 50)
    }
}
