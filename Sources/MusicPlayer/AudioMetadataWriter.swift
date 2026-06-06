import Foundation
import AVFoundation

struct EditableTrackMetadata {
    let title: String
    let artist: String
    let album: String
}

enum AudioMetadataWriterError: LocalizedError {
    case unsupportedFormat(String)
    case cannotReadFile(URL)
    case exportSessionUnavailable
    case exportFailed(String)
    case fileReplacementFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return "当前版本暂不支持直接写入 .\(ext) 文件的元信息。已支持 MP3、M4A、MP4、AAC。"
        case .cannotReadFile(let url):
            return "无法读取文件：\(url.lastPathComponent)"
        case .exportSessionUnavailable:
            return "无法创建音频导出会话。"
        case .exportFailed(let message):
            return "导出音频文件失败：\(message)"
        case .fileReplacementFailed(let message):
            return "替换原文件失败：\(message)"
        }
    }
}

enum AudioMetadataWriter {
    static func write(metadata: EditableTrackMetadata, to url: URL) async throws {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp3":
            try writeMP3(metadata: metadata, to: url)
        case "m4a", "mp4", "aac":
            try await writeMPEG4(metadata: metadata, to: url)
        default:
            throw AudioMetadataWriterError.unsupportedFormat(ext.isEmpty ? "unknown" : ext)
        }
    }
    
    // MARK: - MP3 / ID3v2.3
    
    private static func writeMP3(metadata: EditableTrackMetadata, to url: URL) throws {
        guard let data = try? Data(contentsOf: url) else {
            throw AudioMetadataWriterError.cannotReadFile(url)
        }
        
        let audioData = stripLeadingID3Tag(from: data)
        var tagBody = Data()
        tagBody.append(id3TextFrame(id: "TIT2", text: metadata.title))
        tagBody.append(id3TextFrame(id: "TPE1", text: metadata.artist))
        tagBody.append(id3TextFrame(id: "TALB", text: metadata.album))
        
        var output = Data()
        output.append(contentsOf: [0x49, 0x44, 0x33]) // ID3
        output.append(contentsOf: [0x03, 0x00])       // v2.3.0
        output.append(0x00)                           // flags
        output.append(syncSafeBytes(tagBody.count))
        output.append(tagBody)
        output.append(audioData)
        
        try backupOriginal(at: url)
        try output.write(to: url, options: [.atomic])
    }
    
    private static func stripLeadingID3Tag(from data: Data) -> Data {
        guard data.count >= 10,
              data[0] == 0x49, data[1] == 0x44, data[2] == 0x33
        else { return data }
        
        let size = syncSafeInt(data[6], data[7], data[8], data[9])
        let totalSize = 10 + size
        guard totalSize <= data.count else { return data }
        return data.subdata(in: totalSize..<data.count)
    }
    
    private static func id3TextFrame(id: String, text: String) -> Data {
        var payload = Data([0x03]) // UTF-8 encoding marker
        payload.append(text.data(using: .utf8) ?? Data())
        
        var frame = Data(id.utf8)
        frame.append(UInt32(payload.count).bigEndianData)
        frame.append(contentsOf: [0x00, 0x00]) // flags
        frame.append(payload)
        return frame
    }
    
    private static func syncSafeBytes(_ value: Int) -> Data {
        Data([
            UInt8((value >> 21) & 0x7F),
            UInt8((value >> 14) & 0x7F),
            UInt8((value >> 7) & 0x7F),
            UInt8(value & 0x7F)
        ])
    }
    
    private static func syncSafeInt(_ b1: UInt8, _ b2: UInt8, _ b3: UInt8, _ b4: UInt8) -> Int {
        (Int(b1) << 21) | (Int(b2) << 14) | (Int(b3) << 7) | Int(b4)
    }
    
    // MARK: - MPEG-4 / M4A / AAC
    
    private static func writeMPEG4(metadata: EditableTrackMetadata, to url: URL) async throws {
        let asset = AVURLAsset(url: url)
        guard let export = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw AudioMetadataWriterError.exportSessionUnavailable
        }
        
        let tempURL = url.deletingLastPathComponent()
            .appendingPathComponent(".\(url.deletingPathExtension().lastPathComponent)-metadata-\(UUID().uuidString)")
            .appendingPathExtension(url.pathExtension)
        
        export.outputURL = tempURL
        export.outputFileType = outputFileType(for: url.pathExtension.lowercased())
        export.metadata = [
            metadataItem(identifier: .commonIdentifierTitle, value: metadata.title),
            metadataItem(identifier: .commonIdentifierArtist, value: metadata.artist),
            metadataItem(identifier: .commonIdentifierAlbumName, value: metadata.album)
        ]
        
        await export.export()
        
        guard export.status == .completed else {
            let message = export.error?.localizedDescription ?? "未知错误"
            try? FileManager.default.removeItem(at: tempURL)
            throw AudioMetadataWriterError.exportFailed(message)
        }
        
        do {
            try backupOriginal(at: url)
            _ = try FileManager.default.replaceItemAt(url, withItemAt: tempURL, backupItemName: nil, options: [])
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            throw AudioMetadataWriterError.fileReplacementFailed(error.localizedDescription)
        }
    }
    
    private static func metadataItem(identifier: AVMetadataIdentifier, value: String) -> AVMutableMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        item.extendedLanguageTag = "und"
        return item
    }
    
    private static func outputFileType(for ext: String) -> AVFileType {
        switch ext {
        case "mp4": return .mp4
        default: return .m4a
        }
    }
    
    // MARK: - Backup
    
    private static func backupOriginal(at url: URL) throws {
        let backupURL = url.appendingPathExtension("bak")
        let fm = FileManager.default
        if fm.fileExists(atPath: backupURL.path) {
            try fm.removeItem(at: backupURL)
        }
        try fm.copyItem(at: url, to: backupURL)
    }
}

private extension UInt32 {
    var bigEndianData: Data {
        var value = self.bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}
