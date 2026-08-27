using System.Text;
using System.Text.Json;

namespace Kibo.Core.Tests;

/// Proves this implementation against `Fixtures/conversion-cases.json`.
///
/// That file is the portable behaviour contract PLAN.md calls for: the macOS original and this
/// port run the same cases from the same file, and the two stay in lockstep because neither is
/// allowed to change it unilaterally. It is read from the repository rather than copied into the
/// test project, so a stale copy cannot pass.
public class FixtureConformanceTests
{
    private sealed record Fixture(int Version, MappedKey[] Mapping, SubstituteEntry[] TypographicSubstitutes, Case[] Cases);
    private sealed record MappedKey(string Qwerty, string Kedmanee);
    private sealed record SubstituteEntry(string Substitute, string Key);
    private sealed record Case(string Name, string Mode, string Input, string Output);

    private static readonly JsonSerializerOptions Options = new() { PropertyNameCaseInsensitive = true };

    private static Fixture LoadFixture()
    {
        Assert.True(File.Exists(RepoPaths.Fixture), $"fixture not found at {RepoPaths.Fixture}");
        using var document = JsonDocument.Parse(File.ReadAllBytes(RepoPaths.Fixture));
        var root = document.RootElement;
        return new Fixture(
            root.GetProperty("version").GetInt32(),
            root.GetProperty("mapping").Deserialize<MappedKey[]>(Options)!,
            root.GetProperty("typographicSubstitutes").Deserialize<SubstituteEntry[]>(Options)!,
            root.GetProperty("cases").Deserialize<Case[]>(Options)!);
    }

    private static Rune SingleScalar(string text, string what)
    {
        Assert.True(text.EnumerateRunes().Count() == 1, $"'{text}' ({what}) is not one scalar");
        return Rune.GetRuneAt(text, 0);
    }

    /// Readers must refuse a version they do not understand.
    [Fact]
    public void Fixture_is_the_version_this_suite_understands()
    {
        Assert.Equal(3, LoadFixture().Version);
    }

    /// The fixture carries the whole key table, so a port can verify its mapping before it ever
    /// runs a conversion — which is where a port is most likely to go wrong.
    [Fact]
    public void Fixture_mapping_matches_the_implementation()
    {
        var fixture = LoadFixture();
        Assert.Equal(KedmaneeMapping.Pairs.Count, fixture.Mapping.Length);

        foreach (var entry in fixture.Mapping)
        {
            var qwerty = SingleScalar(entry.Qwerty, "qwerty");
            var kedmanee = SingleScalar(entry.Kedmanee, "kedmanee");
            Assert.True(kedmanee == KedmaneeMapping.ThaiForQwerty(qwerty), $"fixture maps '{entry.Qwerty}' → '{entry.Kedmanee}'");
            Assert.True(qwerty == KedmaneeMapping.QwertyForThai(kedmanee), $"fixture reverse of '{entry.Kedmanee}'");
        }
    }

    /// The fold is carried too. Both curls fold to one key, so this side is many-to-one and is
    /// *not* checked for an inverse.
    [Fact]
    public void Fixture_typographic_substitutes_match_the_implementation()
    {
        var fixture = LoadFixture();
        Assert.Equal(TypographicSubstitutes.Pairs.Count, fixture.TypographicSubstitutes.Length);

        foreach (var entry in fixture.TypographicSubstitutes)
        {
            var substitute = SingleScalar(entry.Substitute, "substitute");
            var key = SingleScalar(entry.Key, "key");
            Assert.True(key == TypographicSubstitutes.AsciiKeyFor(substitute), $"fixture folds '{entry.Substitute}' → '{entry.Key}'");
            // The straight key must be a real key, or the fold lands nowhere.
            Assert.True(KedmaneeMapping.ThaiForQwerty(key).HasValue, $"'{entry.Key}' is not a QWERTY key");
        }
    }

    [Fact]
    public void Every_fixture_case_converts_as_specified()
    {
        var fixture = LoadFixture();
        var converter = new KeyboardConverter();
        Assert.NotEmpty(fixture.Cases);

        foreach (var testCase in fixture.Cases)
        {
            Assert.True(ConversionModes.TryParse(testCase.Mode, out var mode), $"unknown mode '{testCase.Mode}' in case '{testCase.Name}'");
            var actual = converter.Convert(testCase.Input, mode).Output;
            Assert.True(string.Equals(testCase.Output, actual, StringComparison.Ordinal),
                $"case: {testCase.Name}\n  input:    '{testCase.Input}'\n  expected: '{testCase.Output}'\n  actual:   '{actual}'");
        }
    }

    /// A port that only implements the explicit directions would still pass a fixture full of
    /// explicit cases. Guard that all four modes are actually exercised.
    [Fact]
    public void Fixture_exercises_every_mode()
    {
        var modes = LoadFixture().Cases.Select(c => c.Mode).ToHashSet(StringComparer.Ordinal);
        foreach (var mode in ConversionModes.All)
        {
            Assert.True(modes.Contains(mode.RawValue()), $"no fixture case covers {mode.RawValue()}");
        }
    }

    // MARK: - The fixture must carry the accuracy contract, not a sample of it

    /// Whatever `AccuracyCorpus` asserts against this implementation, the fixture must ask of
    /// every implementation. These fail if the JSON drifts from the corpus.
    [Fact]
    public void Fixture_carries_every_precision_case()
    {
        var mixedCases = MixedCasesByInput();
        foreach (var text in AccuracyCorpus.MustSurvive)
        {
            Assert.True(mixedCases.TryGetValue(text, out var match), $"precision string '{text}' is missing from the fixture");
            Assert.True(text == match, $"the fixture lets '{text}' be mangled");
        }
    }

    [Fact]
    public void Fixture_carries_every_recall_case()
    {
        var mixedCases = MixedCasesByInput();
        foreach (var word in AccuracyCorpus.EnglishCaught)
        {
            var wreckage = AccuracyCorpus.MistypedOnThaiLayout(word);
            Assert.True(mixedCases.GetValueOrDefault(wreckage) == word, $"the fixture does not require '{wreckage}' → '{word}'");
        }
        foreach (var word in AccuracyCorpus.ThaiCaught)
        {
            var wreckage = AccuracyCorpus.MistypedOnUSLayout(word);
            Assert.True(mixedCases.GetValueOrDefault(wreckage) == word, $"the fixture does not require '{wreckage}' → '{word}'");
        }
    }

    /// The misses are part of the contract too. A port that "improves" on them has changed the
    /// gate, and needs to re-measure precision before claiming it did better.
    [Fact]
    public void Fixture_carries_every_known_miss()
    {
        var mixedCases = MixedCasesByInput();
        foreach (var word in AccuracyCorpus.EnglishMissed)
        {
            var wreckage = AccuracyCorpus.MistypedOnThaiLayout(word);
            Assert.True(mixedCases.GetValueOrDefault(wreckage) == wreckage, $"the fixture does not pin the known miss '{word}'");
        }
        foreach (var word in AccuracyCorpus.ThaiMissed)
        {
            var wreckage = AccuracyCorpus.MistypedOnUSLayout(word);
            Assert.True(mixedCases.GetValueOrDefault(wreckage) == wreckage, $"the fixture does not pin the known miss '{word}'");
        }
    }

    /// Mixed-mode cases by input, first wins on a duplicate — as the Swift `uniquingKeysWith`.
    private static Dictionary<string, string> MixedCasesByInput()
    {
        var result = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var c in LoadFixture().Cases.Where(c => c.Mode == ConversionMode.Mixed.RawValue()))
        {
            result.TryAdd(c.Input, c.Output);
        }
        return result;
    }
}
