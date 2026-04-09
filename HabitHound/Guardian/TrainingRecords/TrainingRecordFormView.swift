import SwiftUI

struct TrainingRecordFormView: View {
    /// Pre-select a pet (e.g. when opened from PetDetailView).
    var preselectedPetId: UUID? = nil
    /// Existing record to edit; nil means create.
    var existingRecord: TrainingRecord? = nil
    /// Pet name to show in the nav title when known (edit mode from detail view).
    var petName: String? = nil
    /// Called with the viewModel after a successful save so the caller can refresh.
    var onSave: ((TrainingRecord) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var pets: [Pet] = []
    @State private var selectedPetId: UUID? = nil
    @State private var recordedAt = Date()
    @State private var status: TrainingStatus = .green
    @State private var distance: Distance = .armsLength
    @State private var distraction: Distraction = .none
    @State private var duration: TrainingDuration = .instant
    @State private var notes = ""
    @State private var isShared = false

    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var timerViewModel = TimerViewModel()
    @State private var timerExpanded = false

    private let petService = PetService()
    private let recordService = TrainingRecordService()

    private var isEditing: Bool { existingRecord != nil }
    private var canSave: Bool { selectedPetId != nil && !isSaving }

    var body: some View {
        NavigationStack {
            Form {
                // Pet
                Section("Pet") {
                    if pets.isEmpty {
                        Text("No pets yet — add a pet first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Pet", selection: $selectedPetId) {
                            Text("Select a pet").tag(Optional<UUID>.none)
                            ForEach(pets) { pet in
                                Text(pet.name).tag(Optional(pet.id))
                            }
                        }
                    }
                }

                // Date & Time
                Section("Date & Time") {
                    DatePicker("Session", selection: $recordedAt, displayedComponents: .date)
                        .datePickerStyle(.compact)
                }

                // Status
                Section("Status") {
                    HStack(spacing: 0) {
                        ForEach(TrainingStatus.allCases, id: \.self) { s in
                            Button {
                                status = s
                            } label: {
                                VStack(spacing: 6) {
                                    Circle()
                                        .fill(s.color)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Circle()
                                                .stroke(Color.primary, lineWidth: status == s ? 3 : 0)
                                                .padding(2)
                                        )
                                        .shadow(color: status == s ? s.color.opacity(0.5) : .clear, radius: 6)
                                    Text(s.shortLabel)
                                        .font(.caption2)
                                        .foregroundStyle(status == s ? .primary : .secondary)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)

                    Text(status.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Three D's
                Section("Three D's") {
                    VStack(alignment: .leading, spacing: 12) {
                        LabeledPicker(label: "Distance", selection: $distance) {
                            ForEach(Distance.allCases, id: \.self) { d in
                                Text(d.label).tag(d)
                            }
                        }
                        Divider()
                        LabeledPicker(label: "Distraction", selection: $distraction) {
                            ForEach(Distraction.allCases, id: \.self) { d in
                                Text(d.label).tag(d)
                            }
                        }
                        Divider()
                        LabeledPicker(label: "Duration", selection: $duration) {
                            ForEach(TrainingDuration.allCases, id: \.self) { d in
                                Text(d.label).tag(d)
                            }
                        }
                    }
                }

                // Training Timer
                Section {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { timerExpanded.toggle() }
                    } label: {
                        HStack {
                            Label("Training Timer", systemImage: "timer")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: timerExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    if timerExpanded {
                        TimerView(viewModel: timerViewModel)
                    }
                }

                // Notes
                Section("Notes") {
                    TextField("Optional notes…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Share
                Section {
                    Toggle("Share with Trainer", isOn: $isShared)
                }
            }
            .navigationTitle(isEditing ? "Edit — \(petName ?? "Session")" : "Log Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Log") {
                        Task { await save() }
                    }
                    .disabled(!canSave)
                }
            }
            .disabled(isSaving)
            .overlay { if isSaving { ProgressView() } }
            .onDisappear { timerViewModel.reset() }
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
            .task { await loadPets() }
            .onAppear { populateIfEditing() }
        }
    }

    // MARK: - Helpers

    private func loadPets() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        pets = (try? await petService.fetchPets(guardianId: userId)) ?? []
        if selectedPetId == nil {
            selectedPetId = preselectedPetId ?? pets.first?.id
        }
    }

    private func populateIfEditing() {
        guard let r = existingRecord else { return }
        selectedPetId  = r.petId
        recordedAt     = r.recordedAt
        status         = r.status
        distance       = r.distance
        distraction    = r.distraction
        duration       = r.duration
        notes          = r.notes ?? ""
        isShared       = r.isShared
    }

    /// Normalise to noon local time so the UTC date always matches the user's
    /// intended calendar date regardless of timezone. A 9 PM session on Mar 18
    /// (EST) would otherwise be stored as Mar 19 UTC, breaking streak logic.
    private var normalizedDate: Date {
        Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: recordedAt) ?? recordedAt
    }

    private func save() async {
        guard let petId = selectedPetId,
              let userId = supabase.auth.currentUser?.id else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let record: TrainingRecord
            if let existing = existingRecord {
                var updated = existing
                updated.petId       = petId
                updated.recordedAt  = normalizedDate
                updated.status      = status
                updated.distance    = distance
                updated.distraction = distraction
                updated.duration    = duration
                updated.notes       = notes.isEmpty ? nil : notes
                updated.isShared    = isShared
                record = try await recordService.updateRecord(updated)
            } else {
                record = try await recordService.createRecord(
                    petId: petId,
                    guardianId: userId,
                    recordedAt: normalizedDate,
                    status: status,
                    distance: distance,
                    distraction: distraction,
                    duration: duration,
                    notes: notes.isEmpty ? nil : notes,
                    isShared: isShared
                )
            }
            onSave?(record)
            HapticManager.light()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview("New Session") {
    TrainingRecordFormView()
}

// MARK: - LabeledPicker helper

private struct LabeledPicker<T: Hashable, Content: View>: View {
    let label: String
    @Binding var selection: T
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(label, selection: $selection) {
                content()
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
}
