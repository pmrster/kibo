using System.Text;

namespace Kibo.Core;

/// <summary>
/// The Thai Kedmanee layout mapped to the US QWERTY layout, key by key. The port of
/// <c>KedmaneeMapping.swift</c>.
/// </summary>
/// <remarks>
/// <para>
/// Every pair below was dumped from macOS's own layout data rather than transcribed by hand — see
/// <c>Tools/dump-kedmanee.swift</c> — and this C# table is a transcription of that dump, held to
/// it by <c>FixtureConformanceTests</c>. Two keys in particular defeat intuition and are worth not
/// "correcting": <c>3</c> produces <c>_</c> (underscore) and the backtick produces <c>-</c>.
/// </para>
/// <para>
/// All 94 printable ASCII keys carry a Kedmanee character, and no two land on the same one, so the
/// table is a bijection and the Thai → English direction is a plain inversion of it. Eleven keys
/// produce ASCII on the Kedmanee side (<c>/ _ - + % ( ) " , . ?</c>); they are part of the
/// mapping like any other key.
/// </para>
/// <para>
/// <b>Why the escapes.</b> Fifteen Kedmanee characters are Unicode nonspacing marks. Written
/// literally they would render attached to the quote before them, and a reader would be asked to
/// tell <c>ิ</c> from <c>ี</c> at 11pt. Each is an explicit escape with its name in a comment.
/// </para>
/// <para>
/// <b>Why <see cref="Rune"/>.</b> Lookups are keyed by Unicode scalar, never by <c>char</c> or by
/// text element, and this is load-bearing: Thai combining marks fuse with the consonant before
/// them, so "สวัสดี" is six scalars but four text elements, and an emoji is one scalar but two
/// <c>char</c>s. <see cref="KeyboardConverter"/> walks <c>EnumerateRunes()</c>, and these
/// dictionaries match.
/// </para>
/// </remarks>
public static class KedmaneeMapping
{
    public readonly record struct KeyPair(Rune Qwerty, Rune Kedmanee);

    /// <summary>
    /// Laid out in physical keyboard rows, unshifted then shifted, so a row can be read straight
    /// off a real keyboard.
    /// </summary>
    private static readonly (char Qwerty, char Kedmanee)[] Table =
    [
        // ── Number row ──────────────────────────────────────────────────────────────────────
        ('`', '-'), ('1', 'ๅ'), ('2', '/'), ('3', '_'), ('4', 'ภ'), ('5', 'ถ'),
        ('6', '\u0E38'),                                                    // ุ  SARA U
        ('7', '\u0E36'),                                                    // ึ  SARA UE
        ('8', 'ค'), ('9', 'ต'), ('0', 'จ'), ('-', 'ข'), ('=', 'ช'),

        ('~', '%'), ('!', '+'), ('@', '๑'), ('#', '๒'), ('$', '๓'), ('%', '๔'),
        ('^', '\u0E39'),                                                    // ู  SARA UU
        ('&', '฿'), ('*', '๕'), ('(', '๖'), (')', '๗'), ('_', '๘'), ('+', '๙'),

        // ── Top row ─────────────────────────────────────────────────────────────────────────
        ('q', 'ๆ'), ('w', 'ไ'), ('e', 'ำ'), ('r', 'พ'), ('t', 'ะ'),
        ('y', '\u0E31'),                                                    // ั  MAI HAN AKAT
        ('u', '\u0E35'),                                                    // ี  SARA II
        ('i', 'ร'), ('o', 'น'), ('p', 'ย'), ('[', 'บ'), (']', 'ล'), ('\\', 'ฃ'),

        ('Q', '๐'), ('W', '"'), ('E', 'ฎ'), ('R', 'ฑ'), ('T', 'ธ'),
        ('Y', '\u0E4D'),                                                    // ํ  NIKHAHIT
        ('U', '\u0E4A'),                                                    // ๊  MAI TRI
        ('I', 'ณ'), ('O', 'ฯ'), ('P', 'ญ'), ('{', 'ฐ'), ('}', ','), ('|', 'ฅ'),

        // ── Home row ────────────────────────────────────────────────────────────────────────
        ('a', 'ฟ'), ('s', 'ห'), ('d', 'ก'), ('f', 'ด'), ('g', 'เ'),
        ('h', '\u0E49'),                                                    // ้  MAI THO
        ('j', '\u0E48'),                                                    // ่  MAI EK
        ('k', 'า'), ('l', 'ส'), (';', 'ว'), ('\'', 'ง'),

        ('A', 'ฤ'), ('S', 'ฆ'), ('D', 'ฏ'), ('F', 'โ'), ('G', 'ฌ'),
        ('H', '\u0E47'),                                                    // ็  MAITAIKHU
        ('J', '\u0E4B'),                                                    // ๋  MAI CHATTAWA
        ('K', 'ษ'), ('L', 'ศ'), (':', 'ซ'), ('"', '.'),

        // ── Bottom row ──────────────────────────────────────────────────────────────────────
        ('z', 'ผ'), ('x', 'ป'), ('c', 'แ'), ('v', 'อ'),
        ('b', '\u0E34'),                                                    // ิ  SARA I
        ('n', '\u0E37'),                                                    // ื  SARA UEE
        ('m', 'ท'), (',', 'ม'), ('.', 'ใ'), ('/', 'ฝ'),

        ('Z', '('), ('X', ')'), ('C', 'ฉ'), ('V', 'ฮ'),
        ('B', '\u0E3A'),                                                    // ฺ  PHINTHU
        ('N', '\u0E4C'),                                                    // ์  THANTHAKHAT
        ('M', '?'), ('<', 'ฒ'), ('>', 'ฬ'), ('?', 'ฦ'),
    ];

    public static IReadOnlyList<KeyPair> Pairs { get; }

    private static readonly Dictionary<Rune, Rune> EnToTh;
    private static readonly Dictionary<Rune, Rune> ThToEn;

    static KedmaneeMapping()
    {
        Pairs = Table.Select(p => new KeyPair(new Rune(p.Qwerty), new Rune(p.Kedmanee))).ToArray();

        // `Add`, not the indexer: the indexer would silently overwrite a duplicate and break the
        // bijection with no error, where Swift's `Dictionary(uniqueKeysWithValues:)` traps. Here a
        // duplicate on either side throws at type initialisation, so a bad table cannot load.
        EnToTh = new Dictionary<Rune, Rune>(Pairs.Count);
        ThToEn = new Dictionary<Rune, Rune>(Pairs.Count);
        foreach (var pair in Pairs)
        {
            EnToTh.Add(pair.Qwerty, pair.Kedmanee);
            ThToEn.Add(pair.Kedmanee, pair.Qwerty);
        }
    }

    /// <summary>
    /// The scalar this physical key prints with the Thai layout active. <c>null</c> for anything
    /// that is not a mapped key — whitespace, emoji, accented Latin, Thai script itself.
    /// </summary>
    public static Rune? ThaiForQwerty(Rune key) => EnToTh.TryGetValue(key, out var thai) ? thai : null;

    /// <summary>
    /// The inverse: which physical key printed this Kedmanee scalar. <c>null</c> when the scalar
    /// is not on the Thai layout at all.
    /// </summary>
    public static Rune? QwertyForThai(Rune key) => ThToEn.TryGetValue(key, out var qwerty) ? qwerty : null;
}
