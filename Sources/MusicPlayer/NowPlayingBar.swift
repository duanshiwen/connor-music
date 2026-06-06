import SwiftUI

struct NowPlayingBar: View {
    @ObservedObject var viewModel: PlayerViewModel
    @State private var isDragging: Bool = false
    @State private var dragTime: TimeInterval = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))
                        .frame(height: 3)
                    
                    Rectangle()
                        .fill(Color.accentColor.opacity(0.8))
                        .frame(width: progressWidth(total: geo.size.width), height: 3)
                }
                .frame(height: 3)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let pct = max(0, min(1, value.location.x / geo.size.width))
                            dragTime = pct * totalDuration
                        }
                        .onEnded { value in
                            let pct = max(0, min(1, value.location.x / geo.size.width))
                            let time = pct * totalDuration
                            viewModel.seek(to: time)
                            isDragging = false
                        }
                )
            }
            .frame(height: 3)
            
            // Controls
            HStack(spacing: 16) {
                // Track info
                HStack(spacing: 10) {
                    if let track = viewModel.currentTrack {
                        ArtworkView(artwork: track.artwork, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                            Text(track.artist)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("未在播放")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 200, alignment: .leading)
                
                Spacer()
                
                // Playback controls
                HStack(spacing: 16) {
                    Button(action: { viewModel.previous() }) {
                        Image(systemName: "backward.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(viewModel.currentTrack != nil ? .primary : .secondary.opacity(0.4))
                    .disabled(viewModel.currentTrack == nil)
                    
                    Button(action: { viewModel.togglePlayPause() }) {
                        Image(systemName: playPauseIcon)
                            .font(.system(size: 28))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(viewModel.playlist.isEmpty ? .secondary.opacity(0.4) : .primary)
                    .disabled(viewModel.playlist.isEmpty)
                    
                    Button(action: { viewModel.next() }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(viewModel.currentTrack != nil ? .primary : .secondary.opacity(0.4))
                    .disabled(viewModel.currentTrack == nil)
                }
                
                Spacer()
                
                // Time + controls
                HStack(spacing: 12) {
                    // Time display
                    Text("\(formatTime(displayTime)) / \(formatTime(totalDuration))")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    // Shuffle
                    Button(action: { viewModel.shuffleEnabled.toggle() }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 14))
                            .foregroundColor(viewModel.shuffleEnabled ? .accentColor : .secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    
                    // Repeat
                    Button(action: { viewModel.cycleRepeatMode() }) {
                        Image(systemName: viewModel.repeatMode.icon)
                            .font(.system(size: 14))
                            .foregroundColor(viewModel.repeatMode == .off ? .secondary.opacity(0.6) : .accentColor)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 200, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var playPauseIcon: String {
        switch viewModel.playbackState {
        case .playing: return "pause.circle.fill"
        case .paused, .idle: return "play.circle.fill"
        }
    }
    
    private var totalDuration: TimeInterval {
        viewModel.currentTrack?.duration ?? 0
    }
    
    private var displayTime: TimeInterval {
        isDragging ? dragTime : viewModel.currentTime
    }
    
    private func progressWidth(total: CGFloat) -> CGFloat {
        guard totalDuration > 0 else { return 0 }
        return (displayTime / totalDuration) * total
    }
    
    private func formatTime(_ t: TimeInterval) -> String {
        guard t.isFinite && t >= 0 else { return "0:00" }
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%d:%02d", m, s)
    }
}
