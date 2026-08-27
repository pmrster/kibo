namespace Kibo.Core;

/// <summary>
/// The injected seam that plays the role <c>UserDefaults</c> plays for the macOS
/// <c>SettingsStore</c>: string keys, string values, nothing else. That narrowness is the point —
/// SPEC.md promises no entered or converted text is ever stored, and the way to keep the promise
/// is to have nowhere to put it.
/// </summary>
public interface IKeyValueStore
{
    string? Get(string key);

    /// <summary><c>null</c> removes the key.</summary>
    void Set(string key, string? value);
}

/// <summary>A store that lives in memory, for tests.</summary>
public sealed class InMemoryKeyValueStore : IKeyValueStore
{
    private readonly Dictionary<string, string> values = new(StringComparer.Ordinal);

    public string? Get(string key) => values.GetValueOrDefault(key);

    public void Set(string key, string? value)
    {
        if (value is null) values.Remove(key);
        else values[key] = value;
    }
}
