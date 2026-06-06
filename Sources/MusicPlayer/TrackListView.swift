import SwiftUI

struct TrackListView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var selectedTrackID: Track.ID? = nil
    
    private var isFiltering: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var visibleTracks: [Track] {
        viewModel.filteredPlaylist
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            List(selection: $selectedTrackID) {
                ForEach(visibleTracks) { track in
                    TrackRowView(
                        track: track,
                        index: indexInVisible(track),
                        isCurrent: isCurrentTrack(track),
                        playbackState: viewModel.playbackState
                    )
                    .tag(track.id)
                    .contentShape(Rectangle())
                    .contextMenu {
                        contextMenu(for: track)
                    }
                    .onTapGesture(count: 2) {
                        viewModel.play(track: track)
                    }
                }
                .onMove { source, destination in
                    guard !isFiltering else { return }
                    viewModel.moveTrack(from: source, to: destination)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
        .onDeleteCommand {
            if let id = selectedTrackID,
               let track = viewModel.playlist.first(where: { $0.id == id }) {
                viewModel.removeTrack(track)
            }
        }
    }
    
    private var header: some View {
        HStack(spacing: 8) {
            Text(" ")
                .frame(width: 24)
            Text("#")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 34, alignment: .leading)
            Text("标题")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("专辑")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 170, alignment: .leading)
            Text("时长")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
    
    @ViewBuilder
    private func contextMenu(for track: Track) -> some View {
        Button("播放") {
            viewModel.play(track: track)
        }
        Button("编辑歌曲信息") {
            viewModel.editMetadata(for: track)
        }
        Divider()
        Button("从播放列表移除", role: .destructive) {
            viewModel.removeTrack(track)
        }
    }
    
    private func indexInVisible(_ track: Track) -> Int {
        visibleTracks.firstIndex(where: { $0.id == track.id }) ?? 0
    }
    
    private func isCurrentTrack(_ track: Track) -> Bool {
        viewModel.currentTrack?.id == track.id
    }
}

private struct TrackRowView: View {
    @ObservedObject var track: Track
    let index: Int
    let isCurrent: Bool
    let playbackState: PlaybackState
    
    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isCurrent {
                    Image(systemName: playbackState == .playing ? "speaker.wave.2.fill" : "pause.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.35))
                }
            }
            .frame(width: 24)
            
            Text("\(index + 1)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 34, alignment: .leading)
            
            HStack(spacing: 8) {
                ArtworkView(artwork: track.artwork, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .foregroundColor(isCurrent ? .accentColor : .primary)
                    Text(track.artist)
                        .font(.system(size: 11))
                        .lineLimit(1)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(track.album)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.secondary)
                .frame(width: 170, alignment: .leading)
            
            Text(track.formattedDuration)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
}
