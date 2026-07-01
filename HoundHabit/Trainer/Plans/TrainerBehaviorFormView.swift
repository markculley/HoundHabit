import SwiftUI

/// Adds a behavior to a plan. A behavior is either one of the 12 standard
/// presets or a custom name the trainer types. The two inputs are mutually
/// exclusive — picking a preset clears the custom field, and vice versa.
struct TrainerBehaviorFormView: View {
    let onSave: (BehaviorType) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedStandard: StandardBehavior? = nil
    @State private var customName: String = ""

    /// The behavior to save: a non-empty custom name wins, otherwise the picked
    /// preset. `BehaviorType.init(rawValue:)` collapses a custom value that
    /// matches a standard label back to `.standard`.
    private var resolvedType: BehaviorType? {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return BehaviorType(rawValue: trimmed)
        }
        return selectedStandard.map(BehaviorType.standard)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Behavior") {
                    ForEach(StandardBehavior.allCases, id: \.self) { type in
                        Button {
                            selectedStandard = type
                            customName = ""
                        } label: {
                            HStack {
                                Text(type.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedStandard == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.caption.bold())
                                }
                            }
                        }
                    }
                }

                Section {
                    TextField("e.g. Heel", text: $customName)
                        .onChange(of: customName) { _, newValue in
                            if !newValue.isEmpty { selectedStandard = nil }
                        }
                } header: {
                    Text("Custom")
                } footer: {
                    Text("Type your own behavior name if it isn't in the list above.")
                }
            }
            .navigationTitle("Add Behavior")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let resolvedType {
                            onSave(resolvedType)
                        }
                        dismiss()
                    }
                    .disabled(resolvedType == nil)
                }
            }
        }
    }
}

#Preview {
    TrainerBehaviorFormView { _ in }
}
