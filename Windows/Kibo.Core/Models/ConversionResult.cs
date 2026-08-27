namespace Kibo.Core;

/// <summary>
/// What the converter produced, carrying the input and mode alongside so a caller holding a
/// result never has to remember which question it answered.
/// </summary>
public readonly record struct ConversionResult(string Input, string Output, ConversionMode Mode);
