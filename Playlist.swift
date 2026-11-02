import Foundation

struct Playlist: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var trackIds: [String]
    var created: Date

    init(id: String = UUID().uuidString, name: String, trackIds: [String] = [], created: Date = Date()) {
        self.id = id
        self.name = name
        self.trackIds = trackIds
        self.created = created
    }
}
