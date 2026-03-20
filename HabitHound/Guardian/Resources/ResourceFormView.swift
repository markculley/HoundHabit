import SwiftUI

struct ResourceFormView: View {
    var onSave: (Resource) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var kind: ResourceKind = .note
    @State private var title = ""
    @State private var urlText = ""
    @State private var noteText = ""
    @State private var photoData: Data?
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let service = ResourceService()
    private let storageService = StorageService()

    var body: some View {
        NavigationStack {
            Form {
                Section("Kind") {
                    Picker("Kind", selection: $kind) {
                        ForEach(ResourceKind.allCases) { k in
                            Text(k.label).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Title") {
                    TextField("Title", text: $title)
                }

                switch kind {
                case .photo:
                    Section("Photo") {
                        PhotoPickerView(imageData: $photoData)
                            .listRowInsets(EdgeInsets())
                    }
                    Section("Notes (optional)") {
                        TextField("Add notes...", text: $noteText, axis: .vertical)
                            .lineLimit(3...6)
                    }

                case .url:
                    Section("URL") {
                        TextField("https://", text: $urlText)
                            .keyboardType(.URL)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    }
                    Section("Notes (optional)") {
                        TextField("Add notes...", text: $noteText, axis: .vertical)
                            .lineLimit(3...6)
                    }

                case .note:
                    Section("Note") {
                        TextField("Write your note...", text: $noteText, axis: .vertical)
                            .lineLimit(5...10)
                    }
                }
            }
            .navigationTitle("Add Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(!isValid || isSaving)
                }
            }
            .overlay {
                if isSaving { ProgressView() }
            }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var isValid: Bool {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return false }
        switch kind {
        case .photo: return photoData != nil
        case .url:   return !urlText.trimmingCharacters(in: .whitespaces).isEmpty
        case .note:  return !noteText.trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    private func save() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
            let trimmedBody  = noteText.trimmingCharacters(in: .whitespaces)
            let resourceId   = UUID()

            var photoUrl: String? = nil
            if kind == .photo, let data = photoData {
                photoUrl = try await storageService.uploadResourcePhoto(
                    data: data, guardianId: userId, resourceId: resourceId
                )
            }

            let resource = try await service.createResource(
                id: resourceId,
                guardianId: userId,
                kind: kind,
                title: trimmedTitle,
                url: kind == .url ? urlText.trimmingCharacters(in: .whitespaces) : photoUrl,
                body: trimmedBody.isEmpty ? nil : trimmedBody
            )
            onSave(resource)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ResourceFormView { _ in }
}
