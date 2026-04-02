import Foundation
import FirebaseFirestore

@MainActor
final class ChoreViewModel: ObservableObject {

    @Published var activeChores: [Chore] = []
    @Published var pendingChores: [Chore] = []
    @Published var weeklyCompletions: [String: [ChoreCompletion]] = [:]  // choreId → completions
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let service: ChoreServiceProtocol
    private var listener: ListenerRegistration?

    var householdId: String
    var currentUserId: String

    init(householdId: String, currentUserId: String, service: ChoreServiceProtocol = ChoreService()) {
        self.householdId = householdId
        self.currentUserId = currentUserId
        self.service = service
        startListening()
    }

    deinit { listener?.remove() }

    // MARK: - Listening

    func startListening() {
        listener?.remove()
        listener = service.listenToChores(householdId: householdId) { [weak self] chores in
            guard let self else { return }
            self.activeChores = chores.filter { $0.status == .active }
            self.pendingChores = chores.filter { $0.status == .pending }
        }
    }

    // MARK: - Propose

    func proposeChore(
        title: String,
        description: String,
        frequency: ChoreFrequency,
        assignablePool: [String],
        excludeLastAssignee: Bool
    ) async {
        let chore = Chore(
            id: UUID().uuidString,
            householdId: householdId,
            title: title,
            description: description,
            frequency: frequency,
            assignablePool: assignablePool,
            approvals: [:],
            status: .pending,
            nextDueDate: Date(),
            currentAssigneeId: nil,
            excludeLastAssignee: excludeLastAssignee,
            completionCounts: [:],
            lastCompletedBy: nil,
            createdBy: currentUserId,
            createdAt: Date()
        )
        do {
            try await service.proposeChore(chore)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Voting

    func vote(choreId: String, approved: Bool) async {
        do {
            try await service.castVote(
                householdId: householdId,
                choreId: choreId,
                userId: currentUserId,
                approved: approved
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Returns the current user's vote for a given chore, if cast
    func myVote(for chore: Chore) -> Bool? {
        chore.approvals[currentUserId]
    }

    /// True if the current user still needs to vote on this chore
    func needsMyVote(for chore: Chore) -> Bool {
        chore.status == .pending && chore.approvals[currentUserId] == nil
    }

    // MARK: - Completion

    func markComplete(choreId: String) async {
        do {
            try await service.markComplete(
                householdId: householdId,
                choreId: choreId,
                userId: currentUserId
            )
            await loadWeeklyCompletions(for: choreId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Archive

    func archiveChore(_ choreId: String) async {
        do {
            try await service.archiveChore(householdId: householdId, choreId: choreId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Weekly Schedule

    func loadWeeklyCompletions(for choreId: String) async {
        do {
            let completions = try await service.fetchCompletions(
                householdId: householdId,
                choreId: choreId,
                weekOf: Date()
            )
            weeklyCompletions[choreId] = completions
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadAllWeeklyCompletions() async {
        await withTaskGroup(of: Void.self) { group in
            for chore in activeChores {
                group.addTask { await self.loadWeeklyCompletions(for: chore.id) }
            }
        }
    }

    // MARK: - Helpers

    var myAssignedChores: [Chore] {
        activeChores.filter { $0.currentAssigneeId == currentUserId }
    }

    func isCompleted(_ chore: Chore) -> Bool {
        weeklyCompletions[chore.id]?.isEmpty == false
    }

    func completedBy(_ chore: Chore, memberNames: [String: String]) -> String? {
        guard let completion = weeklyCompletions[chore.id]?.first else { return nil }
        return memberNames[completion.completedBy]
    }
}
