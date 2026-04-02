import SwiftUI
import AuthenticationServices

struct SignInView: View {

    @EnvironmentObject var auth: AuthViewModel
    @State private var currentNonce: String?

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Logo / Wordmark
            VStack(spacing: 8) {
                Image(systemName: "house.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)
                Text("Roomie")
                    .font(.largeTitle.bold())
                Text("Live better together.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 12) {
                // Google Sign-In
                Button {
                    signInWithGoogle()
                } label: {
                    HStack {
                        Image("google_logo") // Add to Assets.xcassets
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text("Continue with Google")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.separator, lineWidth: 1)
                    )
                }
                .foregroundStyle(.primary)

                // Apple Sign-In
                SignInWithAppleButton(.continue) { request in
                    let nonce = AuthService.randomNonce()
                    currentNonce = nonce
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = AuthService.sha256(nonce)
                } onCompletion: { result in
                    handleAppleSignIn(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)

            if let error = auth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer().frame(height: 16)
        }
    }

    // MARK: - Actions

    private func signInWithGoogle() {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let root = scene.windows.first?.rootViewController else { return }
        auth.signInWithGoogle(presenting: root)
    }

    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let nonce = currentNonce else { return }
            auth.signInWithApple(credential: credential, nonce: nonce)
        case .failure(let error):
            auth.errorMessage = error.localizedDescription
        }
    }
}
