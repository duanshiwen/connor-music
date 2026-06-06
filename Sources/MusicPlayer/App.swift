import SwiftUI
import AppKit

@main
struct MusicPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = PlayerViewModel()
    
    var body: some Scene {
        WindowGroup("康纳音乐") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 700, minHeight: 500)
                .onAppear {
                    setupAppearance()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 900, height: 650)
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
    
    private func setupAppearance() {
        // Window appearance setup
        if let window = NSApplication.shared.windows.first {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.styleMask.insert(.fullSizeContentView)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private lazy var runtimeIcon: NSImage = makeRuntimeApplicationIcon()
    
    func applicationWillFinishLaunching(_ notification: Notification) {
        applyApplicationIcon()
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftPM runs the app as a bare executable, so macOS can fail to index
        // automatic window tabs because there is no app bundle identifier.
        // The Xcode app target has a bundle identifier, but disabling automatic
        // tabbing also keeps launches consistent across both run paths.
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // Be explicit when launched from Xcode's debugger so the app becomes a
        // regular foreground app and the main SwiftUI window is activated.
        NSApplication.shared.setActivationPolicy(.regular)
        applyApplicationIcon()
        NSApplication.shared.activate(ignoringOtherApps: true)
        scheduleIconRefreshes()
    }
    
    func applicationWillBecomeActive(_ notification: Notification) {
        applyApplicationIcon()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        applyApplicationIcon()
        scheduleIconRefreshes()
    }
    
    private func scheduleIconRefreshes() {
        for delay in [0.1, 0.3, 0.8, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.applyApplicationIcon()
            }
        }
    }
    
    private func applyApplicationIcon() {
        runtimeIcon.isTemplate = false
        runtimeIcon.size = NSSize(width: 512, height: 512)
        NSApplication.shared.applicationIconImage = runtimeIcon
        NSApplication.shared.windows.forEach { window in
            window.miniwindowImage = runtimeIcon
        }
    }
    
    private func makeRuntimeApplicationIcon() -> NSImage {
        let size = NSSize(width: 512, height: 512)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }
        
        let rect = NSRect(origin: .zero, size: size)
        NSColor.clear.setFill()
        rect.fill()
        
        // Solid modern blue-violet rounded-square background.
        let backgroundRect = NSRect(x: 48, y: 48, width: 416, height: 416)
        let background = NSBezierPath(roundedRect: backgroundRect, xRadius: 92, yRadius: 92)
        NSColor(red: 58 / 255, green: 89 / 255, blue: 255 / 255, alpha: 1).setFill()
        background.fill()
        
        // Subtle symbol shadow.
        drawRuntimeMusicNote(offset: NSPoint(x: 8, y: -8), color: NSColor.black.withAlphaComponent(0.20))
        
        // Large rounded white music note. Programmatic drawing guarantees the
        // Dock icon is visible even if Xcode/LaunchServices ignores bundle icons.
        drawRuntimeMusicNote(offset: .zero, color: .white)
        
        image.isTemplate = false
        return image
    }
    
    private func drawRuntimeMusicNote(offset: NSPoint, color: NSColor) {
        color.setFill()
        color.setStroke()
        
        let ox = offset.x
        let oy = offset.y
        
        // Rounded note head.
        let noteHead = NSBezierPath(ovalIn: NSRect(x: 154 + ox, y: 126 + oy, width: 136, height: 104))
        noteHead.fill()
        
        // Small inner cut keeps the note refined while staying very legible.
        NSColor(red: 58 / 255, green: 89 / 255, blue: 255 / 255, alpha: color.alphaComponent).setFill()
        let innerCut = NSBezierPath(ovalIn: NSRect(x: 190 + ox, y: 152 + oy, width: 62, height: 48))
        innerCut.fill()
        
        color.setFill()
        color.setStroke()
        
        // Thick rounded stem.
        let stem = NSBezierPath(roundedRect: NSRect(x: 270 + ox, y: 174 + oy, width: 44, height: 210), xRadius: 22, yRadius: 22)
        stem.fill()
        
        // Rounded slanted beam.
        let beam = NSBezierPath(roundedRect: NSRect(x: 268 + ox, y: 360 + oy, width: 144, height: 44), xRadius: 22, yRadius: 22)
        var transform = AffineTransform()
        transform.translate(x: 340 + ox, y: 382 + oy)
        transform.rotate(byDegrees: -16)
        transform.translate(x: -(340 + ox), y: -(382 + oy))
        beam.transform(using: transform)
        beam.fill()
        
        // Round end cap for a softer, more premium silhouette.
        let cap = NSBezierPath(ovalIn: NSRect(x: 382 + ox, y: 338 + oy, width: 54, height: 54))
        cap.fill()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
