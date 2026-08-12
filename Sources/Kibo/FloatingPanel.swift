import AppKit
import SwiftUI

/// A small floating window hosting a SwiftUI view.
///
/// Every auxiliary window in this app is one of these. AppKit rather than a SwiftUI `Window`
/// scene, because a window scene does not reliably open from a menu-bar-only (`LSUIElement`)
/// app — the standard About panel simply did nothing when asked to show.
@MainActor
final class FloatingPanel {
    private let title: String
    private let size: NSSize
    private let minSize: NSSize?
    private let content: () -> AnyView
    private var panel: NSPanel?

    /// - Parameter minSize: also decides whether the panel is resizable. `nil` gives a fixed
    ///   window, which is what the small About and Settings panels want.
    init(title: String,
         size: NSSize,
         minSize: NSSize? = nil,
         @ViewBuilder content: @escaping () -> some View) {
        self.title = title
        self.size = size
        self.minSize = minSize
        self.content = { AnyView(content()) }
    }

    func show() {
        let firstTime = panel == nil
        let p = panel ?? makePanel()
        panel = p
        // Re-host on every show so the view starts from a clean state.
        p.contentViewController = NSHostingController(rootView: content())
        if firstTime || minSize == nil {
            p.setContentSize(size)
            p.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        p.makeKeyAndOrderFront(nil)
    }

    func toggle() {
        if let panel, panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        var style: NSWindow.StyleMask = [.titled, .closable, .utilityWindow, .nonactivatingPanel]
        if minSize != nil { style.insert(.resizable) }

        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size),
                        styleMask: style,
                        backing: .buffered,
                        defer: false)
        p.title = title
        p.isFloatingPanel = true
        p.level = .floating
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        if let minSize {
            p.contentMinSize = minSize
            p.acceptsMouseMovedEvents = true  // so SwiftUI `.help` tooltips track inside the panel
        }
        return p
    }
}

/// The app's auxiliary windows.
///
/// `pinned` is optional because it hosts the converter and so cannot exist until the
/// `ConverterModel` does — `AppDelegate` installs it at launch. The other two depend on nothing
/// and are created on first use.
@MainActor
enum Panels {
    static var pinned: FloatingPanel?

    static let settings = FloatingPanel(title: "Settings",
                                        size: NSSize(width: 320, height: 320)) { SettingsView() }

    static let about = FloatingPanel(title: "About",
                                     size: NSSize(width: 320, height: 360)) { AboutView() }
}
