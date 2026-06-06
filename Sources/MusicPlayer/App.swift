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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.applyApplicationIcon()
        }
    }
    
    private func applyApplicationIcon() {
        guard let icon = loadApplicationIcon() else { return }
        icon.size = NSSize(width: 512, height: 512)
        NSApplication.shared.applicationIconImage = icon
    }
    
    private func loadApplicationIcon() -> NSImage? {
        // 1. Runtime imageset lookup. A regular imageset is more reliable for
        // NSImage(named:) than the special AppIcon.appiconset.
        if let icon = NSImage(named: "AppRuntimeIcon") {
            return icon
        }
        
        // 2. Standard app-bundle resource path used by the Xcode .app target.
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            return icon
        }
        
        // 3. Asset catalog app-icon lookup. This may work for the bundled app target.
        if let icon = NSImage(named: "AppIcon") {
            return icon
        }
        
        // 4. SwiftPM/Xcode package debug fallback: when launched as a bare
        // executable, Bundle.main has no app resources, so search upward from
        // the working directory for the checked-in Resources/AppIcon.icns.
        var directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        for _ in 0..<8 {
            let candidate = directory.appendingPathComponent("Resources/AppIcon.icns")
            if let icon = NSImage(contentsOf: candidate) {
                return icon
            }
            directory.deleteLastPathComponent()
        }
        
        return nil
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
