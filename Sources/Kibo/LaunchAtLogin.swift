import ServiceManagement

/// The "open at login" switch, backed by `SMAppService` — the modern login-item API, which
/// registers the app itself rather than a helper and shows up in System Settings → General →
/// Login Items under its own name.
///
/// Nothing is stored in the app's own defaults. The system is the one source of truth, and the
/// Settings toggle reads `state` back after every change, so it can never claim the app opens at
/// login when Login Items says otherwise — the two could drift if the user toggled it there.
///
/// Shell-only: it is one system call with nothing to unit-test, and Core stays free of system
/// frameworks. It also only works from a real `.app` bundle — under `swift run` there is nothing
/// for Login Items to register, `set` throws, and the toggle stays off.
enum LaunchAtLogin {
    enum State {
        case off
        case on
        /// Registered, but macOS wants the user to confirm it in System Settings first. The toggle
        /// shows where to do that rather than pretending the switch took.
        case awaitingApproval
    }

    static var state: State {
        switch SMAppService.mainApp.status {
        case .enabled: return .on
        case .requiresApproval: return .awaitingApproval
        case .notRegistered, .notFound: return .off
        @unknown default: return .off
        }
    }

    static func set(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
