import SwiftUI

/// The rounded, subtly bordered container the dashboard is built from.
struct DashboardCard<Content: View>: View {
    var title: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.quaternary.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.separator, lineWidth: 1)
        )
    }
}
