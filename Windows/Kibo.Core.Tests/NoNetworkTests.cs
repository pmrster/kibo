using System.Net.Http;

namespace Kibo.Core.Tests;

/// The privacy invariant, asserted on the compiled binaries.
///
/// On macOS the sandbox entitlement is what turns "no network" from a README promise into a
/// kernel-enforced fact, and `package.sh` proves the signature carries it. Windows has no such
/// entitlement for an unpackaged app, so this is the proof instead: a metadata scan of the built
/// assemblies for any reference to the networking parts of the runtime. `package.ps1` and CI
/// point `KIBO_APP_ASSEMBLY` at the published app's DLLs so the release artefact itself is what
/// gets scanned.
public class NoNetworkTests
{
    /// The scanner has to be able to see networking when it is there, or a clean result means
    /// nothing. `System.Net.Http.dll` references `System.Net.Primitives` and friends.
    [Fact]
    public void The_scanner_detects_an_assembly_that_does_network()
    {
        var hits = NetworkReferenceScanner.Scan(typeof(HttpClient).Assembly.Location);
        Assert.NotEmpty(hits);
    }

    [Fact]
    public void Core_references_nothing_under_System_Net()
    {
        var hits = NetworkReferenceScanner.Scan(typeof(KeyboardConverter).Assembly.Location);
        Assert.True(hits.Count == 0, "Kibo.Core references networking:\n  " + string.Join("\n  ", hits));
    }

    /// Scans every path in `KIBO_APP_ASSEMBLY` (`;`-separated, each must exist) when it is set —
    /// that is the release gate. When it is not, probes the app's build output and scans whatever
    /// is there, skipping only if the app has not been built on this machine yet.
    [Fact]
    public void App_references_nothing_under_System_Net()
    {
        var paths = AppAssemblies();
        if (paths.Count == 0)
        {
            Assert.Skip("Build Windows/Kibo.App first; set KIBO_APP_ASSEMBLY to require it.");
        }
        foreach (var path in paths)
        {
            var hits = NetworkReferenceScanner.Scan(path);
            Assert.True(hits.Count == 0, $"{Path.GetFileName(path)} references networking:\n  " + string.Join("\n  ", hits));
        }
    }

    private static List<string> AppAssemblies()
    {
        var configured = Environment.GetEnvironmentVariable("KIBO_APP_ASSEMBLY");
        if (!string.IsNullOrEmpty(configured))
        {
            var paths = configured.Split(';', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries).ToList();
            foreach (var path in paths)
            {
                Assert.True(File.Exists(path), $"KIBO_APP_ASSEMBLY names a file that does not exist: {path}");
            }
            return paths;
        }

        var bin = Path.Combine(RepoPaths.Root, "Windows", "Kibo.App", "bin");
        if (!Directory.Exists(bin)) return [];
        return Directory.EnumerateFiles(bin, "*.dll", SearchOption.AllDirectories)
            .Where(p => Path.GetFileName(p) is "Kibo.dll" or "Kibo.Core.dll")
            .Where(p => !p.Split(Path.DirectorySeparatorChar).Contains("publish"))
            .ToList();
    }
}
