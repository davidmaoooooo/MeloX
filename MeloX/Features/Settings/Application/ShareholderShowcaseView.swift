import SwiftUI

struct ShareholderShowcaseView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    let name: String

    var body: some View {
        HStack(spacing: 12) {
            Text(name)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 8)

            Image(systemName: "waveform")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .symbolEffect(
                    .variableColor.iterative,
                    options: .repeating.speed(0.7),
                    isActive: !accessibilityReduceMotion
                )
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("股东，\(name)")
    }
}

#Preview("股东展示") {
    Form {
        Section("股东") {
            ShareholderShowcaseView(name: "J1 Champ1on")
        }
    }
}
