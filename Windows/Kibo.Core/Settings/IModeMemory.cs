namespace Kibo.Core;

/// <summary>
/// Where the converter remembers the mode it was left in. Narrow on purpose, in the same spirit
/// as <see cref="IClipboard"/>: "reopen in the mode you left it in" is a behaviour rule, so it
/// belongs to <see cref="ConverterModel"/> where it can be tested, not to the picker that happens
/// to draw it. Two methods, so a test can count the saves.
/// </summary>
public interface IModeMemory
{
    ConversionMode LoadMode();
    void SaveMode(ConversionMode mode);
}

/// <summary>A mode memory that lives in memory, for tests.</summary>
public sealed class InMemoryModeMemory(ConversionMode mode = ConversionModes.Default) : IModeMemory
{
    public int Saves { get; private set; }
    public ConversionMode Mode { get; set; } = mode;

    public ConversionMode LoadMode() => Mode;

    public void SaveMode(ConversionMode mode)
    {
        Saves++;
        Mode = mode;
    }
}
