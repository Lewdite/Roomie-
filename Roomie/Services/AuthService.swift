import Foundation
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import AuthenticationServices
import CryptoKit

// MARK: - Protocol

protocol AuthServiceProtocol {
    var currentFirebaseUser: FirebaseAuth.User? { get }
    func signInWithGoogle(presenting: UIViewController) async throws -> RoomieUser
    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws -> RoomieUser
    func signOut() throws
    func fetchOrCreateUser(from firebaseUser: FirebaseAuth.User) async throws -> RoomieUser
}

// MARK: - Implementation

final class AuthService: AuthServiceProtocol {

    private let db = Firestore.firestore()

    var currentFirebaseUser: FirebaseAuth.User? {
        Auth.auth().currentUser
    }

    // MARK: Google Sign-In

    func signInWithGoogle(presenting viewController: UIViewController) async throws -> RoomieUser {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingClientID
        }
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config

        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: viewController)
        guard let idToken = result.user.idToken?.tokenString else {
            throw AuthError.missingToken
        }
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        let authResult = try await Auth.auth().signIn(with: credential)
        return try await fetchOrCreateUser(from: authResult.user)
    }

    // MARK: Apple Sign-In

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) async throws -> RoomieUser {
        guard let appleIDToken = credential.identityToken,
              let tokenString = String(data: appleIDToken, encoding: .utf8) else {
            throw AuthError.missingToken
        }
        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: tokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        let authResult = try await Auth.auth().signIn(with: firebaseCredential)
        return try await fetchOrCreateUser(from: authResult.user)
    }

    // MARK: Sign Out

    func signOut() throws {
        try Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    // MARK: User Document

    func fetchOrCreateUser(from firebaseUser: FirebaseAuth.User) async throws -> RoomieUser {
        let ref = db.collection("users").document(firebaseUser.uid)
        let snapshot = try await ref.getDocument()

        if snapshot.exists, let user = try? snapshot.data(as: RoomieUser.self) {
            return user
        }

        let newUser = RoomieUser(
            id: firebaseUser.uid,
            displayName: firebaseUser.displayName ?? "Roomie",
            email: firebaseUser.email ?? "",
            photoURL: firebaseUser.photoURL?.absoluteString,
            householdIds: [],
            createdAt: Date()
        )
        try ref.setData(from: newUser)
        return newUser
    }

    // MARK: Apple Nonce Helpers

    static func randomNonce(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce: \(errorCode)")
        }
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}

// MARK: - Errors

enum AuthError: LocalizedError {
    case missingClientID
    case missingToken

    var errorDescription: String? {
        switch self {
        case .missingClientID: return "Firebase client ID is not configured."
        case .missingToken:    return "Authentication token was missing or invalid."
        }
    }
}
