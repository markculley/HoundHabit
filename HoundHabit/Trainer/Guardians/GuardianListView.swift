import SwiftUI

// MARK: - ViewModel

@Observable
class GuardianListViewModel {
    var guardians: [LinkedGuardian] = []
    var isLoading = false
    var errorMessage: String?

    private let service = InviteService()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            guardians = try await service.fetchLinkedGuardians()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - List View

struct GuardianListView: View {
    @State private var viewModel = GuardianListViewModel()

    var body: some View {
        VStack(spacing: 0) {
            AppBrandingHeader(subtitle: "Guardians")
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)

            Group {
                if viewModel.isLoading && viewModel.guardians.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if viewModel.guardians.isEmpty {
                    ContentUnavailableView(
                        "No Guardians Yet",
                        systemImage: "person.2",
                        description: Text("Send an invite from the Invite tab to link a guardian.")
                    )
                } else {
                    List {
                        ForEach(viewModel.guardians) { guardian in
                            NavigationLink(value: guardian) {
                                GuardianRow(guardian: guardian)
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: LinkedGuardian.self) { guardian in
            GuardianDetailView(guardian: guardian)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load() }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Row

private struct GuardianRow: View {
    let guardian: LinkedGuardian

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(initials)
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                }
            VStack(alignment: .leading, spacing: 2) {
                Text(guardian.profile.fullName ?? "Guardian")
                    .font(.headline)
                Text("Linked \(guardian.linkedAt.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private var initials: String {
        let name = guardian.profile.fullName ?? ""
        let parts = name.split(separator: " ")
        return parts.prefix(2).compactMap { $0.first.map(String.init) }.joined()
    }
}

// MARK: - Guardian Detail Stub (Phase 8 will replace this)

private struct GuardianStubView: View {
    let guardian: LinkedGuardian

    var body: some View {
        List {
            Section {
                LabeledContent("Name", value: guardian.profile.fullName ?? "—")
                LabeledContent("Linked", value: guardian.linkedAt.formatted(date: .abbreviated, time: .omitted))
            }

            Section {
                Label("Training records and comments coming in Phase 8.", systemImage: "clock")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .navigationTitle(guardian.profile.fullName ?? "Guardian")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        GuardianListView()
    }
}
