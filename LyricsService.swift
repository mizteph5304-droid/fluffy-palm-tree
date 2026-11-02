import Foundation

/// Line of timed lyrics (LRC).
struct LyricLine: Identifiable, Hashable {
    let id = UUID()
    let time: TimeInterval   // seconds
    let text: String
}

enum LyricsStatus: Equatable {
    case idle
    case loading
    case found(synced: Bool)
    case instrumental
    case notFound
    case offline
}

actor LyricsService {
    static let shared = LyricsService()

    private let base = "https://lrclib.net/api"
    private let userAgent = "Pulse iOS/1.0 (local media player)"

    // MARK: - Public

    func find(title: String, artist: String, album: String?, duration: TimeInterval) async -> (status: LyricsStatus, text: String?, matched: String?) {
        let cleanTitle = Self.normalize(title)
        let cleanArtist = Self.normalize(artist)
        guard !cleanTitle.isEmpty else { return (.notFound, nil, nil) }

        let durationSec = duration > 0 ? Int(duration.rounded()) : 0

        // 1. Exact get
        if !cleanArtist.isEmpty {
            if let r = await get(track: title, artist: artist, album: album, duration: durationSec),
               Self.usable(r) {
                return Self.done(r)
            }
        }

        // 2. Search variants
        var queries: [String] = []
        if !cleanArtist.isEmpty {
            queries.append("track_name=\(enc(title))&artist_name=\(enc(artist))")
            let stripped = title.replacingOccurrences(of: #"\(.*?\)|\[.*?\]"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
            if stripped != title && !stripped.isEmpty {
                queries.append("track_name=\(enc(stripped))&artist_name=\(enc(artist))")
            }
        }
        queries.append("q=\(enc([artist, title].filter { !$0.isEmpty }.joined(separator: " ")))")

        var reachable = false
        for q in queries {
            if let results: [LRCLIBResult] = await search(q) {
                reachable = true
                if let best = Self.pickBest(results, wantTitle: title, duration: durationSec) {
                    return Self.done(best)
                }
            } else {
                // network failure on first attempt → offline
                if !reachable { return (.offline, nil, nil) }
            }
        }
        return (reachable ? .notFound : .offline, nil, nil)
    }

    // MARK: - LRC parsing

    nonisolated static func parseLRC(_ text: String) -> [LyricLine] {
        var lines: [LyricLine] = []
        // [mm:ss.xx] or [mm:ss]
        let pattern = #"\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            let range = NSRange(line.startIndex..., in: line)
            let matches = regex.matches(in: line, range: range)
            for m in matches {
                guard let mRange = Range(m.range(at: 1), in: line),
                      let sRange = Range(m.range(at: 2), in: line) else { continue }
                let minutes = Double(line[mRange]) ?? 0
                let seconds = Double(line[sRange]) ?? 0
                var fraction = 0.0
                if m.range(at: 3).location != NSNotFound,
                   let fRange = Range(m.range(at: 3), in: line) {
                    let fStr = String(line[fRange])
                    let divisor = pow(10.0, Double(fStr.count))
                    fraction = (Double(fStr) ?? 0) / divisor
                }
                let textRange = Range(m.range(at: 4), in: line)
                let body = textRange.map { String(line[$0]).trimmingCharacters(in: .whitespaces) } ?? ""
                if !body.isEmpty {
                    lines.append(LyricLine(time: minutes * 60 + seconds + fraction, text: body))
                }
            }
        }
        return lines.sorted { $0.time < $1.time }
    }

    /// Index of the line that should be highlighted at `time` (with optional offset).
    nonisolated static func activeIndex(in lines: [LyricLine], at time: TimeInterval, offset: Double = 0) -> Int {
        let t = time + offset
        guard !lines.isEmpty else { return -1 }
        var idx = -1
        for (i, line) in lines.enumerated() {
            if line.time <= t { idx = i } else { break }
        }
        return idx
    }

    // MARK: - Networking helpers

    private struct LRCLIBResult: Decodable {
        let trackName: String?
        let artistName: String?
        let albumName: String?
        let duration: Double?
        let instrumental: Bool?
        let plainLyrics: String?
        let syncedLyrics: String?
    }

    private func get(track: String, artist: String, album: String?, duration: Int) async -> LRCLIBResult? {
        var parts = [
            "track_name=\(enc(track))",
            "artist_name=\(enc(artist))"
        ]
        if let album, !album.isEmpty { parts.append("album_name=\(enc(album))") }
        if duration > 0 { parts.append("duration=\(duration)") }
        return await fetch("/get?\(parts.joined(separator: "&))")
    }

    private func search(_ query: String) async -> [LRCLIBResult]? {
        await fetch("/search?\(query)")
    }

    private func fetch<T: Decodable>(_ pathAndQuery: String) async -> T? {
        guard let url = URL(string: base + pathAndQuery) else { return nil }
        var req = URLRequest(url: url)
        req.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        req.timeoutInterval = 8
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            return nil
        }
    }

    private func enc(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }

    private static func usable(_ r: LRCLIBResult) -> Bool {
        r.instrumental == true || (r.syncedLyrics?.isEmpty == false) || (r.plainLyrics?.isEmpty == false)
    }

    private static func done(_ r: LRCLIBResult) -> (LyricsStatus, String?, String?) {
        if r.instrumental == true {
            return (.instrumental, nil, nil)
        }
        let synced = r.syncedLyrics?.isEmpty == false
        let text = synced ? r.syncedLyrics : r.plainLyrics
        let matched = [r.artistName, r.trackName].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " - ")
        return (.found(synced: synced), text, matched.isEmpty ? nil : matched)
    }

    private static func pickBest(_ results: [LRCLIBResult], wantTitle: String, duration: Int) -> LRCLIBResult? {
        let nt = normalize(wantTitle)
        var best: LRCLIBResult?
        var bestScore = -1.0
        for r in results where usable(r) {
            let titleMatch = !nt.isEmpty && normalize(r.trackName ?? "") == nt
            let durKnown = duration > 0 && (r.duration ?? 0) > 0
            if durKnown {
                let diff = abs((r.duration ?? 0) - Double(duration))
                if diff > 5 { continue }
            } else if !titleMatch {
                continue
            }
            var score = 0.0
            if titleMatch { score += 4 }
            if durKnown {
                let diff = abs((r.duration ?? 0) - Double(duration))
                score += 3 - min(3, diff / 2)
            }
            if r.syncedLyrics?.isEmpty == false { score += 3 }
            if score > bestScore {
                best = r
                bestScore = score
            }
        }
        return best
    }

    private static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: #"\(.*?\)|\[.*?\]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\b(feat|ft|featuring)\b.*$"#, with: " ", options: [.regularExpression, .caseInsensitive])
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
