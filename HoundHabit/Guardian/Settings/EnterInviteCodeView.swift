import SwiftUI

struct EnterInviteCodeView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var code = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var linkedTrainerName: String?

    private let service = InviteService()

    var body: some View {
        NavigationStack {
            Group {
                if let trainerName = linkedTrainerName {
                    successView(trainerName: trainerName)
                } else {
                    codeEntryForm
                }
            }
            .navigationTitle("Enter Invite Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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

    // MARK: - Code entry

    private var codeEntryForm: some View {
        Form {
            Section {
                TextField("8-character code", text: $code)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: code) { _, new in
                        code = String(new.uppercased().prefix(8))
                    }
            } footer: {
                Text("Enter the code your trainer sent you by email.")
            }

            Section {
                Button {
                    Task { await redeem() }
                } label: {
                    if isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Link Trainer")
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(code.count < 8 || isLoading)
            }
        }
    }

    // MARK: - Success state

    private func successView(trainerName: String) -> some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("You're linked!")
                .font(.title2.bold())

            Text("**\(trainerName)** can now view your shared training records.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Redeem

    private func redeem() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let invite = try await service.fetchInviteByCode(code)
            _ = try await service.acceptInvite(invite)
            let trainerProfile = try? await AuthService().fetchProfile(id: invite.trainerId)
            linkedTrainerName = trainerProfile?.fullName ?? "Your trainer"
        } catch let error as InviteError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    EnterInviteCodeView()
}
