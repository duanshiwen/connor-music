import SwiftUI
import AppKit

struct ArtworkView: View {
    let artwork: NSImage?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let image = artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: size > 48 ? 8 : 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.accentColor.opacity(0.15),
                                    Color.accentColor.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.35))
                        .foregroundColor(.accentColor.opacity(0.4))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size > 48 ? 8 : 4))
    }
}
