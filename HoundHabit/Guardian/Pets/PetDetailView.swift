import SwiftUI

struct PetDetailView: View {
    let petId: UUID
    let viewModel: PetViewModel

    @State private var showEditSheet = false
    @State private var showLogSessionSheet = false
    @State private var petPlans: [AssignedPlan] = []
    @State private var isLoadingPlans = false
    @State private var selectedAssignedPlan: AssignedPlan? = nil
    @State private var guardianPlanVM = GuardianPlanViewModel()
    @State private var trainingVM = TrainingRecordViewModel()
    @Environment(\.dismiss) private var dismiss

    private let planService = TrainingPlanService()

    private var pet: Pet? {
        viewModel.pets.first { $0.id == petId }
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
                .navigationDestination(for: TrainingRecord.self) { record in
                    TrainingRecordDetailView(
                        record: record,
                        petName: pet.name,
                        viewModel: trainingVM,
                        selfLoadComments: true
                    )
                }
                .sheet(isPresented: $showEditSheet) {
                    PetFormView(mode: .edit(pet), viewModel: viewModel)
                }
                .sheet(isPresented: $showLogSessionSheet) {
                    TrainingRecordFormView(preselectedPetId: pet.id) { newRecord in
                        trainingVM.records.insert(newRecord, at: 0)
                    }
                }
                .onChange(of: showLogSessionSheet) { _, isShowing in
                    if !isShowing { Task { await trainingVM.loadRecords(petId: pet.id) } }
                }
                .sheet(item: $selectedAssignedPlan) { ap in
                    NavigationStack {
                        GuardianPlanDetailView(assignedPlan: ap, viewModel: guardianPlanVM)
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
                Button {
                    showLogSessionSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
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
                Text("No sessions yet. Tap + to log one.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .listRowSeparator(.hidden)
            } else {
                ForEach(trainingVM.records) { record in
                    NavigationLink(value: record) {
                        TrainingRecordRow(record: record)
                    }
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
