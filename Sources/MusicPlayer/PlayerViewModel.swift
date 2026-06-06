import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class PlayerViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published var playlist: [Track] = []
    @Published var currentIndex: Int? = nil
    @Published var playbackState: PlaybackState = .idle
    @Published var currentTime: TimeInterval = 0
    @Published var shuffleEnabled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var searchText: String = ""
    @Published var editingTrack: Track? = nil
    @Published var metadataEditError: String? = nil
    @Published private(set) var musicFolder: URL?
    
    // MARK: - Private
    
    private let audioEngine = AudioEngine()
    private let folderMonitor = FolderMonitor()
    private var timer: Timer?
    private var shuffleHistory: [Int] = []
    
    var currentTrack: Track? {
        guard let idx = currentIndex, playlist.indices.contains(idx) else { return nil }
        return playlist[idx]
    }
    
    var filteredPlaylist: [Track] {
        guard !searchText.isEmpty else { return playlist }
        let query = searchText.lowercased()
        return playlist.filter {
            $0.title.lowercased().contains(query) ||
            $0.artist.lowercased().contains(query) ||
            $0.album.lowercased().contains(query)
        }
    }
    
    // MARK: - Init
    
    init() {
        // Restore saved folder
        if let savedPath = UserDefaults.standard.string(forKey: "musicFolderPath") {
            let url = URL(fileURLWithPath: savedPath)
            if FileManager.default.fileExists(atPath: savedPath) {
                setMusicFolder(url)
            }
        }
        
        // Playback finished handler
        audioEngine.onPlaybackFinished = { [weak self] in
            Task { @MainActor in
                self?.handlePlaybackFinished()
            }
        }
    }
    
    // MARK: - Playback Controls
    
    func play(track: Track) {
        guard let idx = playlist.firstIndex(where: { $0.id == track.id }) else { return }
        currentIndex = idx
        do {
            try audioEngine.load(url: track.url)
            audioEngine.play()
            playbackState = .playing
            startTimeUpdate()
            shuffleHistory.append(idx)
        } catch {
            print("Failed to play \(track.title): \(error)")
            playbackState = .idle
        }
    }
    
    func playAtIndex(_ index: Int) {
        guard playlist.indices.contains(index) else { return }
        play(track: playlist[index])
    }
    
    func togglePlayPause() {
        switch playbackState {
        case .playing:
            audioEngine.pause()
            playbackState = .paused
            stopTimeUpdate()
        case .paused:
            audioEngine.play()
            playbackState = .playing
            startTimeUpdate()
        case .idle:
            if let first = playlist.first {
                play(track: first)
            }
        }
    }
    
    func next() {
        guard !playlist.isEmpty else { return }
        
        switch repeatMode {
        case .one:
            if let idx = currentIndex {
                playAtIndex(idx)
            }
        case .all:
            let nextIdx = shuffleEnabled ? randomIndex() : ((currentIndex ?? -1) + 1) % playlist.count
            playAtIndex(nextIdx)
        case .off:
            let nextIdx = shuffleEnabled ? randomIndex() : ((currentIndex ?? -1) + 1)
            if nextIdx < playlist.count {
                playAtIndex(nextIdx)
            } else {
                audioEngine.stop()
                playbackState = .idle
                stopTimeUpdate()
                currentTime = 0
            }
        }
    }
    
    func previous() {
        guard !playlist.isEmpty else { return }
        
        // If more than 3 seconds in, restart current track
        if currentTime > 3 {
            audioEngine.currentTime = 0
            currentTime = 0
            return
        }
        
        let prevIdx: Int
        if shuffleEnabled {
            if shuffleHistory.last == currentIndex {
                shuffleHistory.removeLast()
            }
            if let previousIdx = shuffleHistory.popLast(), playlist.indices.contains(previousIdx) {
                prevIdx = previousIdx
            } else {
                prevIdx = randomIndex()
            }
        } else {
            prevIdx = ((currentIndex ?? 1) - 1 + playlist.count) % playlist.count
        }
        playAtIndex(prevIdx)
    }
    
    func seek(to time: TimeInterval) {
        audioEngine.currentTime = time
        currentTime = time
    }
    
    func selectFolder() {
        let panel = NSOpenPanel()
        panel.title = "选择音乐文件夹"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            setMusicFolder(url)
        }
    }
    
    // MARK: - Playlist Management
    
    func removeTrack(_ track: Track) {
        guard let idx = playlist.firstIndex(where: { $0.id == track.id }) else { return }
        
        if currentIndex == idx {
            audioEngine.stop()
            playbackState = .idle
            stopTimeUpdate()
            currentTime = 0
            playlist.remove(at: idx)
            currentIndex = nil
        } else {
            playlist.remove(at: idx)
            if let ci = currentIndex, ci > idx {
                currentIndex = ci - 1
            }
        }
    }
    
    func sortPlaylist(by field: PlaylistSortField, ascending: Bool) {
        let playingTrackID = currentTrack?.id
        playlist.sort { lhs, rhs in
            let result: ComparisonResult
            switch field {
            case .title:
                result = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
            case .artist:
                result = lhs.artist.localizedCaseInsensitiveCompare(rhs.artist)
            case .album:
                result = lhs.album.localizedCaseInsensitiveCompare(rhs.album)
            case .duration:
                if lhs.duration == rhs.duration {
                    result = .orderedSame
                } else {
                    result = lhs.duration < rhs.duration ? .orderedAscending : .orderedDescending
                }
            }
            
            if result == .orderedSame {
                let tieBreaker = lhs.title.localizedCaseInsensitiveCompare(rhs.title)
                return ascending ? tieBreaker != .orderedDescending : tieBreaker == .orderedDescending
            }
            return ascending ? result == .orderedAscending : result == .orderedDescending
        }
        updateCurrentIndex(for: playingTrackID)
    }
    
    private func updateCurrentIndex(for playingTrackID: Track.ID?) {
        guard let playingTrackID else { return }
        currentIndex = playlist.firstIndex(where: { $0.id == playingTrackID })
    }
    
    func playAllShuffle() {
        shuffleEnabled = true
        if let first = playlist.randomElement() {
            play(track: first)
        }
    }
    
    func cycleRepeatMode() {
        switch repeatMode {
        case .off: repeatMode = .all
        case .all: repeatMode = .one
        case .one: repeatMode = .off
        }
    }
    
    func cyclePlaybackMode() {
        if shuffleEnabled {
            shuffleEnabled = false
            repeatMode = .all
            return
        }
        
        switch repeatMode {
        case .off:
            shuffleEnabled = true
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
    }
    
    var playbackModeTitle: String {
        if shuffleEnabled { return "随机播放" }
        return repeatMode.rawValue
    }
    
    var playbackModeIcon: String {
        if shuffleEnabled { return "shuffle" }
        return repeatMode.icon
    }
    
    var isSpecialPlaybackModeEnabled: Bool {
        shuffleEnabled || repeatMode != .off
    }
    
    func editMetadata(for track: Track) {
        metadataEditError = nil
        editingTrack = track
    }
    
    func saveMetadata(for track: Track, title: String, artist: String, album: String) {
        let metadata = EditableTrackMetadata(
            title: normalizedMetadataValue(title) ?? track.url.deletingPathExtension().lastPathComponent,
            artist: normalizedMetadataValue(artist) ?? "未知艺术家",
            album: normalizedMetadataValue(album) ?? "未知专辑"
        )
        let wasCurrentTrack = currentTrack?.id == track.id
        let resumeTime = wasCurrentTrack ? currentTime : 0
        let shouldResumePlayback = wasCurrentTrack && playbackState == .playing
        
        if wasCurrentTrack {
            audioEngine.stop()
            playbackState = .paused
            stopTimeUpdate()
        }
        
        Task {
            do {
                try await AudioMetadataWriter.write(metadata: metadata, to: track.url)
                track.title = metadata.title
                track.artist = metadata.artist
                track.album = metadata.album
                
                if wasCurrentTrack {
                    try audioEngine.load(url: track.url)
                    let safeResumeTime = max(0, min(resumeTime, audioEngine.duration))
                    audioEngine.currentTime = safeResumeTime
                    currentTime = safeResumeTime
                    
                    if shouldResumePlayback {
                        audioEngine.play()
                        playbackState = .playing
                        startTimeUpdate()
                    } else {
                        playbackState = .paused
                    }
                }
                
                editingTrack = nil
                metadataEditError = nil
            } catch {
                metadataEditError = "保存歌曲信息失败：\(error.localizedDescription)"
                
                if wasCurrentTrack {
                    do {
                        try audioEngine.load(url: track.url)
                        let safeResumeTime = max(0, min(resumeTime, audioEngine.duration))
                        audioEngine.currentTime = safeResumeTime
                        currentTime = safeResumeTime
                        
                        if shouldResumePlayback {
                            audioEngine.play()
                            playbackState = .playing
                            startTimeUpdate()
                        } else {
                            playbackState = .paused
                        }
                    } catch {
                        playbackState = .idle
                        currentTime = 0
                    }
                }
            }
        }
    }
    
    // MARK: - Private Helpers
    
    private func handlePlaybackFinished() {
        next()
    }
    
    private func setMusicFolder(_ url: URL) {
        musicFolder = url
        UserDefaults.standard.set(url.path, forKey: "musicFolderPath")
        loadFolder(url)
        startMonitoring(url)
    }
    
    private func normalizedMetadataValue(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private func randomIndex() -> Int {
        guard playlist.count > 1 else { return currentIndex ?? 0 }
        var idx: Int
        repeat {
            idx = Int.random(in: 0..<playlist.count)
        } while idx == currentIndex
        return idx
    }
    
    private func startTimeUpdate() {
        stopTimeUpdate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.currentTime = self?.audioEngine.currentTime ?? 0
            }
        }
    }
    
    private func stopTimeUpdate() {
        timer?.invalidate()
        timer = nil
    }
    
    // MARK: - Folder Loading & Monitoring
    
    private func loadFolder(_ url: URL) {
        let urls = FolderMonitor.scanFolder(url)
        
        // Preserve existing tracks, add new ones
        let existingURLs = Set(playlist.map { $0.url })
        let newURLs = urls.filter { !existingURLs.contains($0) }
        
        let newTracks = newURLs.map { Track(url: $0) }
        
        // Load metadata off main thread
        Task.detached {
            for track in newTracks {
                await track.loadMetadata()
            }
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                // Remove tracks that no longer exist
                let currentURLs = Set(urls)
                self.playlist.removeAll { !currentURLs.contains($0.url) }
                // Add new tracks
                self.playlist.append(contentsOf: newTracks)
                self.playlist.sort {
                    $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                }
                // Update currentIndex if track is still playing
                if let track = self.currentTrack {
                    self.currentIndex = self.playlist.firstIndex(where: { $0.id == track.id })
                }
            }
        }
    }
    
    private func startMonitoring(_ url: URL) {
        folderMonitor.onFolderChanged = { [weak self] in
            Task { @MainActor in
                guard let self = self, let folder = self.musicFolder else { return }
                self.loadFolder(folder)
            }
        }
        folderMonitor.start(path: url.path)
    }
}
