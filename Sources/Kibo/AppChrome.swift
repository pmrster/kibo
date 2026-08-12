import AppKit
import Combine
import SwiftUI
import KiboCore

/// Owns the menu-bar status item and its dropdown.
///
/// `NSStatusItem` is managed directly rather than through SwiftUI's `MenuBarExtra` because
/// `MenuBarExtra` offers no right-click hook, and the About / Settings / Quit menu has to live
/// somewhere — a menu-bar-only app has no menu bar of its own to put it in.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var appearanceCancellable: AnyCancellable?

    init(model: ConverterModel) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            button.image = MenuBarIcon.image()
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Kibo")
        }

        let hosting = NSHostingController(rootView: ConverterView(model: model))
        hosting.sizingOptions = [.preferredContentSize]  // popover tracks the SwiftUI content size
        popover.contentViewController = hosting
        popover.behavior = .transient

        // NSPopover does NOT inherit `NSApp.appearance` like the panels do, so force it to match
        // the Light/Dark setting — otherwise the open popover keeps its launch colors while
        // About/Settings recolor. Re-applied on every show (below) and on every change.
        popover.appearance = AppSettings.shared.nsAppearance
        appearanceCancellable = AppSettings.shared.$appearance
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.popover.appearance = AppSettings.shared.nsAppearance }
    }

    @objc private func handleClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else if let button = statusItem.button {
            popover.appearance = AppSettings.shared.nsAppearance
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let about = NSMenuItem(title: "About Kibo",
                               action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Kibo",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        if let button = statusItem.button {
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc private func showAbout() {
        if popover.isShown { popover.performClose(nil) }
        Panels.about.show()
    }

    @objc private func showSettings() {
        if popover.isShown { popover.performClose(nil) }
        Panels.settings.show()
    }
}
