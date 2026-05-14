import SwiftUI

/// The one consistent screen a guardian uses to do (or repeat) a training
/// session. Linked from the plan detail (tapping a reachable step) and from the
/// pet detail's Training Sessions list (tapping a past session → "Train Again").
///
/// Flow: shows plan / behavior / step / Three D's / timer + a "Train Now"
/// button. Tapping "Train Now" starts the timer and reveals the reps stepper +
/// notes; the button becomes "Done". "Done" logs the session, advances the plan
/// when this is the guardian's current step, and dismisses.
///
/// Self-contained: it does its own record creation + advancement so it behaves
/// identically regardless of where it was opened from. It takes just the step
/// id + the assignment and self-loads the step and behavior via the view model.
struct TrainingSessionView: View {
    let planItemId: UUID
    let assignedPlan: AssignedPlan
    /// Whether sessions logged here are shared with the trainer — passed in so
    /// callers with a live sharing toggle (plan detail) can provide the current
    /// value rather than a stale snapshot.
    let isShared: Bool
    let viewModel: GuardianPlanViewModel
    /// Fired after a session is logged so the caller can refresh its list.
    var onLogged: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var timerViewModel = TimerViewModel()
    @State private var score = 5
    @State private var notes = ""
    @State private var hasStartedTraining = false
    /// Set when the guardian taps "Done" before the timer runs out.
    @State private var finishedEarly = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let recordService = TrainingRecordService()

    private var planId: UUID { assignedPlan.plan.id }

    private var planItem: TrainingPlanItem? {
        viewModel.items[planId]?.first { $0.id == planItemId }
    }

    private var behaviorName: String? {
        guard let behaviorId = planItem?.behaviorId else { return nil }
        return viewModel.behaviors[planId]?.first { $0.id == behaviorId }?.type.label
    }

    private var derivedStatus: TrainingStatus { TrainingStatus.from(score: score) }

    /// The Reps + Notes inputs show once training is over — either the timer
    /// expired, or the guardian tapped "Done" early.
    private var showResultInputs: Bool {
        timerViewModel.state == .complete || finishedEarly
    }

    /// True when the step being trained is the guardian's current position in
    /// the plan — only then does logging advance the plan.
    private var isCurrentStep: Bool {
        let items = viewModel.items[planId] ?? []
        return viewModel.currentItem(for: assignedPlan, in: items)?.id == planItemId
    }

    var body: some View {
        NavigationStack {
            Group {
                if let planItem {
                    content(planItem)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Training Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
            }
            .task {
                if viewModel.items[planId] == nil {
                    await viewModel.loadItems(for: planId)
                }
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

    // MARK: - Content

    @ViewBuilder
    private func content(_ planItem: TrainingPlanItem) -> some View {
        Form {
            // Primary action — fixed at the top. Train Now → Done in place.
            Section {
                Button {
                    if !hasStartedTraining {
                        // "Train Now" — start the session + the timer.
                        hasStartedTraining = true
                        timerViewModel.start()
                    } else if !showResultInputs {
                        // "Done" tapped before the timer expired — finish early:
                        // stop the timer and reveal the Reps + Notes inputs.
                        finishedEarly = true
                        timerViewModel.pause()
                    } else {
                        // "Done" with the result inputs showing — log it.
                        Task { await logSession(planItem) }
                    }
                } label: {
                    Text(hasStartedTraining ? "Done" : "Train Now")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isSaving)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            // Result inputs — held back until training is over: either the timer
            // expired, or the guardian tapped "Done" early.
            if showResultInputs {
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

                Section("Notes") {
                    TextField("Optional notes…", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }

            // Reference — what the guardian is training.
            Section {
                LabeledContent("Plan", value: assignedPlan.plan.title)
                LabeledContent("Behavior", value: behaviorName ?? "—")
                LabeledContent("Step", value: planItem.title)
            }

            Section("Three D's") {
                LabeledContent("Distance",    value: planItem.distanceLabel)
                LabeledContent("Duration",    value: planItem.durationLabel)
                LabeledContent("Distraction", value: planItem.distractionLabel)
            }

            Section("Training Timer") {
                TimerView(viewModel: timerViewModel)
            }
        }
    }

    private var scoreFooter: String {
        guard isCurrentStep else {
            return "This step is already complete — logging it again won't change your plan position."
        }
        switch score {
        case 5:    return "Green — ready to advance to the next step."
        case 3, 4: return "Yellow — keep practicing this step to build confidence."
        case 2:    return "Orange — stay on this step a bit longer."
        default:   return "Red — we'll drop back to the previous step."
        }
    }

    // MARK: - Logging

    private func logSession(_ planItem: TrainingPlanItem) async {
        guard let petId = assignedPlan.assignment.petId,
              let userId = supabase.auth.currentUser?.id else {
            errorMessage = "Couldn't log this session — the plan isn't linked to a pet."
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            _ = try await recordService.createRecord(
                petId: petId,
                guardianId: userId,
                recordedAt: Date(),
                score: score,
                distance: planItem.distance,
                distraction: planItem.distraction,
                duration: planItem.duration,
                distanceCustomValue: planItem.distanceCustomValue,
                durationCustomValue: planItem.durationCustomValue,
                distractionCustomValue: planItem.distractionCustomValue,
                notes: notes.isEmpty ? nil : notes,
                isShared: isShared,
                planItemId: planItem.id
            )
            HapticManager.light()
            // Refresh the guardian's records so per-step completion (3-day streak)
            // reflects this session immediately on the plan detail.
            await viewModel.loadRecords()
            // Keep the legacy advancement pointer moving so the plan progress
            // badge still works — it's removed in the plan-progress rework card.
            if isCurrentStep {
                await viewModel.advanceCurrentStep(
                    assignedPlan: assignedPlan,
                    score: score,
                    planItems: viewModel.items[planId] ?? []
                )
            }
            onLogged?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    let plan = TrainingPlan(
        id: UUID(), trainerId: UUID(),
        title: "Basic Recall", description: nil,
        createdAt: Date(), updatedAt: Date()
    )
    let assignment = PlanAssignment(
        id: UUID(), planId: plan.id, trainerId: UUID(),
        guardianId: UUID(), petId: UUID(), assignedAt: Date(),
        currentItemId: nil, isShared: true
    )
    return TrainingSessionView(
        planItemId: UUID(),
        assignedPlan: AssignedPlan(assignment: assignment, plan: plan),
        isShared: true,
        viewModel: GuardianPlanViewModel()
    )
}
