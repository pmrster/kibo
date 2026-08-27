using System.Reflection.Metadata;
using System.Reflection.PortableExecutable;

namespace Kibo.Core.Tests;

/// Reads an assembly's metadata tables — no loading, no execution — and lists every reference to
/// the networking parts of the runtime. Empty means the assembly cannot open a socket without
/// first being rebuilt.
internal static class NetworkReferenceScanner
{
    private static readonly string[] ForbiddenAssemblyPrefixes = ["System.Net"];

    private static readonly string[] ForbiddenNamespacePrefixes =
        ["System.Net", "Windows.Networking", "Windows.Web"];

    /// `WebBrowser` lives in `System.Windows.Controls`, so a namespace check misses it.
    private static readonly string[] ForbiddenTypeNames = ["WebBrowser"];

    public static IReadOnlyList<string> Scan(string assemblyPath)
    {
        var hits = new List<string>();
        using var stream = File.OpenRead(assemblyPath);
        using var reader = new PEReader(stream);
        var metadata = reader.GetMetadataReader();

        foreach (var handle in metadata.AssemblyReferences)
        {
            var name = metadata.GetString(metadata.GetAssemblyReference(handle).Name);
            if (ForbiddenAssemblyPrefixes.Any(p => name.StartsWith(p, StringComparison.Ordinal)))
            {
                hits.Add($"assembly reference: {name}");
            }
        }

        foreach (var handle in metadata.TypeReferences)
        {
            var type = metadata.GetTypeReference(handle);
            var ns = metadata.GetString(type.Namespace);
            var name = metadata.GetString(type.Name);
            if (ForbiddenNamespacePrefixes.Any(p => ns.StartsWith(p, StringComparison.Ordinal))
                || ForbiddenTypeNames.Contains(name, StringComparer.Ordinal))
            {
                hits.Add($"type reference: {ns}.{name}");
            }
        }

        return hits;
    }
}
