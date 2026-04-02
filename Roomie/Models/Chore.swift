import Foundation

struct Chore: Codable, Identifiable {
    let id: String
    var householdId: String
    var title: String
    var description: String
    var frequency: ChoreFrequency
    var assignablePool: [String]            // userIds eligible for assignment
    var approvals: [String: Bool]           // userId → approved/rejected
    var status: ChoreStatus
    var nextDueDate: Date
    var currentAssigneeId: String?
    var lastAssignedTo: String?
    /// Running tally of completions per user — used for fairness-weighted assignment
    var completionCounts: [String: Int]
    var createdBy: String
    var createdAt: Date

    // MARK: - Ratification helpers

    /// True once every pool member has cast an approval vote
    func isFullyRatified(memberIds: [String]) -> Bool {
        memberIds.allSatisfy { approvals[$0] == true }
    }

    /// True if any member has rejected the proposal
    var isRejected: Bool {
        approvals.values.contains(false)
    }

    // MARK: - Probabilistic assignment

    /// Returns the next assignee using fairness-weighted random selection.
    /// Members with fewer completions receive proportionally higher weight.
    func selectNextAssignee(excluding excluded: String? = nil) -> String? {
        let candidates = assignablePool.filter { $0 != excluded }
        guard !candidates.isEmpty else { return assignablePool.first }

        let weights = candidates.map { userId in
            1.0 / Double((completionCounts[userId] ?? 0) + 1)
        }
        let total = weights.reduce(0, +)
        var roll = Double.random(in: 0..<total)

        for (index, weight) in weights.enumerated() {
            roll -= weight
            if roll <= 0 { return candidates[index] }
        }
        return candidates.last
    }
}

enum ChoreFrequency: String, Codable, CaseIterable {
    case daily      = "Daily"
    case biWeekly   = "Bi-Weekly"
    case weekly     = "Weekly"
    case biMonthly  = "Bi-Monthly"
    case monthly    = "Monthly"

    /// Calendar component value to advance nextDueDate
    var calendarAdvance: (component: Calendar.Component, value: Int) {
        switch self {
        case .daily:     return (.day, 1)
        case .biWeekly:  return (.day, 3)
        case .weekly:    return (.weekOfYear, 1)
        case .biMonthly: return (.day, 14)
        case .monthly:   return (.month, 1)
        }
    }
}

enum ChoreStatus: String, Codable {
    case pending   = "Pending"    // Awaiting full ratification
    case active    = "Active"     // Ratified and scheduled
    case archived  = "Archived"   // Retired
}

struct ChoreCompletion: Codable, Identifiable {
    let id: String
    var choreId: String
    var completedBy: String     // userId
    var completedAt: Date
    /// The Monday of the week this completion belongs to, for weekly schedule grouping
    var weekOf: Date
}
