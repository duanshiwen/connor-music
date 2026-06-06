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
            return "当前版本暂不支持直接写入 .\(ext) 文件的元信息。已支持 MP3、FLAC、M4A、MP4、AAC。"
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

private struct FLACMetadataBlock {
    let type: UInt8
    let data: Data
}

enum AudioMetadataWriter {
    static func write(metadata: EditableTrackMetadata, to url: URL) async throws {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "mp3":
            try writeMP3(metadata: metadata, to: url)
        case "flac":
            try writeFLAC(metadata: metadata, to: url)
        case "m4a", "mp4", "aac":
            try await writeMPEG4(metadata: metadata, to: url)
        default:
            throw AudioMetadataWriterError.unsupportedFormat(ext.isEmpty ? "unknown" : ext)
        }
    }
    
    // MARK: - FLAC / Vorbis Comment
    
    private static func writeFLAC(metadata: EditableTrackMetadata, to url: URL) throws {
        guard let data = try? Data(contentsOf: url) else {
            throw AudioMetadataWriterError.cannotReadFile(url)
        }
        guard data.count >= 4, data.prefix(4) == Data("fLaC".utf8) else {
            throw AudioMetadataWriterError.cannotReadFile(url)
        }
        
        var offset = 4
        var blocks: [FLACMetadataBlock] = []
        var foundLastBlock = false
        
        while offset + 4 <= data.count {
            let header = data[offset]
            let type = header & 0x7F
            let length = (Int(data[offset + 1]) << 16) | (Int(data[offset + 2]) << 8) | Int(data[offset + 3])
            let payloadStart = offset + 4
            let payloadEnd = payloadStart + length
            guard payloadEnd <= data.count else {
                throw AudioMetadataWriterError.cannotReadFile(url)
            }
            
            blocks.append(FLACMetadataBlock(type: type, data: Data(data[payloadStart..<payloadEnd])))
            offset = payloadEnd
            
            if (header & 0x80) != 0 {
                foundLastBlock = true
                break
            }
        }
        
        guard foundLastBlock, !blocks.isEmpty else {
            throw AudioMetadataWriterError.cannotReadFile(url)
        }
        
        let audioData = Data(data[offset..<data.count])
        var replacedVorbisComment = false
        
        blocks = blocks.map { block in
            guard block.type == 4 else { return block }
            replacedVorbisComment = true
            return FLACMetadataBlock(
                type: block.type,
                data: updatedVorbisCommentData(block.data, metadata: metadata)
            )
        }
        
        if !replacedVorbisComment {
            let insertionIndex = blocks.first?.type == 0 ? 1 : 0
            blocks.insert(
                FLACMetadataBlock(type: 4, data: newVorbisCommentData(metadata: metadata)),
                at: insertionIndex
            )
        }
        
        var output = Data("fLaC".utf8)
        for index in blocks.indices {
            let block = blocks[index]
            let isLast = index == blocks.indices.last
            output.append((isLast ? 0x80 : 0x00) | block.type)
            output.append(flacBlockLengthBytes(block.data.count))
            output.append(block.data)
        }
        output.append(audioData)
        
        try output.write(to: url, options: [.atomic])
    }
    
    private static func updatedVorbisCommentData(_ data: Data, metadata: EditableTrackMetadata) -> Data {
        let parsed = parseVorbisComment(data)
        let vendor = parsed?.vendor ?? "康纳音乐"
        var comments = parsed?.comments ?? []
        
        upsertVorbisComment("TITLE", metadata.title, in: &comments)
        upsertVorbisComment("ARTIST", metadata.artist, in: &comments)
        upsertVorbisComment("ALBUM", metadata.album, in: &comments)
        
        return buildVorbisCommentData(vendor: vendor, comments: comments)
    }
    
    private static func newVorbisCommentData(metadata: EditableTrackMetadata) -> Data {
        buildVorbisCommentData(
            vendor: "康纳音乐",
            comments: [
                "TITLE=\(metadata.title)",
                "ARTIST=\(metadata.artist)",
                "ALBUM=\(metadata.album)"
            ]
        )
    }
    
    private static func parseVorbisComment(_ data: Data) -> (vendor: String, comments: [String])? {
        var offset = 0
        guard let vendorLength = readLittleEndianUInt32(data, offset: &offset),
              offset + vendorLength <= data.count else { return nil }
        let vendorData = Data(data[offset..<(offset + vendorLength)])
        offset += vendorLength
        guard let vendor = String(data: vendorData, encoding: .utf8),
              let commentCount = readLittleEndianUInt32(data, offset: &offset) else { return nil }
        
        var comments: [String] = []
        for _ in 0..<commentCount {
            guard let length = readLittleEndianUInt32(data, offset: &offset),
                  offset + length <= data.count else { return nil }
            let commentData = Data(data[offset..<(offset + length)])
            offset += length
            if let comment = String(data: commentData, encoding: .utf8) {
                comments.append(comment)
            }
        }
        
        return (vendor, comments)
    }
    
    private static func buildVorbisCommentData(vendor: String, comments: [String]) -> Data {
        var output = Data()
        let vendorData = vendor.data(using: .utf8) ?? Data()
        output.appendLittleEndianUInt32(vendorData.count)
        output.append(vendorData)
        output.appendLittleEndianUInt32(comments.count)
        
        for comment in comments {
            let commentData = comment.data(using: .utf8) ?? Data()
            output.appendLittleEndianUInt32(commentData.count)
            output.append(commentData)
        }
        
        return output
    }
    
    private static func upsertVorbisComment(_ key: String, _ value: String, in comments: inout [String]) {
        let prefix = "\(key)="
        comments.removeAll { $0.range(of: prefix, options: [.caseInsensitive, .anchored]) != nil }
        comments.append("\(key)=\(value)")
    }
    
    private static func readLittleEndianUInt32(_ data: Data, offset: inout Int) -> Int? {
        guard offset + 4 <= data.count else { return nil }
        let value = Int(data[offset])
            | (Int(data[offset + 1]) << 8)
            | (Int(data[offset + 2]) << 16)
            | (Int(data[offset + 3]) << 24)
        offset += 4
        return value
    }
    
    private static func flacBlockLengthBytes(_ length: Int) -> Data {
        Data([
            UInt8((length >> 16) & 0xFF),
            UInt8((length >> 8) & 0xFF),
            UInt8(length & 0xFF)
        ])
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
}

private extension UInt32 {
    var bigEndianData: Data {
        var value = self.bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}

private extension Data {
    mutating func appendLittleEndianUInt32(_ value: Int) {
        append(UInt8(value & 0xFF))
        append(UInt8((value >> 8) & 0xFF))
        append(UInt8((value >> 16) & 0xFF))
        append(UInt8((value >> 24) & 0xFF))
    }
}
