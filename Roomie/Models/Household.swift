import Foundation

struct Household: Codable, Identifiable {
    let id: String
    var name: String
    var memberIds: [String]
    var adminId: String
    var inviteCode: String
    var createdAt: Date
}
