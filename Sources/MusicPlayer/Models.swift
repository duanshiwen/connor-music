import Foundation
import AVFoundation
import AppKit

// MARK: - Track

final class Track: Identifiable, ObservableObject, Equatable {
    let id: UUID
    let url: URL
    
    @Published var title: String
    @Published var artist: String
    @Published var album: String
    @Published var duration: TimeInterval
    
    @Published var artwork: NSImage?
    
    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.artist = "未知艺术家"
        self.album = "未知专辑"
        self.duration = 0
        self.artwork = nil
    }
    
    func loadMetadata() async {
        let asset = AVURLAsset(url: url)
        var loadedTitle: String?
        var loadedArtist: String?
        var loadedAlbum: String?
        var loadedDuration: TimeInterval?
        var loadedArtwork: NSImage?
        
        // Duration
        if let d = try? await asset.load(.duration), d.isValid && !d.isIndefinite {
            loadedDuration = CMTimeGetSeconds(d)
        }
        
        // Metadata
        if let metadata = try? await asset.load(.commonMetadata) {
            for item in metadata {
                if let key = item.commonKey {
                    switch key {
                    case .commonKeyTitle:
                        loadedTitle = try? await item.load(.stringValue)
                    case .commonKeyArtist:
                        loadedArtist = try? await item.load(.stringValue)
                    case .commonKeyAlbumName:
                        loadedAlbum = try? await item.load(.stringValue)
                    case .commonKeyArtwork:
                        if let data = try? await item.load(.dataValue) {
                            loadedArtwork = NSImage(data: data)
                        }
                    default:
                        break
                    }
                }
            }
        }
        
        let metadata = TrackMetadata(
            title: loadedTitle,
            artist: loadedArtist,
            album: loadedAlbum,
            duration: loadedDuration,
            artwork: loadedArtwork
        )
        
        await MainActor.run {
            if let duration = metadata.duration { self.duration = duration }
            if let title = metadata.title { self.title = title }
            if let artist = metadata.artist { self.artist = artist }
            if let album = metadata.album { self.album = album }
            if let artwork = metadata.artwork { self.artwork = artwork }
        }
    }
    
    func applyOverride(_ override: TrackMetadataOverride?) {
        guard let override else { return }
        if let title = override.title { self.title = title }
        if let artist = override.artist { self.artist = artist }
        if let album = override.album { self.album = album }
    }
    
    var formattedDuration: String {
        guard duration > 0 else { return "--:--" }
        let m = Int(duration) / 60
        let s = Int(duration) % 60
        return String(format: "%d:%02d", m, s)
    }
    
    static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Track Metadata

private struct TrackMetadata {
    let title: String?
    let artist: String?
    let album: String?
    let duration: TimeInterval?
    let artwork: NSImage?
}

// MARK: - Playback State

enum PlaybackState: Equatable {
    case idle
    case playing
    case paused
}

// MARK: - Repeat Mode

enum RepeatMode: String, CaseIterable {
    case off = "不循环"
    case all = "全部循环"
    case one = "单曲循环"
    
    var icon: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

// MARK: - Audio Format Support

enum AudioFormats {
    static let supported: Set<String> = [
        "mp3", "m4a", "m4b", "aac", "wav", "aiff", "aif",
        "caf", "alac", "flac", "ogg", "opus", "wma"
    ]
    
    static func isSupported(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return supported.contains(ext)
    }
}
