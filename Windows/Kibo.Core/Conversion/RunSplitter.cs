using System.Text;

namespace Kibo.Core;

/// <summary>Splits text into maximal same-script runs. The port of <c>RunSplitter.swift</c>.</summary>
internal static class RunSplitter
{
    /// <summary>
    /// ASCII punctuation stays <i>inside</i> the Latin run rather than being treated as neutral,
    /// and that is deliberate: <c>;</c> is the <c>ว</c> key, so pulling it out would break
    /// <c>l;ylfu</c> → <c>สวัสดี</c>. The cost is that a run like <c>2024</c> is nominally "Latin";
    /// <see cref="LatinOrthography"/> is what keeps it from being converted.
    /// <para>
    /// Space is excluded from the Latin range on purpose. It makes whitespace a run boundary, so
    /// two words either side of a space are judged separately instead of as one blob.
    /// </para>
    /// <para>
    /// Curly quotes and long dashes count as Latin even though they sit outside the ASCII range,
    /// because an OS put them there in place of <c>'</c>, <c>"</c> and <c>-</c>. Left neutral,
    /// they cut a word in two — <c>don’t</c> split into three runs — and <see cref="RunJudge"/>
    /// never saw a word to judge.
    /// </para>
    /// </summary>
    private static Script ScriptOf(Rune scalar) => scalar.Value switch
    {
        >= 0x0E00 and <= 0x0E7F => Script.Thai,
        >= 0x21 and <= 0x7E => Script.Latin,
        _ => TypographicSubstitutes.Contains(scalar) ? Script.Latin : Script.Neutral,
    };

    /// <summary>
    /// Runs always rejoin to the input exactly — nothing is dropped, reordered, or normalised.
    /// </summary>
    public static IReadOnlyList<Run> Split(string input)
    {
        var runs = new List<Run>();
        var current = new StringBuilder();
        Script? currentScript = null;

        foreach (var scalar in input.EnumerateRunes())
        {
            var scalarScript = ScriptOf(scalar);
            if (currentScript is { } open && scalarScript != open)
            {
                runs.Add(new Run(open, current.ToString()));
                current.Clear();
            }
            currentScript = scalarScript;
            current.Append(scalar.ToString());
        }
        if (currentScript is { } last)
        {
            runs.Add(new Run(last, current.ToString()));
        }
        return runs;
    }
}
