namespace Kibo.Core.Tests;

public class ConverterModelTests
{
    private static (ConverterModel Model, InMemoryClipboard Clipboard) MakeModel(ConversionMode mode = ConversionMode.Mixed)
    {
        var clipboard = new InMemoryClipboard();
        return (new ConverterModel(clipboard, mode: mode), clipboard);
    }

    // MARK: - Output

    [Fact]
    public void Starts_empty()
    {
        var (model, _) = MakeModel();
        Assert.Equal("", model.Input);
        Assert.Equal("", model.Output);
        Assert.False(model.DidCopy);
    }

    [Fact]
    public void Output_updates_when_input_changes()
    {
        var (model, _) = MakeModel(ConversionMode.EnglishToThai);
        model.Input = "l;ylfu";
        Assert.Equal("สวัสดี", model.Output);
    }

    [Fact]
    public void Output_updates_when_mode_changes()
    {
        var (model, _) = MakeModel(ConversionMode.EnglishToThai);
        model.Input = "ครับ";
        Assert.True(model.Output == "ครับ", "no QWERTY keys to map");

        model.Mode = ConversionMode.ThaiToEnglish;
        Assert.Equal("8iy[", model.Output);
    }

    [Fact]
    public void Mixed_judges_each_run()
    {
        var (model, _) = MakeModel();
        Assert.Equal(ConversionMode.Mixed, model.Mode);
        model.Input = "l;ylfu ้ำสสน ครับ 2024 :)";
        Assert.Equal("สวัสดี hello ครับ 2024 :)", model.Output);
    }

    /// The shell binds to `PropertyChanged`; a setter that recomputes silently would leave the
    /// result field stale.
    [Fact]
    public void Output_change_is_announced()
    {
        var (model, _) = MakeModel(ConversionMode.EnglishToThai);
        var announced = new List<string?>();
        model.PropertyChanged += (_, e) => announced.Add(e.PropertyName);
        model.Input = "l;ylfu";
        Assert.Contains(nameof(ConverterModel.Input), announced);
        Assert.Contains(nameof(ConverterModel.Output), announced);
    }

    // MARK: - Actions

    [Fact]
    public void Swap_exchanges_the_explicit_directions()
    {
        var (model, _) = MakeModel(ConversionMode.EnglishToThai);
        model.SwapDirection();
        Assert.Equal(ConversionMode.ThaiToEnglish, model.Mode);
        model.SwapDirection();
        Assert.Equal(ConversionMode.EnglishToThai, model.Mode);
    }

    /// Mixed has no opposite, so Swap is a no-op rather than an error or a silent jump into one
    /// of the explicit modes.
    [Fact]
    public void Swap_leaves_mixed_alone()
    {
        var (model, _) = MakeModel(ConversionMode.Mixed);
        model.SwapDirection();
        Assert.Equal(ConversionMode.Mixed, model.Mode);
    }

    [Fact]
    public void Clear_resets_input_and_output()
    {
        var (model, _) = MakeModel(ConversionMode.EnglishToThai);
        model.Input = "l;ylfu";
        model.Clear();
        Assert.Equal("", model.Input);
        Assert.Equal("", model.Output);
    }

    // MARK: - Clipboard

    [Fact]
    public void Paste_reads_the_clipboard_into_the_input()
    {
        var (model, clipboard) = MakeModel(ConversionMode.EnglishToThai);
        clipboard.Contents = "l;ylfu";
        model.Paste();
        Assert.Equal("l;ylfu", model.Input);
        Assert.Equal("สวัสดี", model.Output);
    }

    [Fact]
    public void Paste_with_an_empty_clipboard_leaves_the_input_alone()
    {
        var (model, clipboard) = MakeModel();
        model.Input = "keep me";
        clipboard.Contents = null;
        model.Paste();
        Assert.Equal("keep me", model.Input);
    }

    [Fact]
    public void Copy_writes_the_output_not_the_input()
    {
        var (model, clipboard) = MakeModel(ConversionMode.EnglishToThai);
        model.Input = "l;ylfu";
        model.CopyOutput();
        Assert.Equal("สวัสดี", clipboard.Contents);
    }

    [Fact]
    public void Copy_with_empty_output_does_not_touch_the_clipboard()
    {
        var (model, clipboard) = MakeModel();
        clipboard.Contents = "untouched";
        model.CopyOutput();
        Assert.Equal("untouched", clipboard.Contents);
        Assert.Equal(0, clipboard.Writes);
        Assert.False(model.DidCopy);
    }

    // MARK: - The privacy invariant

    /// SPEC.md and AGENTS.md both promise the clipboard is read only on an explicit Paste and
    /// written only on an explicit Copy. Typing, switching modes, swapping, and clearing must all
    /// leave it untouched — this is the test that would catch a convenience feature breaking that.
    [Fact]
    public void Clipboard_is_untouched_by_everything_except_paste_and_copy()
    {
        var (model, clipboard) = MakeModel();
        model.Input = "l;ylfu";
        model.Mode = ConversionMode.EnglishToThai;
        model.SwapDirection();
        model.Clear();
        model.Input = "ไำะ";
        _ = model.Output;

        Assert.True(clipboard.Reads == 0, "something read the clipboard without a Paste");
        Assert.True(clipboard.Writes == 0, "something wrote the clipboard without a Copy");

        model.Paste();
        Assert.Equal(1, clipboard.Reads);
        Assert.Equal(0, clipboard.Writes);

        model.Input = "l;ylfu";
        model.CopyOutput();
        Assert.Equal(1, clipboard.Reads);
        Assert.Equal(1, clipboard.Writes);
    }

    // MARK: - Copy confirmation

    [Fact]
    public void Copy_raises_the_confirmation_flag()
    {
        var (model, _) = MakeModel(ConversionMode.EnglishToThai);
        model.Input = "l;ylfu";
        Assert.False(model.DidCopy);
        model.CopyOutput();
        Assert.True(model.DidCopy);
    }

    /// The confirmation refers to what was on screen when it was pressed, so any change that
    /// makes it stale must retract it.
    [Fact]
    public void Confirmation_is_retracted_when_the_result_changes()
    {
        var (model, _) = MakeModel(ConversionMode.EnglishToThai);
        model.Input = "l;ylfu";
        model.CopyOutput();

        model.Input = "vpkddbodkca";
        Assert.True(!model.DidCopy, "editing the input left a stale 'copied' confirmation");

        model.CopyOutput();
        model.Mode = ConversionMode.ThaiToEnglish;
        Assert.True(!model.DidCopy, "switching modes left a stale 'copied' confirmation");

        model.CopyOutput();
        model.Clear();
        Assert.True(!model.DidCopy, "clearing left a stale 'copied' confirmation");
    }

    [Fact]
    public void Dismiss_retracts_the_confirmation_on_request()
    {
        var (model, _) = MakeModel(ConversionMode.EnglishToThai);
        model.Input = "l;ylfu";
        model.CopyOutput();
        model.DismissCopyConfirmation();
        Assert.False(model.DidCopy);
    }

    // MARK: - Remembering the mode

    [Fact]
    public void Opens_in_the_remembered_mode()
    {
        var memory = new InMemoryModeMemory(ConversionMode.ThaiToEnglish);
        var model = new ConverterModel(new InMemoryClipboard(), memory: memory);
        Assert.Equal(ConversionMode.ThaiToEnglish, model.Mode);
    }

    /// Spelled `SwapAll` rather than `Default`, which would assert nothing. A first launch
    /// landing in the mode that converts *everything* is a product decision, so changing it should
    /// have to come through here.
    [Fact]
    public void Opens_in_both_when_there_is_nothing_to_remember()
    {
        var model = new ConverterModel(new InMemoryClipboard());
        Assert.Equal(ConversionMode.SwapAll, model.Mode);
        Assert.Equal(ConversionModes.Default, model.Mode);
    }

    [Fact]
    public void Changing_the_mode_remembers_it()
    {
        var memory = new InMemoryModeMemory(ConversionMode.Mixed);
        var model = new ConverterModel(new InMemoryClipboard(), memory: memory);

        model.Mode = ConversionMode.EnglishToThai;
        Assert.Equal(ConversionMode.EnglishToThai, memory.Mode);

        model.SwapDirection();
        Assert.True(memory.Mode == ConversionMode.ThaiToEnglish, "swapping is a mode change and must persist too");
        Assert.True(memory.Saves == 2, "the mode was saved more often than it changed");
    }

    /// Typing is not a mode change. Without this, every keystroke would write the settings file.
    [Fact]
    public void Editing_the_input_never_touches_the_mode_memory()
    {
        var memory = new InMemoryModeMemory();
        var model = new ConverterModel(new InMemoryClipboard(), memory: memory);

        model.Input = "l;ylfu";
        model.Input = "hello";
        model.Clear();
        model.CopyOutput();

        Assert.Equal(0, memory.Saves);
    }
}

public class ConverterModelSelectionTests
{
    /// Text that did not come through the input field — on macOS the Service, on Windows the
    /// clipboard fix — goes through here rather than through `Input`, because the flyout's field
    /// must not be overwritten by a conversion that happened somewhere else.
    [Fact]
    public void Converting_a_selection_uses_the_current_mode()
    {
        var model = new ConverterModel(new InMemoryClipboard(), mode: ConversionMode.EnglishToThai);
        Assert.Equal("สวัสดี", model.Convert("l;ylfu"));

        model.Mode = ConversionMode.ThaiToEnglish;
        Assert.Equal("l;ylfu", model.Convert("สวัสดี"));
    }

    [Fact]
    public void Converting_a_selection_leaves_the_input_and_result_alone()
    {
        var model = new ConverterModel(new InMemoryClipboard(), mode: ConversionMode.EnglishToThai);
        model.Input = "keep";
        _ = model.Convert("l;ylfu");
        Assert.Equal("keep", model.Input);
        Assert.True(model.Output == "าำำย", "the result still belongs to the field, not the selection");
    }

    [Fact]
    public void Converting_a_selection_never_touches_the_clipboard()
    {
        var clipboard = new InMemoryClipboard("untouched");
        var model = new ConverterModel(clipboard, mode: ConversionMode.SwapAll);
        _ = model.Convert("l;ylfu");
        Assert.Equal(0, clipboard.Reads);
        Assert.Equal(0, clipboard.Writes);
        Assert.Equal("untouched", clipboard.Contents);
    }
}

/// The Windows-only entry path: Windows has no Services menu, so "fix the text I just copied" is
/// a menu action that reads the clipboard once, converts in the current mode, and writes it back.
/// It is the third and last thing allowed to touch the clipboard, and the counts below are what
/// keep it to exactly one read and at most one write.
public class ConverterModelFixClipboardTests
{
    [Fact]
    public void Fixing_the_clipboard_reads_once_converts_and_writes_once()
    {
        var clipboard = new InMemoryClipboard("l;ylfu");
        var model = new ConverterModel(clipboard, mode: ConversionMode.EnglishToThai);

        Assert.Equal(FixClipboardOutcome.Fixed, model.FixClipboard());
        Assert.Equal("สวัสดี", clipboard.Contents);
        Assert.Equal(1, clipboard.Reads);
        Assert.Equal(1, clipboard.Writes);
    }

    [Fact]
    public void Fixing_the_clipboard_uses_the_current_mode()
    {
        var clipboard = new InMemoryClipboard("สวัสดี");
        var model = new ConverterModel(clipboard, mode: ConversionMode.SwapAll);
        Assert.Equal(FixClipboardOutcome.Fixed, model.FixClipboard());
        Assert.Equal("l;ylfu", clipboard.Contents);
    }

    [Fact]
    public void An_empty_clipboard_is_reported_and_never_written()
    {
        var clipboard = new InMemoryClipboard(null);
        var model = new ConverterModel(clipboard, mode: ConversionMode.SwapAll);
        Assert.Equal(FixClipboardOutcome.Empty, model.FixClipboard());
        Assert.Equal(0, clipboard.Writes);

        clipboard.Contents = "";
        Assert.Equal(FixClipboardOutcome.Empty, model.FixClipboard());
        Assert.Equal(0, clipboard.Writes);
    }

    /// Already-correct text in Mixed converts to itself. Writing it back would be a no-op the
    /// clipboard history could still see, so it is reported instead.
    [Fact]
    public void Text_the_mode_leaves_alone_is_reported_as_unchanged_and_never_written()
    {
        var clipboard = new InMemoryClipboard("hello ครับ");
        var model = new ConverterModel(clipboard, mode: ConversionMode.Mixed);
        Assert.Equal(FixClipboardOutcome.Unchanged, model.FixClipboard());
        Assert.Equal("hello ครับ", clipboard.Contents);
        Assert.Equal(1, clipboard.Reads);
        Assert.Equal(0, clipboard.Writes);
    }

    [Fact]
    public void Fixing_the_clipboard_leaves_the_field_and_confirmation_alone()
    {
        var clipboard = new InMemoryClipboard("l;ylfu");
        var model = new ConverterModel(clipboard, mode: ConversionMode.EnglishToThai);
        model.Input = "keep";
        model.CopyOutput();
        clipboard.Contents = "l;ylfu";

        _ = model.FixClipboard();

        Assert.Equal("keep", model.Input);
        Assert.Equal("าำำย", model.Output);
        Assert.True(model.DidCopy, "the field's own confirmation must not be retracted by a clipboard fix");
    }
}
