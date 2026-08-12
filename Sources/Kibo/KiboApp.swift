import SwiftUI
import KiboCore

@main
struct KiboApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    // A menu-bar-only app (`LSUIElement`) has no real window scene. The status item and its
    // popover are owned by the AppDelegate via `StatusItemController`, so that right-click can
    // open a menu — something `MenuBarExtra` cannot do. An empty Settings scene satisfies the
    // `App` protocol's requirement for a body; the real settings window is `SettingsPanel`.
    var body: some Scene {
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.shared.applyAppearance()

        // Design-review tooling, opt-in behind the KIBO_SNAPSHOT compile flag (absent from normal
        // debug and release builds). Renders the surfaces to PNGs and exits.
        #if KIBO_SNAPSHOT
        Snapshot.renderIfRequested()
        #endif

        // `swift run` produces an executable with no bundle, which by default launches as a
        // regular app with a Dock icon. Setting the policy in code keeps development builds
        // behaving like the packaged one, where `LSUIElement` does the same job.
        NSApp.setActivationPolicy(.accessory)

        // No mode is passed: the model opens in whatever the memory remembers, and saves the mode
        // itself from then on. The shell's job is to supply the dependencies, not the rule.
        let model = ConverterModel(clipboard: SystemClipboard(), memory: SettingsStore())

        // The pinned panel shows the same converter, resizable rather than fixed-width. It can
        // only be built now, since it needs the model.
        Panels.pinned = FloatingPanel(title: "Kibo",
                                      size: NSSize(width: 380, height: 520),
                                      minSize: NSSize(width: 340, height: 420)) {
            ConverterView(model: model, fixedWidth: nil)
        }
        statusController = StatusItemController(model: model)
    }

    /// Secure coding for any state AppKit might still restore. The panels opt out of restoration
    /// individually (`FloatingPanel.makePanel`), so there should be nothing to restore at all —
    /// this closes the gap rather than relying on the deprecated insecure path staying benign.
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
