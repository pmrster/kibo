namespace Kibo.Core.Tests;

/// The file behind `%LOCALAPPDATA%\Kibo\settings.json`: a flat JSON object of strings, and
/// nothing else — there is nowhere in it to put entered or converted text.
public sealed class JsonFileKeyValueStoreTests : IDisposable
{
    private readonly string directory = Path.Combine(Path.GetTempPath(), "kibo-tests-" + Guid.NewGuid().ToString("N"));
    private string FilePath => Path.Combine(directory, "nested", "settings.json");

    public void Dispose()
    {
        if (Directory.Exists(directory)) Directory.Delete(directory, recursive: true);
    }

    [Fact]
    public void A_missing_file_reads_as_empty()
    {
        var store = new JsonFileKeyValueStore(FilePath);
        Assert.Null(store.Get("appearance"));
        Assert.False(File.Exists(FilePath));
    }

    [Fact]
    public void Values_round_trip_through_a_second_instance()
    {
        var first = new JsonFileKeyValueStore(FilePath);
        first.Set("appearance", "dark");
        first.Set("bubbleX", "12");

        var second = new JsonFileKeyValueStore(FilePath);
        Assert.Equal("dark", second.Get("appearance"));
        Assert.Equal("12", second.Get("bubbleX"));
    }

    [Fact]
    public void The_file_is_a_flat_json_object_of_strings()
    {
        var store = new JsonFileKeyValueStore(FilePath);
        store.Set("lastMode", "mixed");
        store.Set("appearance", "light");

        using var document = System.Text.Json.JsonDocument.Parse(File.ReadAllBytes(FilePath));
        var root = document.RootElement;
        Assert.Equal(System.Text.Json.JsonValueKind.Object, root.ValueKind);
        Assert.Equal("mixed", root.GetProperty("lastMode").GetString());
        Assert.Equal("light", root.GetProperty("appearance").GetString());
        Assert.Equal(2, root.EnumerateObject().Count());
    }

    [Fact]
    public void Setting_null_removes_the_key()
    {
        var store = new JsonFileKeyValueStore(FilePath);
        store.Set("bubbleX", "12");
        store.Set("bubbleX", null);
        Assert.Null(store.Get("bubbleX"));
        Assert.Null(new JsonFileKeyValueStore(FilePath).Get("bubbleX"));
    }

    /// A corrupted file must not take the converter down with it; it reads as empty and the next
    /// write replaces it cleanly.
    [Fact]
    public void Garbage_reads_as_empty_and_is_overwritten_by_the_next_write()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        File.WriteAllText(FilePath, "{ not json");

        var store = new JsonFileKeyValueStore(FilePath);
        Assert.Null(store.Get("appearance"));
        store.Set("appearance", "dark");
        Assert.Equal("dark", new JsonFileKeyValueStore(FilePath).Get("appearance"));
    }

    /// Non-string values are ignored rather than coerced, so a hand-edited `"bubbleX": 12`
    /// degrades to the default instead of half-working.
    [Fact]
    public void Non_string_values_are_ignored()
    {
        Directory.CreateDirectory(Path.GetDirectoryName(FilePath)!);
        File.WriteAllText(FilePath, "{ \"bubbleX\": 12, \"appearance\": \"dark\", \"nested\": { \"a\": 1 } }");

        var store = new JsonFileKeyValueStore(FilePath);
        Assert.Null(store.Get("bubbleX"));
        Assert.Equal("dark", store.Get("appearance"));
        Assert.Null(store.Get("nested"));
    }

    /// Written atomically — a temp file then a rename — so a crash mid-write cannot leave a
    /// half-written settings file, and no temp file is left behind afterwards.
    [Fact]
    public void Writes_leave_no_temporary_file_behind()
    {
        var store = new JsonFileKeyValueStore(FilePath);
        store.Set("appearance", "dark");
        var files = Directory.GetFiles(Path.GetDirectoryName(FilePath)!);
        Assert.Equal([FilePath], files);
    }
}
