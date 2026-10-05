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
    var photoJPEG: Data?
    var ocrText: String?
    var peekText: String?
    var peekAppName: String?

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        createdAt: Date = .now,
        photoJPEG: Data? = nil,
        ocrText: String? = nil,
        peekText: String? = nil,
        peekAppName: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.photoJPEG = photoJPEG
        self.ocrText = ocrText
        self.peekText = peekText
        self.peekAppName = peekAppName
    }

    var questionText: String {
        let hasAttach = !(ocrText ?? "").isEmpty || !(peekText ?? "").isEmpty
        guard hasAttach else { return content }
        let marker = "\n\n"
        if let range = content.range(of: marker, options: .backwards) {
            return String(content[range.upperBound...])
        }
        return content
    }
}
