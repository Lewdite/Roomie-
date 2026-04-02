import Foundation

struct Bulletin: Codable, Identifiable {
    let id: String
    var householdId: String
    var title: String
    var content: String
    var authorId: String
    var isPinned: Bool
    var isUrgent: Bool
    var createdAt: Date
    var updatedAt: Date
}
