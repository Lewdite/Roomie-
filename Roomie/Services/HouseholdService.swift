import Foundation
import FirebaseFirestore

protocol HouseholdServiceProtocol {
    func createHousehold(name: String, adminId: String) async throws -> Household
    func joinHousehold(inviteCode: String, userId: String) async throws -> Household
    func fetchHousehold(id: String) async throws -> Household
    func fetchMembers(householdId: String) async throws -> [RoomieUser]
    func listenToHousehold(id: String, onChange: @escaping (Household) -> Void) -> ListenerRegistration
}

final class HouseholdService: HouseholdServiceProtocol {

    private let db = Firestore.firestore()

    func createHousehold(name: String, adminId: String) async throws -> Household {
        let inviteCode = generateInviteCode()
        let household = Household(
            id: UUID().uuidString,
            name: name,
            memberIds: [adminId],
            adminId: adminId,
            inviteCode: inviteCode,
            createdAt: Date()
        )
        let ref = db.collection("households").document(household.id)
        try ref.setData(from: household)

        // Add householdId to the user's document
        try await db.collection("users").document(adminId)
            .updateData(["householdIds": FieldValue.arrayUnion([household.id])])

        return household
    }

    func joinHousehold(inviteCode: String, userId: String) async throws -> Household {
        let snapshot = try await db.collection("households")
            .whereField("inviteCode", isEqualTo: inviteCode)
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first,
              var household = try? doc.data(as: Household.self) else {
            throw HouseholdError.invalidInviteCode
        }
        guard !household.memberIds.contains(userId) else { return household }

        household.memberIds.append(userId)
        try doc.reference.setData(from: household)
        try await db.collection("users").document(userId)
            .updateData(["householdIds": FieldValue.arrayUnion([household.id])])

        return household
    }

    func fetchHousehold(id: String) async throws -> Household {
        let doc = try await db.collection("households").document(id).getDocument()
        guard let household = try? doc.data(as: Household.self) else {
            throw HouseholdError.notFound
        }
        return household
    }

    func fetchMembers(householdId: String) async throws -> [RoomieUser] {
        let household = try await fetchHousehold(id: householdId)
        let snapshots = try await withThrowingTaskGroup(of: RoomieUser?.self) { group in
            for memberId in household.memberIds {
                group.addTask {
                    let doc = try await self.db.collection("users").document(memberId).getDocument()
                    return try? doc.data(as: RoomieUser.self)
                }
            }
            var members: [RoomieUser] = []
            for try await member in group {
                if let member { members.append(member) }
            }
            return members
        }
        return snapshots
    }

    func listenToHousehold(id: String, onChange: @escaping (Household) -> Void) -> ListenerRegistration {
        db.collection("households").document(id).addSnapshotListener { snapshot, _ in
            guard let household = try? snapshot?.data(as: Household.self) else { return }
            onChange(household)
        }
    }

    // MARK: - Private

    private func generateInviteCode() -> String {
        let chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        return String((0..<6).compactMap { _ in chars.randomElement() })
    }
}

enum HouseholdError: LocalizedError {
    case invalidInviteCode
    case notFound

    var errorDescription: String? {
        switch self {
        case .invalidInviteCode: return "No household found with that invite code."
        case .notFound:          return "Household not found."
        }
    }
}
