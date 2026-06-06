import SwiftUI
import UniformTypeIdentifiers

struct TrackListView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var selectedTrackID: Track.ID? = nil
    @State private var draggingTrackID: Track.ID? = nil
    
    private var isFiltering: Bool {
        !viewModel.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var visibleRows: [TrackRowData] {
        let currentTrackID = viewModel.currentTrack?.id
        return viewModel.filteredPlaylist.enumerated().map { index, track in
            TrackRowData(
                track: track,
                index: index,
                isCurrent: track.id == currentTrackID
            )
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            header
            List(selection: $selectedTrackID) {
                ForEach(visibleRows) { row in
                    TrackRowView(
                        track: row.track,
                        index: row.index,
                        isCurrent: row.isCurrent,
                        playbackState: viewModel.playbackState,
                        canReorder: !isFiltering,
                        onBeginDrag: {
                            draggingTrackID = row.track.id
                        }
                    )
                    .tag(row.track.id)
                    .contentShape(Rectangle())
                    .contextMenu {
                        contextMenu(for: row.track)
                    }
                    .onTapGesture(count: 2) {
                        viewModel.play(track: row.track)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: TrackReorderDropDelegate(
                            targetTrackID: row.track.id,
                            draggingTrackID: $draggingTrackID,
                            isEnabled: !isFiltering,
                            move: { movingID, targetID in
                                viewModel.moveTrack(movingID, before: targetID)
                            }
                        )
                    )
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
}

private struct TrackRowData: Identifiable {
    let track: Track
    let index: Int
    let isCurrent: Bool
    
    var id: Track.ID { track.id }
}

private struct TrackRowView: View {
    @ObservedObject var track: Track
    let index: Int
    let isCurrent: Bool
    let playbackState: PlaybackState
    let canReorder: Bool
    let onBeginDrag: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            DragHandleView(
                isCurrent: isCurrent,
                playbackState: playbackState,
                canReorder: canReorder,
                trackID: track.id,
                onBeginDrag: onBeginDrag
            )
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

private struct DragHandleView: View {
    let isCurrent: Bool
    let playbackState: PlaybackState
    let canReorder: Bool
    let trackID: Track.ID
    let onBeginDrag: () -> Void
    
    var body: some View {
        Group {
            if isCurrent {
                Image(systemName: playbackState == .playing ? "speaker.wave.2.fill" : "pause.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.accentColor)
            } else {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(canReorder ? .secondary.opacity(0.55) : .secondary.opacity(0.2))
            }
        }
        .frame(width: 22, height: 22)
        .contentShape(Rectangle())
        .help(canReorder ? "拖动此区域调整排序" : "搜索时暂不支持拖动排序")
        .onDrag {
            guard canReorder else { return NSItemProvider() }
            onBeginDrag()
            return NSItemProvider(object: trackID.uuidString as NSString)
        }
    }
}

private struct TrackReorderDropDelegate: DropDelegate {
    let targetTrackID: Track.ID
    @Binding var draggingTrackID: Track.ID?
    let isEnabled: Bool
    let move: (Track.ID, Track.ID) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && draggingTrackID != nil
    }
    
    func dropEntered(info: DropInfo) {
        guard isEnabled,
              let draggingTrackID,
              draggingTrackID != targetTrackID else { return }
        move(draggingTrackID, targetTrackID)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        draggingTrackID = nil
        return isEnabled
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: isEnabled ? .move : .cancel)
    }
}
