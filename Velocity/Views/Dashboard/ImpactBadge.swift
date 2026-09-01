import SwiftUI

/// The compact 1 / 3 / 5 tag used in the feed and the menu bar.
struct ImpactBadge: View {
    let weight: ImpactWeight

    var body: some View {
        Text(weight.shortLabel)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(tint)
            .frame(width: 20, height: 18)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(tint.opacity(0.16))
            )
            .accessibilityLabel("\(weight.displayName), \(weight.points) points")
    }

    private var tint: Color {
        switch weight {
        case .minor: .secondary
        case .core: .green
        case .epic: .yellow
        }
    }
}
