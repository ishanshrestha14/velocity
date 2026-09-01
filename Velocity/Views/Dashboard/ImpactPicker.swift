import SwiftUI

/// The 1 / 3 / 5 selector.
///
/// Shows the number, because that is what the feed shows and what the score is
/// counted in; the name of each level is in the tooltip and the accessibility
/// label so the numbers are never the only explanation.
struct ImpactPicker: View {
    @Binding var selection: ImpactWeight

    var body: some View {
        Picker("Impact", selection: $selection) {
            ForEach(ImpactWeight.allCases) { weight in
                Text(weight.shortLabel)
                    .help(weight.displayName)
                    .tag(weight)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Impact")
        .accessibilityValue("\(selection.points) points, \(selection.displayName)")
    }
}

/// Work / Personal selector, used wherever an item's scope is set.
struct ScopePicker: View {
    @Binding var selection: ProjectScope

    var body: some View {
        Picker("Scope", selection: $selection) {
            ForEach(ProjectScope.allCases) { scope in
                Text(scope.displayName).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .accessibilityLabel("Scope")
        .accessibilityValue(selection.displayName)
    }
}
