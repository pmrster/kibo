import XCTest
@testable import KiboCore

/// Proves this implementation against `Fixtures/conversion-cases.json`.
///
/// That file is the portable behaviour contract PLAN.md calls for: a later Windows implementation
/// runs the same cases from the same file, and the two stay in lockstep because neither is allowed
/// to change it unilaterally. The fixture is deliberately readable — plain JSON, no compression,
/// no code — so it can be consumed by any language.
///
/// It is read from the repository rather than a resource bundle: the package declares no
/// resources, and a test that reaches for the real file cannot silently pass against a stale copy.
final class FixtureConformanceTests: XCTestCase {

    // Tests/KiboCoreTests/ThisFile.swift → repo root is three levels up.
    private static let fixtureURL = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/conversion-cases.json")

    private struct Fixture: Decodable {
        struct MappedKey: Decodable {
            let qwerty: String
            let kedmanee: String
        }
        struct Case: Decodable {
            let name: String
            let mode: String
            let input: String
            let output: String
        }
        let version: Int
        let mapping: [MappedKey]
        let cases: [Case]
    }

    private func loadFixture() throws -> Fixture {
        let data = try Data(contentsOf: Self.fixtureURL)
        return try JSONDecoder().decode(Fixture.self, from: data)
    }

    func test_fixture_is_the_version_this_suite_understands() throws {
        XCTAssertEqual(try loadFixture().version, 1)
    }

    /// The fixture carries the whole key table, so a port can verify its mapping before it ever
    /// runs a conversion — which is where a port is most likely to go wrong.
    func test_fixture_mapping_matches_the_implementation() throws {
        let fixture = try loadFixture()
        XCTAssertEqual(fixture.mapping.count, KedmaneeMapping.pairs.count)

        for entry in fixture.mapping {
            let qwerty = try XCTUnwrap(entry.qwerty.unicodeScalars.first,
                                       "empty qwerty entry in fixture")
            let kedmanee = try XCTUnwrap(entry.kedmanee.unicodeScalars.first,
                                         "empty kedmanee entry in fixture")
            XCTAssertEqual(entry.qwerty.unicodeScalars.count, 1, "'\(entry.qwerty)' is not one scalar")
            XCTAssertEqual(entry.kedmanee.unicodeScalars.count, 1, "'\(entry.kedmanee)' is not one scalar")

            XCTAssertEqual(KedmaneeMapping.thai(forQwerty: qwerty), kedmanee,
                           "fixture maps '\(entry.qwerty)' → '\(entry.kedmanee)'")
            XCTAssertEqual(KedmaneeMapping.qwerty(forThai: kedmanee), qwerty,
                           "fixture reverse of '\(entry.kedmanee)'")
        }
    }

    func test_every_fixture_case_converts_as_specified() throws {
        let fixture = try loadFixture()
        let converter = KeyboardConverter()
        XCTAssertFalse(fixture.cases.isEmpty)

        for testCase in fixture.cases {
            let mode = try XCTUnwrap(ConversionMode(rawValue: testCase.mode),
                                     "unknown mode '\(testCase.mode)' in case '\(testCase.name)'")
            XCTAssertEqual(converter.convert(testCase.input, mode: mode).output,
                           testCase.output,
                           "case: \(testCase.name)")
        }
    }

    /// A port that only implements the explicit directions would still pass a fixture full of
    /// explicit cases. Guard that all three modes are actually exercised.
    func test_fixture_exercises_every_mode() throws {
        let modes = Set(try loadFixture().cases.map(\.mode))
        for mode in ConversionMode.allCases {
            XCTAssertTrue(modes.contains(mode.rawValue), "no fixture case covers \(mode.rawValue)")
        }
    }
}
