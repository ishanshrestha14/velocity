import SwiftUI

/// The compact status-item label: a bolt plus today's point total.
struct MenuBarLabel: View {
    let points: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
            Text("\(points)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Velocity")
        .accessibilityValue("\(points) points shipped today")
    }
}
