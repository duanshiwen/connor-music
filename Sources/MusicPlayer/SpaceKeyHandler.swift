import SwiftUI
import AppKit

struct SpaceKeyHandler: NSViewRepresentable {
    let action: () -> Void

    func makeNSView(context: Context) -> SpaceKeyHandlingView {
        let view = SpaceKeyHandlingView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: SpaceKeyHandlingView, context: Context) {
        nsView.action = action
    }
}

final class SpaceKeyHandlingView: NSView {
    var action: (() -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateMonitor()
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    private func updateMonitor() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }

        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self,
                  let window = self.window,
                  event.window == window,
                  window.isKeyWindow,
                  event.keyCode == 49,
                  event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty,
                  !self.isTextInputActive(in: window) else {
                return event
            }

            self.action?()
            return nil
        }
    }

    private func isTextInputActive(in window: NSWindow) -> Bool {
        guard let firstResponder = window.firstResponder else { return false }

        if firstResponder is NSTextView || firstResponder is NSTextField {
            return true
        }

        let responderDescription = String(describing: type(of: firstResponder))
        return responderDescription.contains("FieldEditor")
    }
}
