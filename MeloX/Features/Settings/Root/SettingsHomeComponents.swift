import SwiftUI

struct SettingsHomeHeader: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 10) {
            Image("MeloXLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 34)
                .clipShape(.rect(cornerRadius: 9, style: .continuous))
                .accessibilityHidden(true)

            Text("MeloX")
                .font(.title2.weight(.bold))

            Spacer(minLength: 16)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
                    .background(.regularMaterial, in: .circle)
                    .contentShape(.circle)
            }
            .buttonStyle(.plain)
            .shadow(
                color: .black.opacity(0.08),
                radius: 18,
                y: 8
            )
            .accessibilityLabel("关闭")
            .accessibilityHint("关闭账号与设置")
        }
    }
}

struct SettingsHomeSectionCard: View {
    let section: SettingsCatalogSection
    let value: (SettingsRoute) -> String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            VStack(spacing: 0) {
                ForEach(section.items.indices, id: \.self) { index in
                    if index > section.items.startIndex {
                        Divider()
                            .padding(.leading, 58)
                    }

                    row(for: section.items[index])
                }
            }
            .background {
                RoundedRectangle(
                    cornerRadius: 26,
                    style: .continuous
                )
                .fill(
                    Color(
                        uiColor:
                            .secondarySystemGroupedBackground
                    )
                )
            }
        }
    }

    private func row(
        for item: SettingsCatalogItem
    ) -> some View {
        NavigationLink(value: item.route) {
            HStack(spacing: 14) {
                Image(systemName: item.systemImage)
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.tint)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                if let value = value(item.route) {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .frame(minHeight: 68)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct SettingsHomeResetCard: View {
    let isResetting: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还原")
                .font(.headline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)

            Button(role: .destructive, action: action) {
                HStack(spacing: 14) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.title3.weight(.medium))
                        .frame(width: 30)

                    Text("恢复播放器默认设置")
                        .font(.body.weight(.semibold))

                    Spacer(minLength: 8)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .frame(minHeight: 60)
                .contentShape(.rect)
                .background {
                    RoundedRectangle(
                        cornerRadius: 26,
                        style: .continuous
                    )
                    .fill(
                        Color(
                            uiColor:
                                .secondarySystemGroupedBackground
                        )
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(isResetting)

            Text("重置播放、歌词、均衡器、自动混音和扩展歌词显示，不会删除账号、下载或音乐数据。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 14)
        }
    }
}
