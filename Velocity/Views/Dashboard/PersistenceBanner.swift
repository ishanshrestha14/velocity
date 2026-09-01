import SwiftUI

/// Shown when loading or saving failed.
///
/// A data problem is the one thing this app must never let pass quietly, so it
/// gets a banner rather than a log line — with the path to whatever was
/// preserved, so the user can go and look.
struct PersistenceBanner: View {
    let error: PersistenceError
    var onDismiss: () -> Void
    var onRevealBackups: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 3) {
                Text(error.errorDescription ?? "Something went wrong.")
                    .fontWeight(.semibold)
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            if case .unreadableData = error, let onRevealBackups {
                Button("Show Backups", action: onRevealBackups)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.yellow.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.yellow.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }
}
