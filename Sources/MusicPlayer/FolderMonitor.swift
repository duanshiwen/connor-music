import Foundation

final class FolderMonitor {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    var onFolderChanged: (() -> Void)?
    
    func start(path: String) {
        stop()
        
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .revoke],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        source?.setEventHandler { [weak self] in
            self?.onFolderChanged?()
        }
        
        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
                self?.fileDescriptor = -1
            }
        }
        
        source?.resume()
    }
    
    func stop() {
        source?.cancel()
        source = nil
    }
    
    deinit {
        stop()
    }
    
    // Scan directory recursively for audio files
    static func scanFolder(_ url: URL) -> [URL] {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        
        var files: [URL] = []
        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  AudioFormats.isSupported(fileURL)
            else { continue }
            files.append(fileURL)
        }
        
        return files.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }
    }
}
