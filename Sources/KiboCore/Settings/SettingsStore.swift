import Foundation

/// Forced appearance. `system` follows the OS.
public enum Appearance: String, CaseIterable, Sendable {
    case system, light, dark
}

/// Text-size preset. `factor` multiplies every hardcoded point size; `small` is 1.0 so the app is
/// pixel-identical to its designed size and the presets only grow from there.
public enum FontSize: String, CaseIterable, Sendable {
    case small, medium, large

    public var factor: Double {
        switch self {
        case .small: return 1.0
        case .medium: return 1.15
        case .large: return 1.3
        }
    }
}

/// Where the converter remembers the mode it was left in.
///
/// Narrow on purpose, in the same spirit as `Clipboard`: "reopen in the mode you left it in" is a
/// behaviour rule, so it belongs to `ConverterModel` in Core where it can be tested, not hung off
/// a picker's `onChange` in the SwiftUI shell where it was — untestable, and something a Windows
/// port would have to rediscover by reading view code. Two methods, so a test can count the saves.
@MainActor
public protocol ModeMemory {
    func loadMode() -> ConversionMode
    func saveMode(_ mode: ConversionMode)
}

/// A mode memory that lives in memory, for tests.
@MainActor
public final class InMemoryModeMemory: ModeMemory {
    public private(set) var saves = 0
    public var mode: ConversionMode

    public init(mode: ConversionMode = .mixed) {
        self.mode = mode
    }

    public func loadMode() -> ConversionMode { mode }

    public func saveMode(_ mode: ConversionMode) {
        saves += 1
        self.mode = mode
    }
}

/// The user's preferences, persisted in `UserDefaults`.
///
/// Everything here is a display preference or the last mode picked — deliberately nothing about
/// what was converted. SPEC.md promises no entered or converted text is ever stored, and the way
/// to keep that promise is to have nowhere to put it.
///
/// Pure value logic with the defaults store injected, so it is testable without touching the real
/// user domain. Unknown or missing values fall back to the defaults.
public struct SettingsStore {
    private let defaults: UserDefaults

    private enum Key {
        static let appearance = "kibo.appearance"
        static let fontSize = "kibo.fontSize"
        static let lastMode = "kibo.lastMode"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var appearance: Appearance {
        get { defaults.string(forKey: Key.appearance).flatMap(Appearance.init(rawValue:)) ?? .system }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.appearance) }
    }

    public var fontSize: FontSize {
        get { defaults.string(forKey: Key.fontSize).flatMap(FontSize.init(rawValue:)) ?? .small }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.fontSize) }
    }

    /// Reopening the converter in the mode you left it in. Mixed is the default because it is the
    /// one that needs no decision from the user.
    public var lastMode: ConversionMode {
        get { defaults.string(forKey: Key.lastMode).flatMap(ConversionMode.init(rawValue:)) ?? .mixed }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.lastMode) }
    }
}

extension SettingsStore: ModeMemory {
    public func loadMode() -> ConversionMode { lastMode }
    public func saveMode(_ mode: ConversionMode) { lastMode = mode }
}
