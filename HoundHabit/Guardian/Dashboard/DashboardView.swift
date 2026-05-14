import SwiftUI

struct DashboardView: View {
    var viewModel: DashboardViewModel
    var switchToPlansTab: (() -> Void)? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppBrandingHeader()
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                List {
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .listRowSeparator(.hidden)
                    }

                    // MARK: Training Plans
                    Section("Training Plans") {
                        if viewModel.planCount == 0 {
                            Text("No plans assigned yet.")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            Button {
                                switchToPlansTab?()
                            } label: {
                                Label(
                                    "\(viewModel.planCount) plan\(viewModel.planCount == 1 ? "" : "s") assigned",
                                    systemImage: "list.bullet.clipboard"
                                )
                            }
                        }
                    }

                    // MARK: Your Trainer
                    Section("Your Trainer") {
                        if let trainer = viewModel.linkedTrainer {
                            LabeledContent("Name", value: trainer.profile.fullName ?? "Trainer")
                            Text("Linked \(trainer.linkedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No trainer linked yet.")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        }
                    }
                }
                .refreshable { await viewModel.load() }
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
}

#Preview {
    DashboardView(viewModel: DashboardViewModel())
}
