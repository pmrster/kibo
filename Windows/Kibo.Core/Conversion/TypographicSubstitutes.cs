using System.Text;

namespace Kibo.Core;

/// <summary>
/// Which key the user actually pressed, for the handful of characters an operating system swaps
/// out as they type. The port of <c>TypographicSubstitutes.swift</c>.
/// </summary>
/// <remarks>
/// <para>
/// macOS turns a typed <c>'</c> into <c>’</c>, <c>"</c> into <c>“</c>/<c>”</c> and <c>-</c> into
/// <c>–</c>; Word and many chat apps on Windows do the same. Text arriving by <b>Paste</b> is
/// curled just as often as text typed anywhere. (WPF's own <c>TextBox</c> substitutes nothing, so
/// on Windows this matters for pasted text rather than typed text.)
/// </para>
/// <para>
/// For most apps that is cosmetic. Here it is not: those three keys carry Kedmanee characters —
/// <c>'</c> is <c>ง</c>, <c>"</c> is <c>.</c>, <c>-</c> is <c>ข</c> — so a curled apostrophe is a
/// keystroke the converter can no longer recognise.
/// </para>
/// <para>
/// <b>Deliberately not part of <see cref="KedmaneeMapping"/>.</b> That table is a bijection of
/// physical keys. This is a many-to-one fold of characters that are on no key at all, and it
/// applies in the QWERTY → Thai direction only: the Thai → English direction emits the straight
/// ASCII the layout actually prints, because there is no curled <c>ง</c>. <c>…</c> is absent
/// because it replaces <i>three</i> <c>.</c> presses, and folding it to one would drop two.
/// </para>
/// </remarks>
public static class TypographicSubstitutes
{
    public readonly record struct SubstitutePair(Rune Substitute, Rune Key);

    /// <summary>
    /// Written as escapes so the pairs stay legible: <c>‘</c> and <c>’</c> are hard to tell apart
    /// at 11pt, and the whole point of the table is that they are different characters.
    /// </summary>
    private static readonly (char Substitute, char Key)[] Table =
    [
        ('‘', '\''),   // ‘  LEFT SINGLE QUOTATION MARK
        ('’', '\''),   // ’  RIGHT SINGLE QUOTATION MARK — a typed apostrophe becomes this
        ('“', '"'),    // “  LEFT DOUBLE QUOTATION MARK
        ('”', '"'),    // ”  RIGHT DOUBLE QUOTATION MARK
        ('–', '-'),    // –  EN DASH
        ('—', '-'),    // —  EM DASH
    ];

    /// <summary>
    /// The whole fold, so <c>Fixtures/conversion-cases.json</c> can be checked against it.
    /// </summary>
    public static IReadOnlyList<SubstitutePair> Pairs { get; } =
        Table.Select(p => new SubstitutePair(new Rune(p.Substitute), new Rune(p.Key))).ToArray();

    private static readonly Dictionary<Rune, Rune> AsciiForSubstitute =
        Pairs.ToDictionary(p => p.Substitute, p => p.Key);

    /// <summary>The ASCII key this character stands in for, or <c>null</c> if it is not a substitution.</summary>
    public static Rune? AsciiKeyFor(Rune scalar) => AsciiForSubstitute.TryGetValue(scalar, out var key) ? key : null;

    /// <summary>
    /// Whether this scalar is one of the substitutes, so <see cref="RunSplitter"/> can keep it inside
    /// the Latin run it belongs to instead of treating it as neutral and cutting the word in half.
    /// </summary>
    public static bool Contains(Rune scalar) => AsciiForSubstitute.ContainsKey(scalar);
}
