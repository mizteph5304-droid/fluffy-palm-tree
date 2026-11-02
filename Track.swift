import Foundation

struct Track: Identifiable, Codable, Hashable {
    let id: String
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval
    /// Relative path inside the app’s Documents/Music folder, or absolute for security-scoped items.
    var fileName: String
    var added: Date
    var artworkData: Data?
    var lyrics: String?
    var lyricsSource: String?          // "tags" | "lrclib" | "file"
    var lyricsOffset: Double           // seconds
    var lyricsCheckedAt: Date?

    init(
        id: String = UUID().uuidString,
        title: String,
        artist: String = "Unknown Artist",
        album: String = "Unknown Album",
        duration: TimeInterval = 0,
        fileName: String,
        added: Date = Date(),
        artworkData: Data? = nil,
        lyrics: String? = nil,
        lyricsSource: String? = nil,
        lyricsOffset: Double = 0,
        lyricsCheckedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.fileName = fileName
        self.added = added
        self.artworkData = artworkData
        self.lyrics = lyrics
        self.lyricsSource = lyricsSource
        self.lyricsOffset = lyricsOffset
        self.lyricsCheckedAt = lyricsCheckedAt
    }

    var displayTitle: String {
        title.isEmpty ? fileName : title
    }

    var displaySubtitle: String {
        [artist, album].filter { !$0.isEmpty && $0 != "Unknown Artist" && $0 != "Unknown Album" }.joined(separator: " · ")
    }
}
