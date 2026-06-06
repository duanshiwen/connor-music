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
        
        // AVFoundation's commonMetadata is not populated for every audio format.
        // In particular, FLAC stores tags as Vorbis Comment metadata
        // (format: org.xiph.vorbis-comment), so we read both commonMetadata and
        // format-specific metadata and merge the first useful values we find.
        if let metadata = try? await asset.load(.commonMetadata) {
            await applyMetadataItems(
                metadata,
                title: &loadedTitle,
                artist: &loadedArtist,
                album: &loadedAlbum,
                artwork: &loadedArtwork
            )
        }
        
        if let formats = try? await asset.load(.availableMetadataFormats) {
            for format in formats {
                guard needsMoreMetadata(title: loadedTitle, artist: loadedArtist, album: loadedAlbum, artwork: loadedArtwork),
                      let metadata = try? await asset.loadMetadata(for: format) else {
                    continue
                }
                await applyMetadataItems(
                    metadata,
                    title: &loadedTitle,
                    artist: &loadedArtist,
                    album: &loadedAlbum,
                    artwork: &loadedArtwork
                )
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
    
    private func applyMetadataItems(
        _ items: [AVMetadataItem],
        title: inout String?,
        artist: inout String?,
        album: inout String?,
        artwork: inout NSImage?
    ) async {
        for item in items {
            if title == nil, item.matchesCommonKey(.commonKeyTitle) || item.matchesRawKey("TITLE") {
                title = await item.nonEmptyStringValue()
            } else if artist == nil, item.matchesCommonKey(.commonKeyArtist) || item.matchesRawKey("ARTIST") {
                artist = await item.nonEmptyStringValue()
            } else if album == nil, item.matchesCommonKey(.commonKeyAlbumName) || item.matchesRawKey("ALBUM") {
                album = await item.nonEmptyStringValue()
            } else if artwork == nil, item.matchesCommonKey(.commonKeyArtwork) || item.matchesRawKey("METADATA_BLOCK_PICTURE") || item.matchesRawKey("COVERART") {
                if let data = try? await item.load(.dataValue) {
                    artwork = NSImage(data: data)
                }
            }
        }
    }
    
    private func needsMoreMetadata(title: String?, artist: String?, album: String?, artwork: NSImage?) -> Bool {
        title == nil || artist == nil || album == nil || artwork == nil
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

private extension AVMetadataItem {
    func matchesCommonKey(_ expectedKey: AVMetadataKey) -> Bool {
        commonKey == expectedKey
    }
    
    func matchesRawKey(_ expectedKey: String) -> Bool {
        guard let key else { return false }
        return String(describing: key).caseInsensitiveCompare(expectedKey) == .orderedSame
    }
    
    func nonEmptyStringValue() async -> String? {
        guard let value = try? await load(.stringValue) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
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
