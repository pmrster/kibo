using System.Text.Json;

namespace Kibo.Core;

/// <summary>
/// <see cref="IKeyValueStore"/> over one JSON file — a flat object of strings, nothing nested. The
/// shell points it at <c>%LOCALAPPDATA%\Kibo\settings.json</c>; it lives in Core, with the path
/// injected, because it is pure <c>System.Text.Json</c> and <c>File</c> and that is what makes it
/// testable on the Mac.
/// </summary>
/// <remarks>
/// Loaded once on construction. Missing, unreadable or malformed files read as empty, and every
/// write rewrites the whole file atomically — a temp file then a rename — so a crash mid-write
/// cannot leave half a settings file. Write failures are swallowed: a settings write must never
/// take the converter down with it.
/// </remarks>
public sealed class JsonFileKeyValueStore : IKeyValueStore
{
    private static readonly JsonSerializerOptions Options = new() { WriteIndented = true };

    private readonly string path;
    private readonly SortedDictionary<string, string> values = new(StringComparer.Ordinal);

    public JsonFileKeyValueStore(string path)
    {
        this.path = path;
        Load();
    }

    public string? Get(string key) => values.GetValueOrDefault(key);

    public void Set(string key, string? value)
    {
        if (value is null) values.Remove(key);
        else values[key] = value;
        Save();
    }

    private void Load()
    {
        try
        {
            if (!File.Exists(path)) return;
            using var document = JsonDocument.Parse(File.ReadAllBytes(path));
            if (document.RootElement.ValueKind != JsonValueKind.Object) return;
            foreach (var property in document.RootElement.EnumerateObject())
            {
                // Only strings. A hand-edited `"bubbleX": 12` degrades to the default rather than
                // half-working, and nothing nested is ever read.
                if (property.Value.ValueKind == JsonValueKind.String)
                {
                    values[property.Name] = property.Value.GetString()!;
                }
            }
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException or JsonException)
        {
            values.Clear();
        }
    }

    private void Save()
    {
        try
        {
            var directory = Path.GetDirectoryName(path);
            if (!string.IsNullOrEmpty(directory)) Directory.CreateDirectory(directory);
            var temporary = path + ".tmp";
            File.WriteAllBytes(temporary, JsonSerializer.SerializeToUtf8Bytes(values, Options));
            File.Move(temporary, path, overwrite: true);
        }
        catch (Exception e) when (e is IOException or UnauthorizedAccessException)
        {
            // Deliberately ignored; see the class remarks.
        }
    }
}
