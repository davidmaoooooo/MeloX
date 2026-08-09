import SwiftUI

struct DesktopLyricsSettingsView: View {
    @State private var page: Page = .appearance

    var body: some View {
        VStack(spacing: 0) {
            Picker("歌词设置分类", selection: $page) {
                ForEach(Page.allCases) { page in
                    Text(page.title).tag(page)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(maxWidth: 520)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 6)

            Group {
                switch page {
                case .appearance:
                    DesktopLyricsAppearanceSettingsView()
                case .content:
                    DesktopLyricsContentSettingsView()
                case .interaction:
                    DesktopLyricsInteractionSettingsView()
                case .animation:
                    DesktopLyricsAnimationSettingsView()
                case .extensions:
                    DesktopLyricsExtensionsSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private enum Page: String, CaseIterable, Identifiable {
        case appearance
        case content
        case interaction
        case animation
        case extensions

        var id: String { rawValue }

        var title: String {
            switch self {
            case .appearance: "排版"
            case .content: "内容"
            case .interaction: "交互"
            case .animation: "动画"
            case .extensions: "扩展"
            }
        }
    }
}
