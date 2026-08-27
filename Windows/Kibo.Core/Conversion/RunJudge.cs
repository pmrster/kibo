using System.Text;

namespace Kibo.Core;

/// <summary>
/// Decides, for one run, whether Mixed mode should convert it or leave it exactly as typed. The
/// port of <c>RunJudge.swift</c>.
/// </summary>
/// <remarks>
/// This is the whole difference between Mixed and the mechanical modes. Those flip everything;
/// Mixed asks this first, so text that is already correct survives a conversion of the text
/// around it.
/// </remarks>
internal static class RunJudge
{
    public static bool ShouldConvert(Run run) => run.Script switch
    {
        Script.Neutral => false,
        Script.Thai => !ThaiOrthography.IsWellFormed(run.Text),
        Script.Latin => !LatinOrthography.IsWellFormed(run.Text) || ReadsAsThaiInDisguise(run.Text),
        _ => false,
    };

    /// <summary>
    /// Below this, a run is too short to carry the evidence — short punctuation like <c>:)</c> and
    /// fragments like <c>a/b</c> are exactly what we must not touch. Four rather than three because
    /// three-scalar runs produced false positives without catching anything the other rules missed.
    /// </summary>
    private const int MinimumScalarsForDisguiseTest = 4;

    /// <summary>
    /// The second chance for Latin runs that carry too few letters to judge on English shape.
    /// <para>
    /// Thai consonants sit on digit and punctuation keys as often as on letter keys, so a
    /// perfectly ordinary Thai word can come back looking like line noise: <c>ขอบคุณ</c> mistyped
    /// is <c>-v[86I</c>, which has two letters in it. There is no English shape to test, so
    /// instead we ask the opposite question — does this turn into convincing Thai?
    /// </para>
    /// <para>Three conditions, all needed, and deliberately strict:</para>
    /// <list type="bullet">
    /// <item><b>Only when there is no English evidence.</b> Runs with enough letters are judged on
    /// their own shape and never reach here. Applying this test to them would convert real words:
    /// <c>rhythm</c> maps to well-formed Thai, and 36% of English does likewise.</item>
    /// <item><b>The conversion must be entirely Thai script and well-formed.</b> <c>2024</c> becomes
    /// <c>/จ/ภ</c>, which is half ASCII, so it stays a number.</item>
    /// <item><b>It must contain a vowel or tone mark.</b> Without this, <c>:)</c> would become
    /// <c>ซ๗</c> — two Thai characters that are not a word.</item>
    /// </list>
    /// The trial conversion uses the <i>unfolded</i> table on purpose: a curled quote in a
    /// letter-poor run is on no key, and aborts the test.
    /// </summary>
    private static bool ReadsAsThaiInDisguise(string text)
    {
        if (!LatinOrthography.HasTooFewLettersToJudge(text)) return false;

        var converted = new StringBuilder();
        var scalarCount = 0;
        foreach (var scalar in text.EnumerateRunes())
        {
            scalarCount++;
            if (KedmaneeMapping.ThaiForQwerty(scalar) is not { } thai) return false;
            converted.Append(thai.ToString());
        }
        if (scalarCount < MinimumScalarsForDisguiseTest) return false;

        var candidate = converted.ToString();
        return ThaiOrthography.IsEntirelyThaiScript(candidate)
            && ThaiOrthography.IsWellFormed(candidate)
            && ThaiOrthography.ContainsFollowingMark(candidate);
    }
}
