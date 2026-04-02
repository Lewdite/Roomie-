import Foundation

struct Expense: Codable, Identifiable {
    let id: String
    var householdId: String
    var title: String
    var amount: Double
    var paidBy: String              // userId
    var splitAmong: [String]        // userIds; equal split among these members
    var category: ExpenseCategory
    var isRecurring: Bool
    var recurrenceFrequency: RecurrenceFrequency?
    var imageURL: String?           // Compressed receipt image (Firebase Storage)
    var imageExpiresAt: Date?       // Auto-deleted after 60 days
    var month: String               // "YYYY-MM" — the billing month this belongs to
    var settlements: [Settlement]
    var createdBy: String
    var createdAt: Date

    /// Each member's share of this expense
    var sharePerPerson: Double {
        guard !splitAmong.isEmpty else { return amount }
        return amount / Double(splitAmong.count)
    }
}

enum ExpenseCategory: String, Codable, CaseIterable {
    case rent        = "Rent"
    case utilities   = "Utilities"
    case groceries   = "Groceries"
    case internet    = "Internet"
    case subscriptions = "Subscriptions"
    case other       = "Other"
}

enum RecurrenceFrequency: String, Codable, CaseIterable {
    case monthly  = "Monthly"
    case biMonthly = "Bi-Monthly"
    case quarterly = "Quarterly"
    case yearly    = "Yearly"
}

struct Settlement: Codable, Identifiable {
    let id: String
    var fromUserId: String
    var toUserId: String
    var amount: Double
    var isSettled: Bool
    var settledAt: Date?
}
