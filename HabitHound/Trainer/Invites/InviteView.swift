import SwiftUI

// MARK: - ViewModel

@Observable
class InviteViewModel {
    var invites: [Invite] = []
    var email = ""
    var isSending = false
    var isLoading = false
    var errorMessage: String?
    var sentCode: String?

    private let service = InviteService()

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            invites = try await service.fetchInvites()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sendInvite(trainerName: String?) async {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isSending = true
        errorMessage = nil
        defer { isSending = false }
        do {
            let invite = try await service.createInvite(email: trimmed, trainerName: trainerName)
            invites.insert(invite, at: 0)
            sentCode = invite.code
            email = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - View

struct InviteView: View {
    @State private var viewModel = InviteViewModel()

    // Trainer's name for the email — pulled from auth profile
    private var trainerName: String? {
        supabase.auth.currentUser?.userMetadata["full_name"]?.stringValue
    }

    var body: some View {
        List {
            Section("New Invite") {
                TextField("Guardian's email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                Button {
                    Task { await viewModel.sendInvite(trainerName: trainerName) }
                } label: {
                    if viewModel.isSending {
                        ProgressView()
                    } else {
                        Text("Send Invite")
                    }
                }
                .disabled(!isValidEmail || viewModel.isSending)
            }

            if let code = viewModel.sentCode {
                Section {
                    VStack(spacing: 12) {
                        Text("Invite sent! Share this code if the email doesn't arrive:")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Text(code)
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                            .tracking(6)

                        HStack(spacing: 16) {
                            Button("Copy Code") {
                                UIPasteboard.general.string = code
                            }
                            .buttonStyle(.borderedProminent)

                            Button("Dismiss") {
                                viewModel.sentCode = nil
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }

            if !viewModel.invites.isEmpty {
                Section("Sent Invites") {
                    ForEach(viewModel.invites) { invite in
                        InviteRow(invite: invite)
                    }
                }
            }
        }
        .navigationTitle("Invite Guardian")
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

    private var isValidEmail: Bool {
        let t = viewModel.email.trimmingCharacters(in: .whitespaces)
        return t.contains("@") && t.contains(".")
    }
}

// MARK: - Row

private struct InviteRow: View {
    let invite: Invite

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(invite.email)
                    .font(.subheadline)
                Text(invite.code)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
        .padding(.vertical, 2)
    }

    private var statusBadge: some View {
        Text(invite.status.rawValue.capitalized)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.15))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch invite.status {
        case .pending:  return .orange
        case .accepted: return .green
        case .expired:  return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        InviteView()
    }
}
