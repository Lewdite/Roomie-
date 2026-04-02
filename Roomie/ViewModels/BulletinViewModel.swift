import Foundation
import FirebaseFirestore

@MainActor
final class BulletinViewModel: ObservableObject {

    @Published var bulletins: [Bulletin] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: BulletinServiceProtocol
    private var listener: ListenerRegistration?

    var householdId: String
    var currentUserId: String

    init(householdId: String, currentUserId: String, service: BulletinServiceProtocol = BulletinService()) {
        self.householdId = householdId
        self.currentUserId = currentUserId
        self.service = service
        startListening()
    }

    deinit { listener?.remove() }

    func startListening() {
        listener?.remove()
        listener = service.listenToBulletins(householdId: householdId) { [weak self] updated in
            self?.bulletins = updated
        }
    }

    func post(title: String, content: String, isUrgent: Bool) async {
        let bulletin = Bulletin(
            id: UUID().uuidString,
            householdId: householdId,
            title: title,
            content: content,
            authorId: currentUserId,
            isPinned: false,
            isUrgent: isUrgent,
            createdAt: Date(),
            updatedAt: Date()
        )
        do {
            try await service.postBulletin(bulletin)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func togglePin(_ bulletin: Bulletin) async {
        do {
            try await service.togglePin(
                householdId: householdId,
                bulletinId: bulletin.id,
                isPinned: !bulletin.isPinned
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func delete(_ bulletin: Bulletin) async {
        guard bulletin.authorId == currentUserId else { return }
        do {
            try await service.deleteBulletin(householdId: householdId, bulletinId: bulletin.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    var pinnedBulletins: [Bulletin] { bulletins.filter { $0.isPinned } }
    var unpinnedBulletins: [Bulletin] { bulletins.filter { !$0.isPinned } }
}
