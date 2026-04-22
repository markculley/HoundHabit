import SwiftUI

// MARK: - Navigation wrapper

/// Carries a training record + its pet name through value-based navigation.
struct RecordNavItem: Hashable {
  let record: TrainingRecord
  let petName: String
}

// MARK: - ViewModel

@Observable
class GuardianViewModel {
  var pets: [Pet] = []
  var records: [TrainingRecord] = []
  var comments: [UUID: [Comment]] = [:]  // keyed by training_record_id
  var isLoading = false
  var errorMessage: String?

  private let petService = PetService()
  private let recordService = TrainingRecordService()
  private let commentService = CommentService()

  func load(guardian: LinkedGuardian) async {
    isLoading = true
    errorMessage = nil
    defer { isLoading = false }
    do {
      async let fetchedPets = petService.fetchPets(guardianId: guardian.guardianId)
      async let fetchedRecords = recordService.fetchRecords(guardianId: guardian.guardianId)
      pets = try await fetchedPets
      records = try await fetchedRecords
    } catch is CancellationError {
      // Pull-to-refresh cancelled the previous load; suppress — a new load is already in flight
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func loadComments(for record: TrainingRecord) async {
    do {
      comments[record.id] = try await commentService.fetchComments(recordId: record.id)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func addComment(to record: TrainingRecord, body: String) async {
    do {
      let comment = try await commentService.addComment(recordId: record.id, body: body)
      comments[record.id, default: []].append(comment)
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func deleteComment(_ comment: Comment, from record: TrainingRecord) async {
    do {
      try await commentService.deleteComment(id: comment.id)
      comments[record.id]?.removeAll { $0.id == comment.id }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func petName(for petId: UUID) -> String {
    pets.first { $0.id == petId }?.name ?? "Unknown Pet"
  }
}

// MARK: - Detail View

struct GuardianDetailView: View {
  let guardian: LinkedGuardian
  @State private var viewModel = GuardianViewModel()
  @State private var showAddResource = false

  var body: some View {
    Group {
      if viewModel.isLoading && viewModel.records.isEmpty {
        ProgressView()
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        List {
          // Guardian info
          Section {
            LabeledContent(
              "Linked",
              value: guardian.linkedAt.formatted(date: .abbreviated, time: .omitted))
          }

          // Pets
          if !viewModel.pets.isEmpty {
            Section("Pets") {
              ForEach(viewModel.pets) { pet in
                HStack {
                  Text(pet.name).font(.body)
                  if let breed = pet.breed {
                    Text("· \(breed)")
                      .font(.caption)
                      .foregroundStyle(.secondary)
                  }
                }
              }
            }
          }

          // Shared training records
          Section("Shared Sessions") {
            if viewModel.records.isEmpty {
              Text("No shared sessions yet.")
                .foregroundStyle(.secondary)
                .font(.subheadline)
            } else {
              ForEach(viewModel.records) { record in
                NavigationLink(
                  value: RecordNavItem(
                    record: record,
                    petName: viewModel.petName(for: record.petId)
                  )
                ) {
                  TrainingRecordRow(record: record)
                }
              }
            }
          }
        }
        .refreshable { await viewModel.load(guardian: guardian) }
        .navigationDestination(for: RecordNavItem.self) { item in
          TrainingRecordDetailView(
            record: item.record,
            petName: item.petName,
            viewModel: TrainingRecordViewModel(),
            isReadOnly: true,
            comments: viewModel.comments[item.record.id] ?? [],
            onAddComment: { body in
              await viewModel.addComment(to: item.record, body: body)
            },
            onDeleteComment: { comment in
              await viewModel.deleteComment(comment, from: item.record)
            }
          )
          .task { await viewModel.loadComments(for: item.record) }
        }
      }
    }
    .navigationTitle(guardian.profile.fullName ?? "Guardian")
    .navigationBarTitleDisplayMode(.large)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button {
          showAddResource = true
        } label: {
          Label("Add Resource", systemImage: "plus")
        }
      }
    }
    .sheet(isPresented: $showAddResource) {
      TrainerAddResourceView(guardian: guardian)
    }
    .onAppear { Task { await viewModel.load(guardian: guardian) } }
    .alert(
      "Error",
      isPresented: Binding(
        get: { viewModel.errorMessage != nil },
        set: { if !$0 { viewModel.errorMessage = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(viewModel.errorMessage ?? "")
    }
  }
}

#Preview {
  NavigationStack {
    GuardianDetailView(
      guardian: LinkedGuardian(
        id: UUID(),
        trainerId: UUID(),
        guardianId: UUID(),
        status: .active,
        linkedAt: Date(),
        profile: Profile(
          id: UUID(),
          role: .guardian,
          fullName: "Alex Guardian",
          avatarUrl: nil,
          createdAt: Date(),
          updatedAt: Date()
        )
      ))
  }
}
