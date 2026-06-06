import SwiftUI
import AppKit

@main
struct MusicPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = PlayerViewModel()
    
    var body: some Scene {
        WindowGroup {
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
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftPM runs the app as a bare executable, so macOS can fail to index
        // automatic window tabs because there is no app bundle identifier.
        // The Xcode app target has a bundle identifier, but disabling automatic
        // tabbing also keeps launches consistent across both run paths.
        NSWindow.allowsAutomaticWindowTabbing = false
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
