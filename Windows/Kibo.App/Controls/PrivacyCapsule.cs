
namespace Kibo.App.Controls;

/// <summary>
/// The green "Local-only · No network" badge from <c>SharedViews.swift</c> — the one place, with
/// the copy confirmation, that any colour but the near-monochrome accent appears.
/// </summary>
internal sealed class PrivacyCapsule : Border
{
    public PrivacyCapsule() : this(9) { }

    public PrivacyCapsule(double size)
    {
        var text = new TextBlock
        {
            Text = "Local-only · No network",
            FontWeight = FontWeights.SemiBold,
            FontSize = size,
            VerticalAlignment = VerticalAlignment.Center,
        };
        text.SetResourceReference(TextBlock.ForegroundProperty, "Brush.Green");

        CornerRadius = new CornerRadius(999);
        Padding = new Thickness(8, 4, 8, 4);
        HorizontalAlignment = HorizontalAlignment.Left;
        Child = text;
        SetResourceReference(BackgroundProperty, "Brush.Green12");
        AutomationProperties.SetName(this, "Runs entirely on this PC. Never connects to the internet.");
    }
}
