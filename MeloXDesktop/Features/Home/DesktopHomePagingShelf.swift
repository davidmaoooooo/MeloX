import SwiftUI

/// A native horizontal shelf that advances by the items currently visible in
/// its viewport. The cards remain one real scrollable sequence; the button is
/// only a paging affordance for that sequence.
struct DesktopHomePagingShelf<Item: Identifiable, Card: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let items: [Item]
    let cardWidth: CGFloat
    let spacing: CGFloat
    let visibleItemCount: Int
    let trailingOverlayInset: CGFloat
    private let card: (Item) -> Card

    @State private var leadingIndex = 0
    @State private var isShelfHovered = false

    init(
        items: [Item],
        cardWidth: CGFloat,
        spacing: CGFloat,
        visibleItemCount: Int,
        trailingOverlayInset: CGFloat,
        @ViewBuilder card: @escaping (Item) -> Card
    ) {
        self.items = items
        self.cardWidth = cardWidth
        self.spacing = spacing
        self.visibleItemCount = visibleItemCount
        self.trailingOverlayInset = trailingOverlayInset
        self.card = card
    }

    var body: some View {
        ScrollViewReader { proxy in
            ZStack {
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: spacing) {
                        ForEach(items) { item in
                            card(item)
                                .frame(width: cardWidth)
                                .clipped()
                                .id(item.id)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .clipped()
                .onChange(of: items.map(\.id), initial: true) { _, _ in
                    let clampedIndex = min(leadingIndex, lastPageStart)
                    guard clampedIndex != leadingIndex else { return }
                    leadingIndex = clampedIndex
                }

                HStack(spacing: 0) {
                    pageButton(
                        systemImage: "chevron.left",
                        title: "上一页",
                        isAvailable: canRetreat
                    ) {
                        page(-1, proxy: proxy)
                    }
                    .padding(.leading, 8)

                    Spacer(minLength: 0)

                    pageButton(
                        systemImage: "chevron.right",
                        title: "下一页",
                        isAvailable: canAdvance
                    ) {
                        page(1, proxy: proxy)
                    }
                    .padding(
                        .trailing,
                        trailingOverlayInset + 8
                    )
                }
            }
            .contentShape(.rect)
            .onHover { isShelfHovered = $0 }
        }
    }

    private func pageButton(
        systemImage: String,
        title: String,
        isAvailable: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let isVisible = isShelfHovered && isAvailable

        return Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 44)
                .background(.regularMaterial, in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(.white.opacity(0.34), lineWidth: 0.7)
                }
                .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
        .disabled(!isAvailable)
        .opacity(isVisible ? 1 : 0)
        .allowsHitTesting(isVisible)
        .accessibilityHidden(!isAvailable)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.18),
            value: isVisible
        )
    }

    private var canAdvance: Bool {
        leadingIndex < lastPageStart
    }

    private var canRetreat: Bool {
        leadingIndex > 0
    }

    private var pageSize: Int {
        max(visibleItemCount, 1)
    }

    private var lastPageStart: Int {
        max(items.count - pageSize, 0)
    }

    private func page(_ direction: Int, proxy: ScrollViewProxy) {
        guard !items.isEmpty else { return }

        let targetIndex: Int
        if direction < 0 {
            targetIndex = max(
                ((max(leadingIndex - 1, 0)) / pageSize) * pageSize,
                0
            )
        } else {
            targetIndex = min(
                ((leadingIndex / pageSize) + 1) * pageSize,
                lastPageStart
            )
        }

        withAnimation(
            reduceMotion
                ? nil
                : DesktopMainWindowMetrics.presentationAnimation
        ) {
            leadingIndex = targetIndex
            proxy.scrollTo(items[targetIndex].id, anchor: .leading)
        }
    }
}
