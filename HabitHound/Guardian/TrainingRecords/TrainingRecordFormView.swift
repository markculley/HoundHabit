import SwiftUI

struct TrainingRecordFormView: View {
    /// Pre-select a pet (e.g. when opened from PetDetailView).
    var preselectedPetId: UUID? = nil
    /// When set, locks the pet to this ID — picker is hidden and pet name shown read-only.
    var lockedPetId: UUID? = nil
    /// Existing record to edit; nil means create.
    var existingRecord: TrainingRecord? = nil
    /// Pet name to show in the nav title when known (edit mode from detail view).
    var petName: String? = nil
    /// When set, this is a plan-linked session: Three D's are locked to the step's values.
    var planItem: TrainingPlanItem? = nil
    /// Called with the saved record so the caller can refresh / trigger advancement.
    var onSave: ((TrainingRecord) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var pets: [Pet] = []
    @State private var selectedPetId: UUID? = nil
    @State private var recordedAt = Date()
    @State private var score: Int = 5
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
    private var isPlanSession: Bool { planItem != nil }
    private var canSave: Bool { selectedPetId != nil && !isSaving }

    private var derivedStatus: TrainingStatus { TrainingStatus.from(score: score) }

    var body: some View {
        NavigationStack {
            Form {
                // Pet
                Section("Pet") {
                    if let lockedId = lockedPetId {
                        let name = pets.first { $0.id == lockedId }?.name ?? "Loading…"
                        LabeledContent("Pet", value: name)
                    } else if pets.isEmpty {
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

                // Score
                Section {
                    Stepper(value: $score, in: 0...5) {
                        HStack {
                            Text("\(score) / 5")
                                .font(.title2.bold())
                                .monospacedDigit()
                            Spacer()
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(derivedStatus.color)
                                    .frame(width: 18, height: 18)
                                Text(derivedStatus.label)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Reps out of 5")
                } footer: {
                    Text(scoreFooter)
                        .foregroundStyle(.secondary)
                }

                // Three D's — locked when from a plan step, editable for standalone sessions
                Section("Three D's") {
                    if isPlanSession {
                        // Read-only display
                        LabeledContent("Distance",    value: distance.label)
                        LabeledContent("Duration",    value: duration.label)
                        LabeledContent("Distraction", value: distraction.label)
                    } else {
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
            .navigationTitle(navTitle)
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

    private var navTitle: String {
        if isEditing { return "Edit — \(petName ?? "Session")" }
        if let item = planItem { return "Practice: \(item.title)" }
        return "Log Session"
    }

    private var scoreFooter: String {
        switch score {
        case 5:    return "Green — ready to advance to the next step."
        case 3, 4: return "Yellow — keep practicing this step to build confidence."
        case 2:    return "Orange — stay on this step a bit longer."
        default:   return "Red — we'll drop back to the previous step."
        }
    }

    private func loadPets() async {
        guard let userId = supabase.auth.currentUser?.id else { return }
        pets = (try? await petService.fetchPets(guardianId: userId)) ?? []
        if selectedPetId == nil {
            selectedPetId = lockedPetId ?? preselectedPetId ?? pets.first?.id
        }
    }

    private func populateIfEditing() {
        if let item = planItem {
            // Lock Three D's to the plan step
            distance    = item.distance
            duration    = item.duration
            distraction = item.distraction
        }
        guard let r = existingRecord else { return }
        selectedPetId  = r.petId
        recordedAt     = r.recordedAt
        score          = r.score
        distance       = r.distance
        distraction    = r.distraction
        duration       = r.duration
        notes          = r.notes ?? ""
        isShared       = r.isShared
    }

    /// Normalise to noon local time so the UTC date always matches the user's
    /// intended calendar date regardless of timezone.
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
                updated.score       = score
                updated.status      = derivedStatus
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
                    score: score,
                    distance: distance,
                    distraction: distraction,
                    duration: duration,
                    notes: notes.isEmpty ? nil : notes,
                    isShared: isShared,
                    planItemId: planItem?.id
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

#Preview("Plan Step Session") {
    TrainingRecordFormView(
        planItem: TrainingPlanItem(
            id: UUID(), planId: UUID(), sortOrder: 1,
            title: "Sit at 6 ft",
            distance: .sixFeet, duration: .fiveSeconds, distraction: .none
        )
    )
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
