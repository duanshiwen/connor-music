import SwiftUI

enum PlaylistSortField: Equatable {
    case title
    case artist
    case album
    case duration
}

struct TrackListView: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var selectedTrackID: Track.ID? = nil
    @State private var sortField: PlaylistSortField = .title
    @State private var sortAscending: Bool = true
    
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
                        playbackState: viewModel.playbackState
                    )
                    .tag(row.track.id)
                    .contentShape(Rectangle())
                    .contextMenu {
                        contextMenu(for: row.track)
                    }
                    .onTapGesture(count: 2) {
                        viewModel.play(track: row.track)
                    }
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
            SortHeaderButton(
                title: "标题",
                field: .title,
                activeField: sortField,
                ascending: sortAscending,
                action: sort
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            SortHeaderButton(
                title: "艺术家",
                field: .artist,
                activeField: sortField,
                ascending: sortAscending,
                action: sort
            )
            .frame(width: 150, alignment: .leading)
            SortHeaderButton(
                title: "专辑",
                field: .album,
                activeField: sortField,
                ascending: sortAscending,
                action: sort
            )
            .frame(width: 150, alignment: .leading)
            SortHeaderButton(
                title: "时长",
                field: .duration,
                activeField: sortField,
                ascending: sortAscending,
                action: sort
            )
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
    
    private func sort(_ field: PlaylistSortField) {
        if sortField == field {
            sortAscending.toggle()
        } else {
            sortField = field
            sortAscending = true
        }
        viewModel.sortPlaylist(by: field, ascending: sortAscending)
    }
}

private struct SortHeaderButton: View {
    let title: String
    let field: PlaylistSortField
    let activeField: PlaylistSortField
    let ascending: Bool
    let action: (PlaylistSortField) -> Void
    
    private var isActive: Bool { field == activeField }
    
    var body: some View {
        Button {
            action(field)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                if isActive {
                    Image(systemName: ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
            }
            .foregroundColor(isActive ? .primary : .secondary)
            .frame(maxWidth: .infinity, alignment: field == .duration ? .trailing : .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help("按\(title)排序")
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
    
    var body: some View {
        HStack(spacing: 8) {
            currentTrackIndicator
                .frame(width: 24)
            
            Text("\(index + 1)")
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 34, alignment: .leading)
            
            HStack(spacing: 8) {
                ArtworkView(artwork: track.artwork, size: 34)
                Text(track.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .foregroundColor(isCurrent ? .accentColor : .primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Text(track.artist)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)
            
            Text(track.album)
                .font(.system(size: 12))
                .lineLimit(1)
                .foregroundColor(.secondary)
                .frame(width: 150, alignment: .leading)
            
            Text(track.formattedDuration)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var currentTrackIndicator: some View {
        if isCurrent {
            Image(systemName: playbackState == .playing ? "speaker.wave.2.fill" : "pause.fill")
                .font(.system(size: 11))
                .foregroundColor(.accentColor)
        } else {
            Color.clear
        }
    }
}
