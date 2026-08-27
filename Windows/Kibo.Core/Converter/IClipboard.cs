namespace Kibo.Core;

/// <summary>
/// The system clipboard, narrowed to the two operations this app is allowed to perform. The port
/// of <c>Clipboard.swift</c>.
/// </summary>
/// <remarks>
/// The interface is this small on purpose. SPEC.md promises the clipboard is read only when the
/// user asks (Paste, Fix clipboard) and written only when they ask (Copy, Fix clipboard), and a
/// two-method interface makes that promise auditable: <c>ConverterModelTests</c> counts the calls
/// and fails if anything else reaches for it. There is no "watch the clipboard" method to
/// accidentally start using.
/// </remarks>
public interface IClipboard
{
    /// <summary>The clipboard's current text, or <c>null</c> when it holds nothing readable as text.</summary>
    string? Read();

    void Write(string text);
}

/// <summary>
/// A clipboard that lives in memory, for tests. Counts accesses so the privacy invariant can be
/// asserted rather than assumed.
/// </summary>
public sealed class InMemoryClipboard(string? contents = null) : IClipboard
{
    public string? Contents { get; set; } = contents;
    public int Reads { get; private set; }
    public int Writes { get; private set; }

    public string? Read()
    {
        Reads++;
        return Contents;
    }

    public void Write(string text)
    {
        Writes++;
        Contents = text;
    }
}
