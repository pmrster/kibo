import XCTest
@testable import WhoForgotToChangeLangCore

final class SettingsStoreTests: XCTestCase {

    /// A throwaway defaults domain per test, so nothing leaks into the real user's preferences.
    private func makeStore(file: StaticString = #filePath, line: UInt = #line)
        throws -> (SettingsStore, UserDefaults, String) {
        let suite = "wfcl.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite), file: file, line: line)
        return (SettingsStore(defaults: defaults), defaults, suite)
    }

    private func tearDown(_ defaults: UserDefaults, _ suite: String) {
        defaults.removePersistentDomain(forName: suite)
    }

    func test_defaults_when_nothing_is_stored() throws {
        let (store, defaults, suite) = try makeStore()
        defer { tearDown(defaults, suite) }

        XCTAssertEqual(store.appearance, .system)
        XCTAssertEqual(store.fontSize, .small)
        XCTAssertEqual(store.lastMode, .mixed)
    }

    func test_values_round_trip() throws {
        let (store, defaults, suite) = try makeStore()
        defer { tearDown(defaults, suite) }

        store.appearance = .dark
        store.fontSize = .large
        store.lastMode = .thaiToEnglish

        XCTAssertEqual(store.appearance, .dark)
        XCTAssertEqual(store.fontSize, .large)
        XCTAssertEqual(store.lastMode, .thaiToEnglish)
    }

    /// A value written by a newer build, or corrupted by hand, must not crash an older one.
    func test_unrecognised_stored_values_fall_back_to_defaults() throws {
        let (store, defaults, suite) = try makeStore()
        defer { tearDown(defaults, suite) }

        defaults.set("chartreuse", forKey: "wfcl.appearance")
        defaults.set("enormous", forKey: "wfcl.fontSize")
        defaults.set("telepathy", forKey: "wfcl.lastMode")

        XCTAssertEqual(store.appearance, .system)
        XCTAssertEqual(store.fontSize, .small)
        XCTAssertEqual(store.lastMode, .mixed)
    }

    func test_font_size_factors_only_grow() {
        XCTAssertEqual(FontSize.small.factor, 1.0)
        XCTAssertLessThan(FontSize.small.factor, FontSize.medium.factor)
        XCTAssertLessThan(FontSize.medium.factor, FontSize.large.factor)
    }
}
