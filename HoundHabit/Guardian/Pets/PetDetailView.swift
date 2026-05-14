import SwiftUI

/// Sort options for the Training Sessions list on the Pet detail screen.
/// Each mode adds another sort key; the unspecified tail falls back to
/// most-recent-first.
enum SessionSort: String, CaseIterable, Identifiable {
    case behavior          = "Behavior"
    case behaviorStep      = "Behavior → Step"
    case behaviorStepDate  = "Behavior → Step → DateTime"
    var id: String { rawValue }
}

struct PetDetailView: View {
    let petId: UUID
    let viewModel: PetViewModel

    @State private var showEditSheet = false
    @State private var petPlans: [AssignedPlan] = []
    @State private var isLoadingPlans = false
    @State private var selectedAssignedPlan: AssignedPlan? = nil
    @State private var guardianPlanVM = GuardianPlanViewModel()
    @State private var trainingVM = TrainingRecordViewModel()
    @State private var sessionSort: SessionSort = .behaviorStepDate
    // Tapping a session row opens a "View / Train Again" dialog; these drive the
    // two destinations the dialog can lead to.
    @State private var sessionActionRecord: TrainingRecord? = nil
    @State private var recordToView: TrainingRecord? = nil
    @State private var recordToRepeat: TrainingRecord? = nil
    @Environment(\.dismiss) private var dismiss

    private let planService = TrainingPlanService()

    private var pet: Pet? {
        viewModel.pets.first { $0.id == petId }
    }

    /// Records sorted per `sessionSort`. Behavior is ordered by its position in
    /// the plan (`behaviorSortOrder`), with behavior name as a deterministic
    /// tiebreaker for the rare cross-plan collision. Step is ordered by its
    /// position within the behavior. DateTime is newest-first. Modes that stop
    /// short of DateTime still use newest-first as the implicit final tiebreaker.
    private var sortedRecords: [TrainingRecord] {
        func ctx(_ r: TrainingRecord) -> SessionPlanContext? {
            r.planItemId.flatMap { trainingVM.planContext[$0] }
        }
        return trainingVM.records.sorted { a, b in
            let ca = ctx(a), cb = ctx(b)

            let aBehaviorOrder = ca?.behaviorSortOrder ?? Int.max
            let bBehaviorOrder = cb?.behaviorSortOrder ?? Int.max
            if aBehaviorOrder != bBehaviorOrder { return aBehaviorOrder < bBehaviorOrder }

            let aBehaviorName = ca?.behaviorName ?? ""
            let bBehaviorName = cb?.behaviorName ?? ""
            if aBehaviorName != bBehaviorName {
                return aBehaviorName.localizedCaseInsensitiveCompare(bBehaviorName) == .orderedAscending
            }

            if sessionSort != .behavior {
                let aStepOrder = ca?.stepSortOrder ?? Int.max
                let bStepOrder = cb?.stepSortOrder ?? Int.max
                if aStepOrder != bStepOrder { return aStepOrder < bStepOrder }
            }

            // DateTime newest-first — explicit in .behaviorStepDate, implicit
            // tiebreaker in the shallower modes.
            return a.recordedAt > b.recordedAt
        }
    }

    var body: some View {
        Group {
            if let pet {
                List {
                    heroRow(pet)
                    plansSection(pet)
                    trainingSessionsSection(pet)
                }
                .listStyle(.plain)
                .refreshable {
                    await loadPetPlans()
                    await trainingVM.loadRecords(petId: pet.id)
                }
                .navigationTitle(pet.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Edit") { showEditSheet = true }
                    }
                }
                .navigationDestination(item: $recordToView) { record in
                    TrainingRecordDetailView(
                        record: record,
                        petName: pet.name,
                        viewModel: trainingVM,
                        selfLoadComments: true
                    )
                }
                // Tapping a session row → choose: view the past session, or repeat it.
                .confirmationDialog(
                    "Training Session",
                    isPresented: Binding(
                        get: { sessionActionRecord != nil },
                        set: { if !$0 { sessionActionRecord = nil } }
                    ),
                    presenting: sessionActionRecord
                ) { record in
                    Button("View Session") { recordToView = record }
                    Button("Train Again") { recordToRepeat = record }
                    Button("Cancel", role: .cancel) {}
                }
                .sheet(isPresented: $showEditSheet) {
                    PetFormView(mode: .edit(pet), viewModel: viewModel)
                }
                .sheet(item: $selectedAssignedPlan, onDismiss: {
                    // A practice session may have been logged inside the plan sheet.
                    Task { await trainingVM.loadRecords(petId: pet.id) }
                }) { ap in
                    NavigationStack {
                        GuardianPlanDetailView(assignedPlan: ap, viewModel: guardianPlanVM)
                    }
                }
                // "Train Again" → the consistent training session view for that step.
                .sheet(item: $recordToRepeat) { record in
                    if let planItemId = record.planItemId,
                       let planId = trainingVM.planContext[planItemId]?.planId,
                       let assignedPlan = petPlans.first(where: { $0.plan.id == planId }) {
                        TrainingSessionView(
                            planItemId: planItemId,
                            assignedPlan: assignedPlan,
                            isShared: assignedPlan.assignment.isShared,
                            viewModel: guardianPlanVM,
                            onLogged: { Task { await trainingVM.loadRecords(petId: pet.id) } }
                        )
                    } else {
                        Text("This session's plan is no longer available.")
                            .padding()
                    }
                }
                .task {
                    await loadPetPlans()
                    await trainingVM.loadRecords(petId: pet.id)
                }
                .alert("Error", isPresented: Binding(
                    get: { trainingVM.errorMessage != nil },
                    set: { if !$0 { trainingVM.errorMessage = nil } }
                )) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(trainingVM.errorMessage ?? "")
                }
            }
        }
        .onChange(of: pet == nil) { _, isGone in
            if isGone { dismiss() }
        }
    }

    // MARK: - Hero Photo

    @ViewBuilder
    private func heroRow(_ pet: Pet) -> some View {
        Section {
            heroSection(pet)
                .listRowInsets(EdgeInsets())
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func heroSection(_ pet: Pet) -> some View {
        let url = pet.photoUrl.map { "\($0)?t=\(Int(pet.updatedAt.timeIntervalSince1970))" }

        ZStack(alignment: .bottomLeading) {
            Rectangle()
                .aspectRatio(4/3, contentMode: .fit)
                .foregroundStyle(Color(.secondarySystemFill))
                .overlay {
                    if let urlString = url, let imageURL = URL(string: urlString) {
                        AsyncImage(url: imageURL) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                            default:
                                heroPawPlaceholder
                            }
                        }
                    } else {
                        heroPawPlaceholder
                    }
                }
                .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name)
                    .font(.largeTitle).bold()
                    .foregroundStyle(.white)
                if let breed = pet.breed, !breed.isEmpty {
                    Text(breed)
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .clipped()
    }

    private var heroPawPlaceholder: some View {
        Image(systemName: "pawprint.fill")
            .resizable()
            .scaledToFit()
            .frame(width: 72)
            .foregroundStyle(.tertiary)
    }

    // MARK: - Plans

    @ViewBuilder
    private func plansSection(_ pet: Pet) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                Text("Plans")
                    .font(.title2).bold()

                if isLoadingPlans && petPlans.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if petPlans.isEmpty {
                    Text("No training plans for \(pet.name) yet. Your trainer can assign one.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } else {
                    planGroup(plans: petPlans)
                }
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private func planGroup(plans: [AssignedPlan]) -> some View {
        VStack(spacing: 0) {
            ForEach(plans) { ap in
                Button {
                    selectedAssignedPlan = ap
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ap.plan.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let desc = ap.plan.description, !desc.isEmpty {
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemGroupedBackground))
                }
                .buttonStyle(.plain)

                if ap.id != plans.last?.id {
                    Divider().padding(.leading, 16)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Training Sessions

    @ViewBuilder
    private func trainingSessionsSection(_ pet: Pet) -> some View {
        Section {
            HStack {
                Text("Training Sessions")
                    .font(.title2).bold()
                Spacer()
                if !trainingVM.records.isEmpty {
                    Menu {
                        Picker("Sort", selection: $sessionSort) {
                            ForEach(SessionSort.allCases) { option in
                                Text(option.rawValue).tag(option)
                            }
                        }
                    } label: {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                            .font(.subheadline)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 24)
            .padding(.bottom, 8)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            if trainingVM.isLoading && trainingVM.records.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowSeparator(.hidden)
            } else if trainingVM.records.isEmpty {
                Text("No training sessions yet. Practice a plan step to log one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(sortedRecords) { record in
                    Button {
                        sessionActionRecord = record
                    } label: {
                        PetSessionRow(
                            record: record,
                            context: record.planItemId.flatMap { trainingVM.planContext[$0] }
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            Task { await trainingVM.toggleSharing(record) }
                        } label: {
                            Label(
                                record.isShared ? "Unshare" : "Share",
                                systemImage: record.isShared ? "person.2.slash" : "person.2.fill"
                            )
                        }
                        .tint(record.isShared ? .gray : .blue)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            Task { await trainingVM.deleteRecord(record) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Data

    private func loadPetPlans() async {
        isLoadingPlans = true
        defer { isLoadingPlans = false }
        let all = (try? await planService.fetchAssignedPlans()) ?? []
        petPlans = all.filter { $0.assignment.petId == petId }
        for ap in petPlans where !guardianPlanVM.assignedPlans.contains(where: { $0.id == ap.id }) {
            guardianPlanVM.assignedPlans.append(ap)
        }
    }
}

// MARK: - PetSessionRow

/// A training session row in the Pet detail screen. Every session is plan-linked,
/// so it leads with Behavior + Step Name, then the rep result, datetime, and notes.
private struct PetSessionRow: View {
    let record: TrainingRecord
    let context: SessionPlanContext?

    private var titleLine: String {
        context?.behaviorName ?? context?.stepTitle ?? "Training session"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(titleLine)
                    .font(.headline)
                if let context, !context.behaviorName.isEmpty {
                    Text(context.stepTitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Text(record.recordedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.top, 1)
                }
            }
            Spacer(minLength: 8)
            Text("\(record.score)/5")
                .font(.headline.monospacedDigit())
                .foregroundStyle(TrainingStatus.from(score: record.score).color)
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let vm = PetViewModel()
    let pet = Pet(
        id: UUID(),
        guardianId: UUID(),
        name: "Ozzie",
        breed: "Goldendoodle",
        photoUrl: nil,
        createdAt: Date(),
        updatedAt: Date()
    )
    vm.pets = [pet]
    return NavigationStack {
        PetDetailView(petId: pet.id, viewModel: vm)
    }
}
