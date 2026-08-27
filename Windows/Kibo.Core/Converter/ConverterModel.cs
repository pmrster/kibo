using System.ComponentModel;

namespace Kibo.Core;

/// <summary>What <see cref="ConverterModel.FixClipboard"/> found on the clipboard.</summary>
public enum FixClipboardOutcome
{
    /// <summary>The text was converted and written back.</summary>
    Fixed,
    /// <summary>The current mode left the text as it was, so nothing was written.</summary>
    Unchanged,
    /// <summary>The clipboard held no text.</summary>
    Empty,
}

/// <summary>
/// The converter window's state and behaviour. The port of <c>ConverterModel.swift</c>.
/// </summary>
/// <remarks>
/// It lives in Core rather than in the WPF shell because it is logic, and logic is what this
/// project holds — which is also what makes it testable without a running app. It owns no mapping
/// rules of its own; it asks <see cref="IKeyboardConverting"/> and reports the answer.
/// <para>
/// UI-thread-affine by convention, the C# stand-in for Swift's <c>@MainActor</c>: the shell binds
/// to it and calls it from the dispatcher thread only. It holds no timers — the 1.6 s retraction
/// of the Copy confirmation belongs to the view, as it does on macOS.
/// </para>
/// </remarks>
public sealed class ConverterModel : INotifyPropertyChanged
{
    private readonly IKeyboardConverting converter;
    private readonly IClipboard clipboard;
    private readonly IModeMemory? memory;

    private string input = "";
    private ConversionMode mode;
    private string output = "";
    private bool didCopy;

    public event PropertyChangedEventHandler? PropertyChanged;

    /// <param name="clipboard">The only clipboard this model will ever touch.</param>
    /// <param name="converter">Defaults to the real <see cref="KeyboardConverter"/>.</param>
    /// <param name="memory">Where the mode is remembered. Optional because most tests do not care,
    /// and the model must work without persistence.</param>
    /// <param name="mode">The mode to open in. Omit it to open in the remembered mode, or in
    /// <see cref="ConversionModes.Default"/> when there is no memory to consult.</param>
    public ConverterModel(IClipboard clipboard, IKeyboardConverting? converter = null,
                          IModeMemory? memory = null, ConversionMode? mode = null)
    {
        this.clipboard = clipboard;
        this.converter = converter ?? new KeyboardConverter();
        this.memory = memory;
        // Assigned to the field, not the property: construction neither recomputes (the input is
        // empty) nor saves the mode (nothing changed) — as Swift's `didSet` does not fire in `init`.
        this.mode = mode ?? memory?.LoadMode() ?? ConversionModes.Default;
    }

    /// <summary>What the user typed or pasted.</summary>
    public string Input
    {
        get => input;
        set
        {
            // Always refreshes, even for an equal value, matching Swift's `didSet`.
            input = value;
            OnPropertyChanged(nameof(Input));
            Refresh();
        }
    }

    /// <summary>
    /// Which question we are asking of the text. Remembered across launches when an
    /// <see cref="IModeMemory"/> was supplied.
    /// </summary>
    public ConversionMode Mode
    {
        get => mode;
        set
        {
            mode = value;
            OnPropertyChanged(nameof(Mode));
            Refresh();
            memory?.SaveMode(value);
        }
    }

    /// <summary>
    /// The converted text. Recomputed when the input or mode changes rather than on every read,
    /// since the view may read it several times per frame and the input can run to 100k characters.
    /// </summary>
    public string Output
    {
        get => output;
        private set
        {
            output = value;
            OnPropertyChanged(nameof(Output));
        }
    }

    /// <summary>
    /// Whether the Copy confirmation should be showing. Retracted automatically as soon as the
    /// result changes, so the confirmation can never refer to text that is no longer on screen.
    /// </summary>
    public bool DidCopy
    {
        get => didCopy;
        private set
        {
            didCopy = value;
            OnPropertyChanged(nameof(DidCopy));
        }
    }

    // MARK: - Actions

    /// <summary>
    /// Swaps the two explicit directions. Mixed and Both have no opposite, so this leaves them as
    /// they are rather than picking one arbitrarily.
    /// </summary>
    public void SwapDirection() => Mode = Mode.Swapped();

    public void Clear() => Input = "";

    /// <summary>
    /// Reads the clipboard into the input. An empty or non-text clipboard leaves the input alone —
    /// silently blanking what the user typed would be worse than doing nothing.
    /// </summary>
    public void Paste()
    {
        var text = clipboard.Read();
        if (string.IsNullOrEmpty(text)) return;
        Input = text;
    }

    /// <summary>
    /// Writes the <i>result</i> to the clipboard, never the input, and does nothing when there is
    /// no result to write.
    /// </summary>
    public void CopyOutput()
    {
        if (Output.Length == 0) return;
        clipboard.Write(Output);
        DidCopy = true;
    }

    /// <summary>Lets the shell retract the confirmation on a timer without reaching into private state.</summary>
    public void DismissCopyConfirmation() => DidCopy = false;

    /// <summary>
    /// Converts text that did not come through the input field. It uses the mode the converter is
    /// currently set to, so the picker is the one control for every path, and it deliberately
    /// bypasses <see cref="Input"/>: the field belongs to whatever the user was working on there,
    /// and a conversion that happened elsewhere must not overwrite it. It never touches the
    /// clipboard.
    /// </summary>
    public string Convert(string text) => converter.Convert(text, Mode).Output;

    /// <summary>
    /// The Windows stand-in for the macOS Service: fix the text the user just copied, in place on
    /// the clipboard. Exactly one read; a write only when the mode actually changed something, so
    /// already-correct text is never re-posted for clipboard history to see. Touches neither the
    /// field nor its confirmation.
    /// </summary>
    public FixClipboardOutcome FixClipboard()
    {
        var text = clipboard.Read();
        if (string.IsNullOrEmpty(text)) return FixClipboardOutcome.Empty;

        var converted = Convert(text);
        if (string.Equals(converted, text, StringComparison.Ordinal)) return FixClipboardOutcome.Unchanged;

        clipboard.Write(converted);
        return FixClipboardOutcome.Fixed;
    }

    private void Refresh()
    {
        Output = converter.Convert(Input, Mode).Output;
        DidCopy = false;
    }

    private void OnPropertyChanged(string name) => PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
