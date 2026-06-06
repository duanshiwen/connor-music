import Foundation

struct TrackMetadataOverride: Codable, Equatable {
    var title: String?
    var artist: String?
    var album: String?
    
    var isEmpty: Bool {
        title == nil && artist == nil && album == nil
    }
}

final class MetadataStore {
    private let fileURL: URL
    private var overrides: [String: TrackMetadataOverride] = [:]
    
    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = appSupport.appendingPathComponent("MusicPlayer", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("metadata-overrides.json")
        load()
    }
    
    func override(for url: URL) -> TrackMetadataOverride? {
        overrides[key(for: url)]
    }
    
    func setOverride(_ override: TrackMetadataOverride, for url: URL) throws {
        let key = key(for: url)
        if override.isEmpty {
            overrides.removeValue(forKey: key)
        } else {
            overrides[key] = override
        }
        try save()
    }
    
    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        overrides = (try? JSONDecoder().decode([String: TrackMetadataOverride].self, from: data)) ?? [:]
    }
    
    private func save() throws {
        let data = try JSONEncoder().encode(overrides)
        try data.write(to: fileURL, options: [.atomic])
    }
    
    private func key(for url: URL) -> String {
        url.standardizedFileURL.path
    }
}
