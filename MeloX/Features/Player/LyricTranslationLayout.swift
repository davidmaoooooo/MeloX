import SwiftUI

struct LyricTranslationLayout: Layout {
    var expansion: CGFloat
    let spacing: CGFloat
    let footprintScale: CGFloat

    init(
        expansion: CGFloat,
        spacing: CGFloat,
        footprintScale: CGFloat = 1
    ) {
        self.expansion = expansion
        self.spacing = spacing
        self.footprintScale = footprintScale
    }

    var animatableData: CGFloat {
        get { expansion }
        set { expansion = newValue }
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard let primaryLyric = subviews.first else {
            return .zero
        }

        let primarySize = primaryLyric.sizeThatFits(proposal)
        guard subviews.count > 1 else {
            return scaledFootprint(for: primarySize)
        }

        let translationSize = subviews[1].sizeThatFits(
            translationProposal(from: proposal)
        )
        let contentSize = CGSize(
            width: proposal.width ?? max(primarySize.width, translationSize.width),
            height: primarySize.height
                + clampedExpansion * (spacing + translationSize.height)
        )
        return scaledFootprint(for: contentSize)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard let primaryLyric = subviews.first else { return }

        let childProposal = ProposedViewSize(
            width: bounds.width,
            height: nil
        )
        let primarySize = primaryLyric.sizeThatFits(childProposal)
        primaryLyric.place(
            at: bounds.origin,
            anchor: .topLeading,
            proposal: childProposal
        )

        guard subviews.count > 1 else { return }
        subviews[1].place(
            at: CGPoint(
                x: bounds.minX,
                y: bounds.minY + primarySize.height + spacing
            ),
            anchor: .topLeading,
            proposal: childProposal
        )
    }

    private var clampedExpansion: CGFloat {
        min(max(expansion, 0), 1)
    }

    private var clampedFootprintScale: CGFloat {
        guard footprintScale.isFinite else { return 1 }
        return max(footprintScale, 0)
    }

    private func scaledFootprint(for size: CGSize) -> CGSize {
        // Child placement keeps its measured size so content can be rendered
        // from promoted metrics; only the height reported to the parent is
        // normalized back to the unpromoted layout footprint.
        CGSize(
            width: size.width,
            height: size.height * clampedFootprintScale
        )
    }

    private func translationProposal(
        from proposal: ProposedViewSize
    ) -> ProposedViewSize {
        ProposedViewSize(
            width: proposal.width,
            height: nil
        )
    }
}
