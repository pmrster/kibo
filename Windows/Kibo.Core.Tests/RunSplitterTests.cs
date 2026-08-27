namespace Kibo.Core.Tests;

public class RunSplitterTests
{
    /// Compact spelling of an expected split, so a case reads as close to the input as possible.
    private static void AssertSplit(string input, params (Script Script, string Text)[] expected)
    {
        var runs = RunSplitter.Split(input);
        Assert.Equal(expected.Select(e => e.Text), runs.Select(r => r.Text));
        Assert.Equal(expected.Select(e => e.Script), runs.Select(r => r.Script));
    }

    [Fact]
    public void Empty_input_produces_no_runs()
    {
        Assert.Empty(RunSplitter.Split(""));
    }

    [Fact]
    public void Single_script_input_is_one_run()
    {
        AssertSplit("hello", (Script.Latin, "hello"));
        AssertSplit("สวัสดี", (Script.Thai, "สวัสดี"));
    }

    /// Whitespace is neutral, which is what makes it a run boundary — two Latin words separated
    /// by a space are judged separately rather than as one blob.
    [Fact]
    public void Space_separates_runs_and_is_preserved()
    {
        AssertSplit("hello world", (Script.Latin, "hello"), (Script.Neutral, " "), (Script.Latin, "world"));
    }

    [Fact]
    public void The_worked_example_from_the_spec()
    {
        AssertSplit("l;ylfu ้ำสสน ครับ 2024 :)",
            (Script.Latin, "l;ylfu"), (Script.Neutral, " "),
            (Script.Thai, "้ำสสน"), (Script.Neutral, " "),
            (Script.Thai, "ครับ"), (Script.Neutral, " "),
            (Script.Latin, "2024"), (Script.Neutral, " "),
            (Script.Latin, ":)"));
    }

    /// Punctuation stays inside a Latin run. It has to: `;` is the `ว` key, so dropping it from
    /// the run would break `l;ylfu` → `สวัสดี`.
    [Fact]
    public void Ascii_punctuation_belongs_to_the_latin_run()
    {
        AssertSplit("l;ylfu", (Script.Latin, "l;ylfu"));
        AssertSplit("don't", (Script.Latin, "don't"));
    }

    [Fact]
    public void Script_change_without_whitespace_still_splits()
    {
        AssertSplit("helloสวัสดี", (Script.Latin, "hello"), (Script.Thai, "สวัสดี"));
    }

    /// Anything that is neither Thai nor printable ASCII is neutral and passes through: emoji,
    /// newlines, tabs, and other scripts.
    [Fact]
    public void Non_thai_non_ascii_is_neutral()
    {
        AssertSplit("hi🐈there", (Script.Latin, "hi"), (Script.Neutral, "🐈"), (Script.Latin, "there"));
        AssertSplit("a\n\tb", (Script.Latin, "a"), (Script.Neutral, "\n\t"), (Script.Latin, "b"));
        AssertSplit("café", (Script.Latin, "caf"), (Script.Neutral, "é"));
        AssertSplit("日本", (Script.Neutral, "日本"));
    }

    /// Adjacent neutral scalars coalesce rather than producing a run each.
    [Fact]
    public void Consecutive_neutrals_form_one_run()
    {
        AssertSplit("a   b", (Script.Latin, "a"), (Script.Neutral, "   "), (Script.Latin, "b"));
    }

    /// Splitting must not lose or reorder anything — the runs always rejoin to the input.
    [Fact]
    public void Runs_always_rejoin_to_the_input()
    {
        foreach (var input in new[]
                 {
                     "", "hello", "สวัสดี", "l;ylfu ้ำสสน ครับ 2024 :)", "hi🐈there",
                     "a\n\tb", "café", "日本", "  ", "ๆๆๆ!!!",
                 })
        {
            Assert.Equal(input, string.Concat(RunSplitter.Split(input).Select(r => r.Text)));
        }
    }

    /// Thai combining marks must stay attached to the run, not be split off as neutral.
    [Fact]
    public void Thai_combining_marks_stay_in_the_thai_run()
    {
        var runs = RunSplitter.Split("ครับ");
        var run = Assert.Single(runs);
        Assert.Equal(4, run.Text.EnumerateRunes().Count());
    }

    /// The six typographic substitutes are Latin despite sitting outside ASCII, so `don’t` is one
    /// run and `RunJudge` sees a word to judge.
    [Fact]
    public void A_curled_apostrophe_keeps_its_word_in_one_run()
    {
        var run = Assert.Single(RunSplitter.Split("don’t"));
        Assert.Equal(Script.Latin, run.Script);
        Assert.Equal("don’t", run.Text);
    }

    [Fact]
    public void Curled_text_still_rejoins_to_the_input_exactly()
    {
        var input = "“don’t” — สวัสดี 2024";
        Assert.Equal(input, string.Concat(RunSplitter.Split(input).Select(r => r.Text)));
    }
}
