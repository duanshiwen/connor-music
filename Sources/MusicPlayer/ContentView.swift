import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            ToolbarView(viewModel: viewModel)
            
            Divider()
            
            // Playlist
            if viewModel.playlist.isEmpty {
                EmptyStateView(viewModel: viewModel)
            } else {
                TrackListView(viewModel: viewModel)
            }
            
            Divider()
            
            // Now Playing Bar
            NowPlayingBar(viewModel: viewModel)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $viewModel.editingTrack) { track in
            EditMetadataView(viewModel: viewModel, track: track)
        }
    }
}

// MARK: - Toolbar

struct ToolbarView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        HStack(spacing: 12) {
            // Folder button
            Button(action: { viewModel.selectFolder() }) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 13))
                    if let folder = viewModel.musicFolder {
                        Text(folder.lastPathComponent)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    } else {
                        Text("选择音乐文件夹")
                            .font(.system(size: 13))
                    }
                }
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(nsColor: .separatorColor).opacity(0.3))
            .cornerRadius(6)
            
            Spacer()
            
            // Track count
            Text("\(viewModel.playlist.count) 首")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            
            // Search
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("搜索", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .frame(width: 160)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    @ObservedObject var viewModel: PlayerViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))
            
            Text("没有音乐")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.secondary)
            
            Text("选择一个包含音乐文件的文件夹开始播放")
                .font(.system(size: 13))
                .foregroundColor(.secondary.opacity(0.7))
            
            Button(action: { viewModel.selectFolder() }) {
                Label("选择文件夹", systemImage: "folder.badge.plus")
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
