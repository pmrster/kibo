namespace Kibo.Core;

/// <summary>Which script a run is in.</summary>
internal enum Script
{
    /// <summary>Thai script.</summary>
    Thai,
    /// <summary>Printable ASCII — letters, digits, and punctuation alike — plus the typographic substitutes.</summary>
    Latin,
    /// <summary>Everything else. Never converted, never judged, passed through exactly.</summary>
    Neutral,
}

/// <summary>
/// A maximal stretch of one kind of text. Mixed mode judges and converts one run at a time, so
/// where the boundaries fall decides what gets judged together.
/// </summary>
internal readonly record struct Run(Script Script, string Text);
