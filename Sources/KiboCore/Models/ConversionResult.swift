import Foundation

/// What the converter produced, carrying the input and mode alongside so a caller holding a
/// result never has to remember which question it answered.
public struct ConversionResult: Equatable, Sendable {
    public let input: String
    public let output: String
    public let mode: ConversionMode

    public init(input: String, output: String, mode: ConversionMode) {
        self.input = input
        self.output = output
        self.mode = mode
    }
}
