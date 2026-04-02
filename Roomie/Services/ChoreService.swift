import Foundation
import FirebaseFirestore

protocol ChoreServiceProtocol {
    func fetchChores(householdId: String) async throws -> [Chore]
    func proposeChore(_ chore: Chore) async throws
    func castVote(householdId: String, choreId: String, userId: String, approved: Bool) async throws
    func assignChore(householdId: String, choreId: String) async throws -> String?
    func markComplete(householdId: String, choreId: String, userId: String) async throws
    func archiveChore(householdId: String, choreId: String) async throws
    func fetchCompletions(householdId: String, choreId: String, weekOf: Date) async throws -> [ChoreCompletion]
    func listenToChores(householdId: String, onChange: @escaping ([Chore]) -> Void) -> ListenerRegistration
}

final class ChoreService: ChoreServiceProtocol {

    private let db = Firestore.firestore()

    private func choresRef(householdId: String) -> CollectionReference {
        db.collection("households").document(householdId).collection("chores")
    }

    private func completionsRef(householdId: String, choreId: String) -> CollectionReference {
        choresRef(householdId: householdId).document(choreId).collection("completions")
    }

    // MARK: Fetch

    func fetchChores(householdId: String) async throws -> [Chore] {
        let snapshot = try await choresRef(householdId: householdId)
            .whereField("status", isNotEqualTo: ChoreStatus.archived.rawValue)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: Chore.self) }
    }

    // MARK: Propose

    func proposeChore(_ chore: Chore) async throws {
        try choresRef(householdId: chore.householdId)
            .document(chore.id)
            .setData(from: chore)
    }

    // MARK: Voting

    func castVote(householdId: String, choreId: String, userId: String, approved: Bool) async throws {
        let ref = choresRef(householdId: householdId).document(choreId)
        let snapshot = try await ref.getDocument()
        guard var chore = try? snapshot.data(as: Chore.self) else { return }

        chore.approvals[userId] = approved

        // If any member rejects, keep pending so proposer can revise
        if !approved {
            chore.status = .pending
        } else if chore.approvals.values.allSatisfy({ $0 }) &&
                  chore.approvals.count == chore.assignablePool.count {
            // All pool members approved — activate
            chore.status = .active
            if chore.currentAssigneeId == nil {
                chore.currentAssigneeId = chore.selectNextAssignee()
            }
        }

        try ref.setData(from: chore)
    }

    // MARK: Assignment

    /// Probabilistically selects the next assignee and updates Firestore.
    /// Returns the selected userId.
    @discardableResult
    func assignChore(householdId: String, choreId: String) async throws -> String? {
        let ref = choresRef(householdId: householdId).document(choreId)
        let snapshot = try await ref.getDocument()
        guard var chore = try? snapshot.data(as: Chore.self) else { return nil }

        let assignee = chore.selectNextAssignee(excluding: chore.lastAssignedTo)
        chore.currentAssigneeId = assignee
        chore.lastAssignedTo = assignee
        try ref.setData(from: chore)
        return assignee
    }

    // MARK: Completion

    func markComplete(householdId: String, choreId: String, userId: String) async throws {
        let ref = choresRef(householdId: householdId).document(choreId)
        let snapshot = try await ref.getDocument()
        guard var chore = try? snapshot.data(as: Chore.self) else { return }

        // Log the completion
        let weekOf = Calendar.current.startOfWeek(for: Date())
        let completion = ChoreCompletion(
            id: UUID().uuidString,
            choreId: choreId,
            completedBy: userId,
            completedAt: Date(),
            weekOf: weekOf
        )
        try completionsRef(householdId: householdId, choreId: choreId)
            .document(completion.id)
            .setData(from: completion)

        // Update completion counts and advance schedule
        chore.completionCounts[userId, default: 0] += 1
        chore.lastAssignedTo = userId

        let (component, value) = chore.frequency.calendarAdvance
        chore.nextDueDate = Calendar.current.date(
            byAdding: component, value: value, to: chore.nextDueDate
        ) ?? chore.nextDueDate

        // Assign next person
        chore.currentAssigneeId = chore.selectNextAssignee(excluding: userId)

        try ref.setData(from: chore)
    }

    // MARK: Archive

    func archiveChore(householdId: String, choreId: String) async throws {
        try await choresRef(householdId: householdId).document(choreId)
            .updateData(["status": ChoreStatus.archived.rawValue])
    }

    // MARK: Completions

    func fetchCompletions(householdId: String, choreId: String, weekOf: Date) async throws -> [ChoreCompletion] {
        let weekStart = Calendar.current.startOfWeek(for: weekOf)
        let weekEnd = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        let snapshot = try await completionsRef(householdId: householdId, choreId: choreId)
            .whereField("completedAt", isGreaterThanOrEqualTo: weekStart)
            .whereField("completedAt", isLessThan: weekEnd)
            .getDocuments()
        return snapshot.documents.compactMap { try? $0.data(as: ChoreCompletion.self) }
    }

    // MARK: Listener

    func listenToChores(householdId: String, onChange: @escaping ([Chore]) -> Void) -> ListenerRegistration {
        choresRef(householdId: householdId)
            .whereField("status", isNotEqualTo: ChoreStatus.archived.rawValue)
            .addSnapshotListener { snapshot, _ in
                let chores = snapshot?.documents.compactMap { try? $0.data(as: Chore.self) } ?? []
                onChange(chores)
            }
    }
}
