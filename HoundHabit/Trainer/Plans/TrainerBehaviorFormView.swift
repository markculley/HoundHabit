import SwiftUI

/// Adds a behavior to a plan. A behavior is one of the 12 standard
/// `BehaviorType`s — picked from a fixed list, not free-typed.
struct TrainerBehaviorFormView: View {
    let onSave: (BehaviorType) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: BehaviorType? = nil

    var body: some View {
        NavigationStack {
            List {
                Section("Behavior") {
                    ForEach(BehaviorType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack {
                                Text(type.label)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedType == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                        .font(.caption.bold())
                                }
                            }
                        }
                    }
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
                        if let selectedType {
                            onSave(selectedType)
                        }
                        dismiss()
                    }
                    .disabled(selectedType == nil)
                }
            }
        }
    }
}

#Preview {
    TrainerBehaviorFormView { _ in }
}
