using System.Runtime.CompilerServices;

namespace Kibo.Core.Tests;

/// Where the repository is, derived from this file's own path at compile time — the same
/// arithmetic as `#filePath` in the Swift suite. There is no resource bundle on purpose: a test
/// that reaches for the real `Fixtures/conversion-cases.json` cannot silently pass against a
/// stale copy. This is also why `ContinuousIntegrationBuild` must stay off: it rewrites
/// `[CallerFilePath]` to `/_/…` and the lookup breaks.
internal static class RepoPaths
{
    public static string Root { get; } = Locate();

    public static string Fixture => Path.Combine(Root, "Fixtures", "conversion-cases.json");

    // Windows/Kibo.Core.Tests/RepoPaths.cs → its directory → Windows/ → the repo root. (Swift's
    // `#filePath` needs three `deletingLastPathComponent()`s because it starts from the file;
    // `GetDirectoryName` has already taken the first of those.)
    private static string Locate([CallerFilePath] string path = "") =>
        Path.GetFullPath(Path.Combine(Path.GetDirectoryName(path)!, "..", ".."));
}
