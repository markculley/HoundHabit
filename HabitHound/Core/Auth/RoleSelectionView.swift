import SwiftUI

struct RoleSelectionView: View {
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("I am a…")
                    .font(.largeTitle).bold()
                Text("You can't change this later.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 16) {
                RoleCard(
                    icon: "figure.walk.dog",
                    title: "Guardian",
                    subtitle: "I own a pet and want to track training progress.",
                    isSelected: viewModel.selectedRole == .guardian
                ) {
                    viewModel.selectedRole = .guardian
                }

                RoleCard(
                    icon: "person.badge.shield.checkmark",
                    title: "Trainer",
                    subtitle: "I'm a professional trainer managing clients.",
                    isSelected: viewModel.selectedRole == .trainer
                ) {
                    viewModel.selectedRole = .trainer
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button {
                Task { await viewModel.signUp() }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView()
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            }
            .disabled(viewModel.isLoading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RoleCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
