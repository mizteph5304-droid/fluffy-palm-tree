import Foundation
import UniformTypeIdentifiers

@MainActor
final class LibraryStore: ObservableObject {
    @Published private(set) var tracks: [Track] = []
    @Published private(set) var playlists: [Playlist] = []
    @Published var isImporting = false
    @Published var importProgress: String?

    private let fileManager = FileManager.default
    private var musicDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let music = docs.appendingPathComponent("Music", isDirectory: true)
        if !fileManager.fileExists(atPath: music.path) {
            try? fileManager.createDirectory(at: music, withIntermediateDirectories: true)
        }
        return music
    }

    private var libraryFileURL: URL {
        let support = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if !fileManager.fileExists(atPath: support.path) {
            try? fileManager.createDirectory(at: support, withIntermediateDirectories: true)
        }
        return support.appendingPathComponent("pulse-library.json")
    }

    // MARK: - Persistence

    struct Snapshot: Codable {
        var tracks: [Track]
        var playlists: [Playlist]
    }

    func load() async {
        guard fileManager.fileExists(atPath: libraryFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: libraryFileURL)
            let snap = try JSONDecoder().decode(Snapshot.self, from: data)
            // Prune missing files
            let valid = snap.tracks.filter { track in
                let url = fileURL(for: track)
                return fileManager.fileExists(atPath: url.path)
            }
            tracks = valid
            // Clean playlists of missing track ids
            let ids = Set(valid.map(\.id))
            playlists = snap.playlists.map { pl in
                var p = pl
                p.trackIds = p.trackIds.filter { ids.contains($0) }
                return p
            }
            if valid.count != snap.tracks.count {
                await save()
            }
        } catch {
            print("Library load error:", error)
        }
    }

    func save() async {
        let snap = Snapshot(tracks: tracks, playlists: playlists)
        do {
            let data = try JSONEncoder().encode(snap)
            try data.write(to: libraryFileURL, options: .atomic)
        } catch {
            print("Library save error:", error)
        }
    }

    // MARK: - File access

    func fileURL(for track: Track) -> URL {
        musicDirectory.appendingPathComponent(track.fileName)
    }

    // MARK: - Import

    private static let audioTypes: [UTType] = [
        .mp3, .mpeg4Audio, .wav, .aiff,
        UTType(filenameExtension: "flac") ?? .audio,
        UTType(filenameExtension: "m4a") ?? .mpeg4Audio,
        UTType(filenameExtension: "aac") ?? .audio,
        UTType(filenameExtension: "ogg") ?? .audio,
        UTType(filenameExtension: "opus") ?? .audio
    ]

    func importFiles(urls: [URL]) async {
        isImporting = true
        defer {
            isImporting = false
            importProgress = nil
        }

        var added: [Track] = []
        for (idx, src) in urls.enumerated() {
            importProgress = "Importing \(idx + 1) of \(urls.count)…"
            let accessed = src.startAccessingSecurityScopedResource()
            defer { if accessed { src.stopAccessingSecurityScopedResource() } }

            let ext = src.pathExtension.lowercased()
            let destName = uniqueFileName(base: src.deletingPathExtension().lastPathComponent, ext: ext)
            let dest = musicDirectory.appendingPathComponent(destName)

            do {
                if fileManager.fileExists(atPath: dest.path) {
                    try fileManager.removeItem(at: dest)
                }
                try fileManager.copyItem(at: src, to: dest)

                let meta = await MetadataService.load(from: dest)
                var art = meta.artworkData
                if let a = art {
                    art = MetadataService.thumbnail(from: a) ?? a
                }

                let track = Track(
                    title: meta.title ?? src.deletingPathExtension().lastPathComponent,
                    artist: meta.artist ?? "Unknown Artist",
                    album: meta.album ?? "Unknown Album",
                    duration: meta.duration,
                    fileName: destName,
                    artworkData: art,
                    lyrics: meta.lyrics,
                    lyricsSource: meta.lyrics != nil ? "tags" : nil
                )
                added.append(track)
            } catch {
                print("Import failed for \(src.lastPathComponent):", error)
            }
        }

        if !added.isEmpty {
            tracks.insert(contentsOf: added, at: 0)
            await save()
        }
    }

    private func uniqueFileName(base: String, ext: String) -> String {
        var name = "\(base).\(ext)"
        var counter = 1
        while fileManager.fileExists(atPath: musicDirectory.appendingPathComponent(name).path) {
            name = "\(base)-\(counter).\(ext)"
            counter += 1
        }
        return name
    }

    // MARK: - Library mutations

    func removeTracks(ids: Set<String>) async {
        let toRemove = tracks.filter { ids.contains($0.id) }
        for t in toRemove {
            let url = fileURL(for: t)
            try? fileManager.removeItem(at: url)
        }
        tracks.removeAll { ids.contains($0.id) }
        playlists = playlists.map { pl in
            var p = pl
            p.trackIds = p.trackIds.filter { !ids.contains($0) }
            return p
        }
        await save()
    }

    func updateTrack(_ track: Track) async {
        guard let idx = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        tracks[idx] = track
        await save()
    }

    func clearLibrary() async {
        for t in tracks {
            try? fileManager.removeItem(at: fileURL(for: t))
        }
        tracks = []
        playlists = []
        await save()
    }

    // MARK: - Playlists

    func createPlaylist(name: String) async -> Playlist {
        let pl = Playlist(name: name)
        playlists.append(pl)
        await save()
        return pl
    }

    func renamePlaylist(id: String, name: String) async {
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[idx].name = name
        await save()
    }

    func deletePlaylist(id: String) async {
        playlists.removeAll { $0.id == id }
        await save()
    }

    func addTracks(_ trackIds: [String], toPlaylist id: String) async {
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        let existing = Set(playlists[idx].trackIds)
        let newOnes = trackIds.filter { !existing.contains($0) }
        playlists[idx].trackIds.append(contentsOf: newOnes)
        await save()
    }

    func removeTrack(_ trackId: String, fromPlaylist id: String) async {
        guard let idx = playlists.firstIndex(where: { $0.id == id }) else { return }
        playlists[idx].trackIds.removeAll { $0 == trackId }
        await save()
    }

    func tracks(for playlist: Playlist) -> [Track] {
        let map = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return playlist.trackIds.compactMap { map[$0] }
    }

    // MARK: - Search / sort helpers

    enum Sort: String, CaseIterable {
        case recent, title, artist, album
        var label: String {
            switch self {
            case .recent: return "Recent"
            case .title: return "Title"
            case .artist: return "Artist"
            case .album: return "Album"
            }
        }
    }

    func filtered(search: String, sort: Sort) -> [Track] {
        var list = tracks
        if !search.isEmpty {
            let q = search.lowercased()
            list = list.filter {
                $0.title.lowercased().contains(q) ||
                $0.artist.lowercased().contains(q) ||
                $0.album.lowercased().contains(q)
            }
        }
        switch sort {
        case .recent:
            list.sort { $0.added > $1.added }
        case .title:
            list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            list.sort { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        case .album:
            list.sort { $0.album.localizedCaseInsensitiveCompare($1.album) == .orderedAscending }
        }
        return list
    }
}
