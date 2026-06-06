import SwiftUI

struct EditMetadataView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @ObservedObject var track: Track
    
    @State private var title: String
    @State private var artist: String
    @State private var album: String
    
    init(viewModel: PlayerViewModel, track: Track) {
        self.viewModel = viewModel
        self.track = track
        _title = State(initialValue: track.title)
        _artist = State(initialValue: track.artist)
        _album = State(initialValue: track.album)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                ArtworkView(artwork: track.artwork, size: 56)
                VStack(alignment: .leading, spacing: 4) {
                    Text("编辑歌曲信息")
                        .font(.system(size: 18, weight: .semibold))
                    Text(track.url.lastPathComponent)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                field("标题", text: $title)
                field("艺术家", text: $artist)
                field("专辑", text: $album)
            }
            
            if let error = viewModel.metadataEditError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }
            
            HStack {
                Text("修改会保存到本播放器，不会改写原始音频文件。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                Button("取消") {
                    viewModel.editingTrack = nil
                }
                Button("保存") {
                    viewModel.saveMetadata(for: track, title: title, artist: artist, album: album)
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 440)
    }
    
    private func field(_ label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            TextField(label, text: text)
                .textFieldStyle(.roundedBorder)
        }
    }
}
