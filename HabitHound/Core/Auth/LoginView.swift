import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @State private var viewModel = AuthViewModel()
    @State private var showSignUp = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "pawprint.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.accentColor)
                    Text("HabitHound")
                        .font(.largeTitle).bold()
                    Text("Pet training made simple")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Fields
                VStack(spacing: 12) {
                    TextField("Email", text: $viewModel.email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .textContentType(.emailAddress)
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                    SecureField("Password", text: $viewModel.password)
                        .textContentType(.password)
                        .padding()
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }

                // Sign In
                Button {
                    Task { await viewModel.signIn() }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView()
                        } else {
                            Text("Sign In")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                    .foregroundStyle(.white)
                }
                .disabled(viewModel.isLoading)

                // Sign in with Apple
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = viewModel.prepareAppleSignIn()
                } onCompletion: { result in
                    viewModel.handleAppleSignIn(result)
                }
                .frame(height: 50)
                .signInWithAppleButtonStyle(.black)

                // Sign Up link
                Button("Don't have an account? Sign Up") {
                    showSignUp = true
                }
                .font(.subheadline)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 24)
            .navigationDestination(isPresented: $showSignUp) {
                SignUpView()
            }
        }
    }
}
