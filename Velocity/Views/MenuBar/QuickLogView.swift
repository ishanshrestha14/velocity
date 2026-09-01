import SwiftUI

/// Log work by hand, for the shipping that leaves no commit behind.
///
/// Lives inline in the menu bar panel rather than in a window: opening a window
/// to record one line would cost more than the thing being recorded.
struct QuickLogView: View {
    @Environment(AppEnvironment.self) private var appEnvironment

    /// Collapses the form and returns focus to the panel.
    var onFinish: () -> Void

    @State private var title = ""
    @State private var scope: ProjectScope = .personal
    @State private var weight: ImpactWeight = .core
    @FocusState private var titleIsFocused: Bool

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool { !trimmedTitle.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("What did you ship?", text: $title)
                .textFieldStyle(.roundedBorder)
                .focused($titleIsFocused)
                .onSubmit(submit)

            ScopePicker(selection: $scope)
            ImpactPicker(selection: $weight)

            HStack(spacing: 8) {
                Button("Cancel", role: .cancel) {
                    reset()
                    onFinish()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Log Shipment", action: submit)
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .onAppear { titleIsFocused = true }
    }

    private func submit() {
        guard canSubmit else { return }
        appEnvironment.store.logManualItem(title: trimmedTitle, scope: scope, weight: weight)
        reset()
        onFinish()
    }

    private func reset() {
        title = ""
        // Scope and impact keep their last values: consecutive manual entries
        // are usually the same kind of work.
        titleIsFocused = false
    }
}
