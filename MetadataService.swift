import Foundation
import AVFoundation
import UIKit

enum MetadataService {
    struct Result {
        var title: String?
        var artist: String?
        var album: String?
        var duration: TimeInterval
        var artworkData: Data?
        var lyrics: String?
    }

    static func load(from url: URL) async -> Result {
        let asset = AVURLAsset(url: url)
        var result = Result(duration: 0)

        // Duration
        do {
            let duration = try await asset.load(.duration)
            result.duration = duration.seconds.isFinite ? duration.seconds : 0
        } catch {
            result.duration = 0
        }

        // Common metadata
        do {
            let items = try await asset.load(.commonMetadata)
            for item in items {
                guard let key = item.commonKey else { continue }
                switch key {
                case .commonKeyTitle:
                    result.title = try? await item.load(.stringValue)
                case .commonKeyArtist:
                    result.artist = try? await item.load(.stringValue)
                case .commonKeyAlbumName:
                    result.album = try? await item.load(.stringValue)
                case .commonKeyArtwork:
                    if let data = try? await item.load(.dataValue) {
                        result.artworkData = data
                    }
                default:
                    break
                }
            }
        } catch { /* ignore */ }

        // Fallback filename-based title
        if result.title == nil || result.title?.isEmpty == true {
            result.title = url.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
        }

        // Try lyrics from available metadata formats
        if result.lyrics == nil {
            result.lyrics = await extractLyrics(from: asset)
        }

        return result
    }

    private static func extractLyrics(from asset: AVAsset) async -> String? {
        // AVMetadataKeySpaceID3 / iTunes sometimes expose lyrics
        do {
            let formats = try await asset.load(.availableMetadataFormats)
            for format in formats {
                let items = try await asset.loadMetadata(for: format)
                for item in items {
                    let key = (try? await item.load(.key)) as? String
                    let space = try? await item.load(.keySpace)
                    // Common lyric keys
                    if key == "USLT" || key == "©lyr" || key == "lyrics" ||
                        (space == .id3 && key?.uppercased().contains("LYR") == true) {
                        if let s = try? await item.load(.stringValue), !s.isEmpty {
                            return s
                        }
                        if let data = try? await item.load(.dataValue),
                           let s = String(data: data, encoding: .utf8), !s.isEmpty {
                            return s
                        }
                    }
                }
            }
        } catch { /* ignore */ }
        return nil
    }

    /// Resize artwork for storage / display.
    static func thumbnail(from data: Data, maxSide: CGFloat = 600) -> Data? {
        guard let image = UIImage(data: data) else { return data }
        let size = image.size
        let scale = min(1, maxSide / max(size.width, size.height))
        if scale >= 0.99 { return data }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.85)
    }
}
