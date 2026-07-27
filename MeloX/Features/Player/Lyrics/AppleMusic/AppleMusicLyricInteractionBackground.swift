import SwiftUI

struct AppleMusicLyricInteractionBackground: View {
    private static let displayedPadding: CGFloat = 16
    private static let displayedCornerRadius: CGFloat = 16
    private static let translationSpacing: CGFloat = 2
    static let visualOverflow = displayedPadding

    @Environment(AppSettings.self) private var settings

    let line: LyricLine
    let fontSize: CGFloat
    let fontWeight: LyricsFontWeight
    let showsTranslation: Bool
    let contentWidth: CGFloat
    let visualScale: CGFloat
    let opacity: Double

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: Self.translationSpacing
        ) {
            measuredText(
                line.text,
                fontSize: fontSize
            )

            if showsTranslation,
               settings.lyricsTranslationEnabled,
               let translation = line.translation {
                measuredText(
                    translation,
                    fontSize: translationFontSize
                )
            }
        }
        .foregroundStyle(.clear)
        .padding(.horizontal, unscaledPadding)
        .padding(.vertical, unscaledPadding)
        .background {
            RoundedRectangle(
                cornerRadius: unscaledCornerRadius,
                style: .continuous
            )
            .fill(.white.opacity(opacity))
        }
        .fixedSize(horizontal: true, vertical: true)
        .offset(
            x: -unscaledPadding,
            y: -unscaledPadding
        )
        .scaleEffect(
            visualScale,
            anchor: .topLeading
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func measuredText(
        _ text: String,
        fontSize: CGFloat
    ) -> some View {
        Text(verbatim: text)
            .font(
                .system(
                    size: fontSize,
                    weight: fontWeight.swiftUIWeight
                )
            )
            .multilineTextAlignment(.leading)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(
                width: max(contentWidth, 1),
                alignment: .leading
            )
    }

    private var translationFontSize: CGFloat {
        max(
            CGFloat(
                settings.lyricsFontSize
                    * settings.lyricsTranslationFontScale
            ),
            13
        )
    }

    private var effectiveVisualScale: CGFloat {
        guard visualScale.isFinite else { return 1 }
        return max(visualScale, 1)
    }

    private var unscaledPadding: CGFloat {
        Self.displayedPadding / effectiveVisualScale
    }

    private var unscaledCornerRadius: CGFloat {
        Self.displayedCornerRadius / effectiveVisualScale
    }
}
