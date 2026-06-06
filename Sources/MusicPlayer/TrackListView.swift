import SwiftUI
import UniformTypeIdentifiers

struct TrackListView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var selectedTrackID: Track.ID? = nil
    @State private var draggingTrackID: Track.ID? = nil
    @State private var dragStartOrder: [Track.ID] = []
    @State private var isDropInsideList: Bool = false
    
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
            GeometryReader { geometry in
                List(selection: $selectedTrackID) {
                    ForEach(visibleRows) { row in
                        TrackRowView(
                            track: row.track,
                            index: row.index,
                            isCurrent: row.isCurrent,
                            playbackState: viewModel.playbackState,
                            canReorder: !isFiltering,
                            isDragging: draggingTrackID == row.track.id,
                            dragPreviewWidth: max(280, geometry.size.width - 32),
                            onBeginDrag: {
                                beginDragging(row.track.id)
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
                                isDropInsideList: $isDropInsideList,
                                isEnabled: !isFiltering,
                                move: { movingID, targetID in
                                    viewModel.moveTrack(movingID, before: targetID)
                                }
                            )
                        )
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .contentShape(Rectangle())
                .onDrop(
                    of: [.text],
                    delegate: PlaylistBoundsDropDelegate(
                        draggingTrackID: $draggingTrackID,
                        isDropInsideList: $isDropInsideList,
                        isEnabled: !isFiltering,
                        confirmDrop: finishDragging,
                        cancelDrop: cancelDragging
                    )
                )
                .onChange(of: draggingTrackID) { _, newValue in
                    if newValue == nil {
                        dragStartOrder = []
                        isDropInsideList = false
                    }
                }
            }
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
    
    private func beginDragging(_ trackID: Track.ID) {
        dragStartOrder = viewModel.playlist.map(\.id)
        draggingTrackID = trackID
        isDropInsideList = true
    }
    
    private func finishDragging() {
        draggingTrackID = nil
    }
    
    private func cancelDragging() {
        if !dragStartOrder.isEmpty {
            viewModel.restorePlaylistOrder(dragStartOrder)
        }
        draggingTrackID = nil
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
    let isDragging: Bool
    let dragPreviewWidth: CGFloat
    let onBeginDrag: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            DragHandleView(
                isCurrent: isCurrent,
                playbackState: playbackState,
                canReorder: canReorder,
                track: track,
                index: index,
                previewWidth: dragPreviewWidth,
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
        .opacity(isDragging ? 0.32 : 1)
        .animation(.easeOut(duration: 0.12), value: isDragging)
    }
}

private struct DragHandleView: View {
    let isCurrent: Bool
    let playbackState: PlaybackState
    let canReorder: Bool
    @ObservedObject var track: Track
    let index: Int
    let previewWidth: CGFloat
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
            return NSItemProvider(object: track.id.uuidString as NSString)
        } preview: {
            TrackDragPreview(track: track, index: index, width: previewWidth)
        }
    }
}

private struct TrackDragPreview: View {
    @ObservedObject var track: Track
    let index: Int
    let width: CGFloat
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 24)
            
            Text("\(index + 1)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 34, alignment: .leading)
            
            HStack(spacing: 8) {
                ArtworkView(artwork: track.artwork, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    Text(track.artist)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(width: width, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentColor.opacity(0.36), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 5)
        .opacity(0.86)
    }
}

private struct TrackReorderDropDelegate: DropDelegate {
    let targetTrackID: Track.ID
    @Binding var draggingTrackID: Track.ID?
    @Binding var isDropInsideList: Bool
    let isEnabled: Bool
    let move: (Track.ID, Track.ID) -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && draggingTrackID != nil
    }
    
    func dropEntered(info: DropInfo) {
        guard isEnabled,
              let draggingTrackID,
              draggingTrackID != targetTrackID else { return }
        isDropInsideList = true
        move(draggingTrackID, targetTrackID)
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        isDropInsideList = isEnabled
        return DropProposal(operation: isEnabled ? .move : .cancel)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        isDropInsideList = isEnabled
        return isEnabled
    }
}

private struct PlaylistBoundsDropDelegate: DropDelegate {
    @Binding var draggingTrackID: Track.ID?
    @Binding var isDropInsideList: Bool
    let isEnabled: Bool
    let confirmDrop: () -> Void
    let cancelDrop: () -> Void
    
    func validateDrop(info: DropInfo) -> Bool {
        isEnabled && draggingTrackID != nil
    }
    
    func dropEntered(info: DropInfo) {
        isDropInsideList = isEnabled
    }
    
    func dropExited(info: DropInfo) {
        guard draggingTrackID != nil else { return }
        isDropInsideList = false
        cancelDrop()
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        isDropInsideList = isEnabled
        return DropProposal(operation: isEnabled ? .move : .cancel)
    }
    
    func performDrop(info: DropInfo) -> Bool {
        guard isEnabled, draggingTrackID != nil, isDropInsideList else {
            cancelDrop()
            return false
        }
        confirmDrop()
        return true
    }
}
