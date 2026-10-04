import Foundation

struct Message: Identifiable, Codable, Sendable, Hashable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
        case system
    }

    let id: UUID
    let role: Role
    var content: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}
