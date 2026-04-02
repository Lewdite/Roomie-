import Foundation
import FirebaseAuth
import Combine

@MainActor
final class AuthViewModel: ObservableObject {

    @Published var currentUser: RoomieUser?
    @Published var currentHousehold: Household?
    @Published var householdMembers: [RoomieUser] = []
    @Published var isLoading = true
    @Published var errorMessage: String?

    private let authService: AuthServiceProtocol
    private let householdService: HouseholdServiceProtocol
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var householdListener: ListenerRegistration?

    init(
        authService: AuthServiceProtocol = AuthService(),
        householdService: HouseholdServiceProtocol = HouseholdService()
    ) {
        self.authService = authService
        self.householdService = householdService
        listenToAuthState()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
        householdListener?.remove()
    }

    // MARK: - Auth State

    private func listenToAuthState() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self else { return }
            Task {
                if let firebaseUser {
                    do {
                        let user = try await self.authService.fetchOrCreateUser(from: firebaseUser)
                        self.currentUser = user
                        await self.loadHousehold(for: user)
                    } catch {
                        self.errorMessage = error.localizedDescription
                    }
                } else {
                    self.currentUser = nil
                    self.currentHousehold = nil
                    self.householdMembers = []
                }
                self.isLoading = false
            }
        }
    }

    // MARK: - Sign In

    func signInWithGoogle(presenting viewController: UIViewController) {
        Task {
            do {
                let user = try await authService.signInWithGoogle(presenting: viewController)
                currentUser = user
                await loadHousehold(for: user)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signInWithApple(credential: ASAuthorizationAppleIDCredential, nonce: String) {
        Task {
            do {
                let user = try await authService.signInWithApple(credential: credential, nonce: nonce)
                currentUser = user
                await loadHousehold(for: user)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() {
        do {
            try authService.signOut()
            currentUser = nil
            currentHousehold = nil
            householdMembers = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Household

    func createHousehold(name: String) async {
        guard let userId = currentUser?.id else { return }
        do {
            let household = try await householdService.createHousehold(name: name, adminId: userId)
            currentHousehold = household
            await refreshMembers()
            listenToHouseholdChanges(id: household.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func joinHousehold(inviteCode: String) async {
        guard let userId = currentUser?.id else { return }
        do {
            let household = try await householdService.joinHousehold(inviteCode: inviteCode, userId: userId)
            currentHousehold = household
            await refreshMembers()
            listenToHouseholdChanges(id: household.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadHousehold(for user: RoomieUser) async {
        guard let householdId = user.householdIds.first else { return }
        do {
            let household = try await householdService.fetchHousehold(id: householdId)
            currentHousehold = household
            await refreshMembers()
            listenToHouseholdChanges(id: householdId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func refreshMembers() async {
        guard let householdId = currentHousehold?.id else { return }
        do {
            householdMembers = try await householdService.fetchMembers(householdId: householdId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func listenToHouseholdChanges(id: String) {
        householdListener?.remove()
        householdListener = householdService.listenToHousehold(id: id) { [weak self] updated in
            self?.currentHousehold = updated
        }
    }

    // MARK: - Helpers

    func displayName(for userId: String) -> String {
        householdMembers.first { $0.id == userId }?.displayName ?? "Unknown"
    }
}
