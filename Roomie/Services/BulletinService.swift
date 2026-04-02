import Foundation
import FirebaseFirestore
import FirebaseMessaging

protocol BulletinServiceProtocol {
    func fetchBulletins(householdId: String) async throws -> [Bulletin]
    func postBulletin(_ bulletin: Bulletin) async throws
    func updateBulletin(_ bulletin: Bulletin) async throws
    func deleteBulletin(householdId: String, bulletinId: String) async throws
    func togglePin(householdId: String, bulletinId: String, isPinned: Bool) async throws
    func listenToBulletins(householdId: String, onChange: @escaping ([Bulletin]) -> Void) -> ListenerRegistration
}

final class BulletinService: BulletinServiceProtocol {

    private let db = Firestore.firestore()

    private func bulletinsRef(householdId: String) -> CollectionReference {
        db.collection("households").document(householdId).collection("bulletins")
    }

    // MARK: Fetch

    func fetchBulletins(householdId: String) async throws -> [Bulletin] {
        let snapshot = try await bulletinsRef(householdId: householdId)
            .order(by: "isPinned", descending: true)
            .order(by: "createdAt", descending: true)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Bulletin.self) }
    }

    // MARK: Write

    func postBulletin(_ bulletin: Bulletin) async throws {
        try bulletinsRef(householdId: bulletin.householdId)
            .document(bulletin.id)
            .setData(from: bulletin)

        if bulletin.isUrgent {
            await sendUrgentNotification(bulletin: bulletin)
        }
    }

    func updateBulletin(_ bulletin: Bulletin) async throws {
        var updated = bulletin
        updated.updatedAt = Date()
        try bulletinsRef(householdId: bulletin.householdId)
            .document(bulletin.id)
            .setData(from: updated, merge: true)
    }

    func deleteBulletin(householdId: String, bulletinId: String) async throws {
        try await bulletinsRef(householdId: householdId).document(bulletinId).delete()
    }

    func togglePin(householdId: String, bulletinId: String, isPinned: Bool) async throws {
        try await bulletinsRef(householdId: householdId).document(bulletinId)
            .updateData(["isPinned": isPinned, "updatedAt": Timestamp(date: Date())])
    }

    // MARK: Listener

    func listenToBulletins(householdId: String, onChange: @escaping ([Bulletin]) -> Void) -> ListenerRegistration {
        bulletinsRef(householdId: householdId)
            .order(by: "isPinned", descending: true)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, _ in
                let bulletins = snapshot?.documents.compactMap { try? $0.data(as: Bulletin.self) } ?? []
                onChange(bulletins)
            }
    }

    // MARK: Push Notification

    /// Sends a push notification to the household topic for urgent bulletins.
    /// Requires Firebase Cloud Messaging topic subscriptions per household.
    private func sendUrgentNotification(bulletin: Bulletin) async {
        // Notification is triggered server-side via a Firebase Cloud Function
        // that listens to writes on /households/{id}/bulletins where isUrgent == true.
        // Client-side: each member subscribes to "household_\(householdId)" topic on sign-in.
        let topic = "household_\(bulletin.householdId)"
        try? await Messaging.messaging().subscribe(toTopic: topic)
    }
}
