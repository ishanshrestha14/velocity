import SwiftUI

/// All Projects / Work / Personal filter. Purely an analytics view state — it
/// never changes stored data.
struct ProjectScopePicker: View {
    @Binding var selection: ScopeFilter

    var body: some View {
        Picker("Scope", selection: $selection) {
            ForEach(ScopeFilter.allCases) { filter in
                Text(filter.displayName).tag(filter)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
        .accessibilityLabel("Project scope filter")
    }
}
