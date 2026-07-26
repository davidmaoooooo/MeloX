import SwiftUI

struct NowPlayingLyricsTranslationButton: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        Menu {
            Picker(
                "翻译显示方式",
                selection: translationSelection
            ) {
                ForEach(
                    NowPlayingLyricsTranslationSelection.allCases
                ) { selection in
                    Text(selection.title)
                        .tag(selection)
                }
            }
        } label: {
            Image(systemName: "translate")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    .white.opacity(
                        settings.lyricsTranslationEnabled
                            ? 0.18
                            : 0.1
                    ),
                    in: .circle
                )
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("翻译歌词")
        .accessibilityValue(currentSelection.title)
        .accessibilityHint("选择仅显示当前句、显示所有句或不显示翻译")
    }

    private var currentSelection:
        NowPlayingLyricsTranslationSelection {
        guard settings.lyricsTranslationEnabled else {
            return .hidden
        }

        switch settings.lyricsTranslationDisplayMode {
        case .focusedLine:
            return .focusedLine
        case .allLines:
            return .allLines
        }
    }

    private var translationSelection:
        Binding<NowPlayingLyricsTranslationSelection> {
        Binding(
            get: { currentSelection },
            set: { selection in
                switch selection {
                case .hidden:
                    settings.lyricsTranslationEnabled = false
                case .focusedLine:
                    settings.lyricsTranslationDisplayMode = .focusedLine
                    settings.lyricsTranslationEnabled = true
                case .allLines:
                    settings.lyricsTranslationDisplayMode = .allLines
                    settings.lyricsTranslationEnabled = true
                }
            }
        )
    }
}

private enum NowPlayingLyricsTranslationSelection:
    String,
    CaseIterable,
    Identifiable {
    case focusedLine
    case allLines
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focusedLine:
            "仅显示当前句"
        case .allLines:
            "显示所有句"
        case .hidden:
            "不显示翻译"
        }
    }
}
