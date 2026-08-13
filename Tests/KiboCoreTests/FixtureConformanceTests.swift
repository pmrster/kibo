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
        struct Substitute: Decodable {
            let substitute: String
            let key: String
        }
        struct Case: Decodable {
            let name: String
            let mode: String
            let input: String
            let output: String
        }
        let version: Int
        let mapping: [MappedKey]
        let typographicSubstitutes: [Substitute]
        let cases: [Case]
    }

    private func loadFixture() throws -> Fixture {
        let data = try Data(contentsOf: Self.fixtureURL)
        return try JSONDecoder().decode(Fixture.self, from: data)
    }

    func test_fixture_is_the_version_this_suite_understands() throws {
        XCTAssertEqual(try loadFixture().version, 3)
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

    /// The fold is carried too, for the same reason the key table is: a port that has the cases
    /// but not the table can only satisfy them by hard-coding six characters it does not
    /// understand. Both curls fold to one key, so this side is many-to-one and is *not* checked
    /// for an inverse.
    func test_fixture_typographic_substitutes_match_the_implementation() throws {
        let fixture = try loadFixture()
        XCTAssertEqual(fixture.typographicSubstitutes.count, TypographicSubstitutes.pairs.count)

        for entry in fixture.typographicSubstitutes {
            XCTAssertEqual(entry.substitute.unicodeScalars.count, 1,
                           "'\(entry.substitute)' is not one scalar")
            XCTAssertEqual(entry.key.unicodeScalars.count, 1, "'\(entry.key)' is not one scalar")
            let substitute = try XCTUnwrap(entry.substitute.unicodeScalars.first)
            let key = try XCTUnwrap(entry.key.unicodeScalars.first)

            XCTAssertEqual(TypographicSubstitutes.asciiKey(for: substitute), key,
                           "fixture folds '\(entry.substitute)' → '\(entry.key)'")
            // The straight key must be a real key, or the fold lands nowhere.
            XCTAssertNotNil(KedmaneeMapping.thai(forQwerty: key),
                            "'\(entry.key)' is not a QWERTY key")
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

    // MARK: - The fixture must carry the accuracy contract, not a sample of it

    /// The point of these three tests.
    ///
    /// The fixture used to hold 24 cases while the real behaviour contract — 36 strings of correct
    /// text that must survive untouched, and the recall corpora — lived only in Swift. A Windows
    /// port could pass every case in the file and still mangle `array[i]`, `C:\Users\pmr` and
    /// `HTML`, which is the one failure SPEC.md calls unacceptable. A contract a port can satisfy
    /// while breaking the promise is not a contract.
    ///
    /// So: whatever `AccuracyCorpus` asserts against this implementation, the fixture must ask of
    /// every implementation. These tests fail if the JSON drifts from the Swift.
    func test_fixture_carries_every_precision_case() throws {
        let mixedCases = try mixedCasesByInput()
        for text in AccuracyCorpus.mustSurvive {
            let match = mixedCases[text]
            XCTAssertNotNil(match, "precision string '\(text)' is missing from the fixture")
            XCTAssertEqual(match, text, "the fixture lets '\(text)' be mangled")
        }
    }

    func test_fixture_carries_every_recall_case() throws {
        let mixedCases = try mixedCasesByInput()
        for word in AccuracyCorpus.englishCaught {
            let wreckage = AccuracyCorpus.mistypedOnThaiLayout(word)
            XCTAssertEqual(mixedCases[wreckage], word,
                           "the fixture does not require '\(wreckage)' → '\(word)'")
        }
        for word in AccuracyCorpus.thaiCaught {
            let wreckage = AccuracyCorpus.mistypedOnUSLayout(word)
            XCTAssertEqual(mixedCases[wreckage], word,
                           "the fixture does not require '\(wreckage)' → '\(word)'")
        }
    }

    /// The misses are part of the contract too. A port that "improves" on them has changed the
    /// gate, and needs to re-measure precision before claiming it did better.
    func test_fixture_carries_every_known_miss() throws {
        let mixedCases = try mixedCasesByInput()
        for word in AccuracyCorpus.englishMissed {
            let wreckage = AccuracyCorpus.mistypedOnThaiLayout(word)
            XCTAssertEqual(mixedCases[wreckage], wreckage,
                           "the fixture does not pin the known miss '\(word)'")
        }
        for word in AccuracyCorpus.thaiMissed {
            let wreckage = AccuracyCorpus.mistypedOnUSLayout(word)
            XCTAssertEqual(mixedCases[wreckage], wreckage,
                           "the fixture does not pin the known miss '\(word)'")
        }
    }

    private func mixedCasesByInput() throws -> [String: String] {
        Dictionary(
            try loadFixture().cases
                .filter { $0.mode == ConversionMode.mixed.rawValue }
                .map { ($0.input, $0.output) },
            uniquingKeysWith: { first, _ in first })
    }
}
