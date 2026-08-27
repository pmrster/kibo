using System.Reflection;
using Kibo.App.Controls;
using Kibo.App.Theme;

namespace Kibo.App.Views;

/// <summary>The About panel — the port of <c>AboutView.swift</c>.</summary>
internal sealed class AboutWindow : PanelWindow
{
    public AboutWindow() : base("About", 320, 360)
    {
        var stack = new StackPanel { HorizontalAlignment = HorizontalAlignment.Center };

        var mascot = new KiboSpriteControl { PixelSize = 5, Mood = KiboSpriteControl.MoodKind.Pleased, Margin = new Thickness(0, 18, 0, 0), HorizontalAlignment = HorizontalAlignment.Center };
        stack.Children.Add(mascot);

        stack.Children.Add(Centered("Kibo", "Font.AboutTitle", "Brush.Text", AppFonts.Ui, FontWeights.SemiBold, new Thickness(0, 12, 0, 0)));
        stack.Children.Add(Centered("Who Forgot To Change Lang", "Font.AboutSubtitle", "Brush.Dim", AppFonts.Ui, FontWeights.Medium, new Thickness(0, 2, 0, 0)));

        var (version, build) = VersionAndBuild();
        stack.Children.Add(Centered($"v{version} · build {build}", "Font.AboutVersion", "Brush.Dim", AppFonts.Mono, FontWeights.Medium, new Thickness(0, 2, 0, 0)));

        var description = Centered(
            "Fixes text typed on the wrong keyboard layout, between Thai Kedmanee and US QWERTY.",
            "Font.AboutSubtitle", "Brush.Dim", AppFonts.Thai, FontWeights.Normal, new Thickness(26, 12, 26, 0));
        description.TextWrapping = TextWrapping.Wrap;
        stack.Children.Add(description);

        stack.Children.Add(new PrivacyCapsule(10) { HorizontalAlignment = HorizontalAlignment.Center, Margin = new Thickness(0, 14, 0, 0) });

        var close = CloseButton();
        close.Margin = new Thickness(0, 20, 0, 18);
        stack.Children.Add(close);

        Content = stack;
    }

    private static TextBlock Centered(string text, string sizeKey, string brushKey, FontFamily family, FontWeight weight, Thickness margin)
    {
        var block = new TextBlock
        {
            Text = text,
            FontFamily = family,
            FontWeight = weight,
            TextAlignment = TextAlignment.Center,
            HorizontalAlignment = HorizontalAlignment.Center,
            Margin = margin,
        };
        block.SetResourceReference(TextBlock.FontSizeProperty, sizeKey);
        block.SetResourceReference(TextBlock.ForegroundProperty, brushKey);
        return block;
    }

    /// <summary>
    /// From the informational version <c>package.ps1</c> injects — <c>0.4.0+build.123</c>. No
    /// attribute (a plain `dotnet run`) shows <c>dev</c> / <c>—</c>, as About does on macOS.
    /// </summary>
    private static (string Version, string Build) VersionAndBuild()
    {
        var informational = Assembly.GetEntryAssembly()?
            .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?.InformationalVersion;
        if (string.IsNullOrEmpty(informational) || informational.StartsWith("0.0.0", StringComparison.Ordinal))
        {
            return ("dev", "—");
        }
        var plus = informational.IndexOf('+');
        if (plus < 0) return (informational, "—");
        var version = informational[..plus];
        var suffix = informational[(plus + 1)..];
        var build = suffix.StartsWith("build.", StringComparison.Ordinal) ? suffix["build.".Length..] : "—";
        return (version, build);
    }
}
