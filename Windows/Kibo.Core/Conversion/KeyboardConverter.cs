using System.Text;

namespace Kibo.Core;

/// <summary>
/// The whole conversion domain, behind one call. Callers — the tray shell, the tests — know only
/// this. Mapping tables, run splitting, and the orthography gate stay on the other side of it.
/// </summary>
public interface IKeyboardConverting
{
    ConversionResult Convert(string input, ConversionMode mode);
}

/// <summary>
/// Pure, deterministic, synchronous. No clipboard, no persistence, no UI, no clock — the same
/// input and mode always produce the same output, which is what lets
/// <c>Fixtures/conversion-cases.json</c> serve as the contract between this and the Swift
/// original. The port of <c>KeyboardConverter.swift</c>.
/// </summary>
public sealed class KeyboardConverter : IKeyboardConverting
{
    public ConversionResult Convert(string input, ConversionMode mode)
    {
        var output = mode switch
        {
            ConversionMode.EnglishToThai => MapEveryScalar(input, ThaiForQwerty),
            ConversionMode.ThaiToEnglish => MapEveryScalar(input, KedmaneeMapping.QwertyForThai),
            ConversionMode.Mixed => ConvertRuns(input, RunJudge.ShouldConvert),
            ConversionMode.SwapAll => ConvertRuns(input, static _ => true),
            _ => throw new ArgumentOutOfRangeException(nameof(mode), mode, null),
        };
        return new ConversionResult(input, output, mode);
    }

    /// <summary>
    /// The QWERTY → Thai lookup, with one fallback the raw table does not have: if the scalar is
    /// a character an OS substituted for a keystroke (<c>’</c> for <c>'</c>, <c>—</c> for
    /// <c>-</c>), convert the key that was actually pressed. Only the outbound direction folds,
    /// and only at the moment a scalar is being converted — text this converter decides to leave
    /// alone keeps its curls.
    /// </summary>
    private static Rune? ThaiForQwerty(Rune scalar)
    {
        if (KedmaneeMapping.ThaiForQwerty(scalar) is { } mapped) return mapped;
        if (TypographicSubstitutes.AsciiKeyFor(scalar) is not { } key) return null;
        return KedmaneeMapping.ThaiForQwerty(key);
    }

    /// <summary>
    /// Mechanical whole-string conversion. Anything the table has no entry for is copied over
    /// untouched rather than dropped — whitespace, emoji, other scripts, and text already in the
    /// destination script all survive.
    /// </summary>
    private static string MapEveryScalar(string input, Func<Rune, Rune?> lookup)
    {
        var output = new StringBuilder(input.Length);
        Span<char> buffer = stackalloc char[2];
        foreach (var scalar in input.EnumerateRunes())
        {
            var written = (lookup(scalar) ?? scalar).EncodeToUtf16(buffer);
            output.Append(buffer[..written]);
        }
        return output.ToString();
    }

    /// <summary>
    /// Split into runs and convert the ones <paramref name="shouldConvert"/> selects, each in the
    /// direction implied by the script it is currently in: Thai goes back to English, Latin goes
    /// to Thai. The predicate is the only difference between the two per-run modes — Mixed passes
    /// <see cref="RunJudge.ShouldConvert"/>, SwapAll a constant <c>true</c>. Sharing the walk keeps
    /// them from drifting.
    /// </summary>
    private static string ConvertRuns(string input, Func<Run, bool> shouldConvert)
    {
        var output = new StringBuilder(input.Length);
        foreach (var run in RunSplitter.Split(input))
        {
            if (!shouldConvert(run))
            {
                output.Append(run.Text);
                continue;
            }
            output.Append(run.Script switch
            {
                Script.Thai => MapEveryScalar(run.Text, KedmaneeMapping.QwertyForThai),
                Script.Latin => MapEveryScalar(run.Text, ThaiForQwerty),
                // Whitespace, emoji, other scripts: on no keyboard layout here, so there is no
                // direction to flip them in. `RunJudge` never selects one, but SwapAll selects
                // everything, so this arm is load-bearing rather than exhaustive.
                _ => run.Text,
            });
        }
        return output.ToString();
    }
}
