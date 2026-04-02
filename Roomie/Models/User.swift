import Foundation

struct RoomieUser: Codable, Identifiable, Equatable {
    let id: String           // Firebase UID
    var displayName: String
    var email: String
    var photoURL: String?
    var householdIds: [String]
    var createdAt: Date

    static func == (lhs: RoomieUser, rhs: RoomieUser) -> Bool {
        lhs.id == rhs.id
    }
}
