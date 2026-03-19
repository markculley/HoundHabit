import SwiftUI

struct SignUpView: View {
    @State private var viewModel = AuthViewModel()
    @State private var showRoleSelection = false
    @State private var passwordVisible = false

    var body: some View {
        VStack(spacing: 24) {
            Text("Create Account")
                .font(.largeTitle).bold()
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                TextField("Full Name", text: $viewModel.fullName)
                    .textContentType(.name)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                TextField("Email", text: $viewModel.email)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .textContentType(.emailAddress)
                    .padding()
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                HStack {
                    Group {
                        if passwordVisible {
                            TextField("Password", text: $viewModel.password)
                        } else {
                            SecureField("Password", text: $viewModel.password)
                        }
                    }
                    .textContentType(.newPassword)
                    .autocapitalization(.none)

                    Button {
                        passwordVisible.toggle()
                    } label: {
                        Image(systemName: passwordVisible ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }

            Button {
                showRoleSelection = true
            } label: {
                Text("Continue")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
            }
            .disabled(viewModel.fullName.isEmpty || viewModel.email.isEmpty || viewModel.password.count < 6)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showRoleSelection) {
            RoleSelectionView(viewModel: viewModel)
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
}
