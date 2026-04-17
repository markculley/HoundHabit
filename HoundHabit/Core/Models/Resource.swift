import Foundation

struct Resource: Codable, Identifiable, Hashable {
    let id: UUID
    let ownerId: UUID
    let addedById: UUID
    let guardianId: UUID
    let kind: ResourceKind
    var url: String?
    var body: String?
    var title: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId    = "owner_id"
        case addedById  = "added_by_id"
        case guardianId = "guardian_id"
        case kind, url, body, title
        case createdAt  = "created_at"
    }
}

enum ResourceKind: String, Codable, CaseIterable, Identifiable {
    case photo
    case url
    case note

    var id: String { rawValue }

    var label: String {
        switch self {
        case .photo: return "Photo"
        case .url:   return "URL"
        case .note:  return "Note"
        }
    }

    var systemImage: String {
        switch self {
        case .photo: return "photo"
        case .url:   return "link"
        case .note:  return "note.text"
        }
    }
}
