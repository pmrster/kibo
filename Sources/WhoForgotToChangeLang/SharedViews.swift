import SwiftUI

/// The product's central promise, stated on the surface rather than buried in an About box.
/// Shown both on the converter itself and in the About window.
///
/// Phrased the same way as Tama's badge, since the two apps make the same promise and a user who
/// runs both should recognise it at a glance.
struct PrivacyCapsule: View {
    var size: CGFloat = 9

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.shield.fill").font(AppFont.ui(size))
            Text("Local-only · No network")
                .font(AppFont.ui(size, weight: .semibold))
        }
        .foregroundStyle(Palette.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Palette.green.opacity(0.12), in: Capsule())
        .accessibilityElement()
        .accessibilityLabel("Runs entirely on this Mac. Never connects to the internet.")
    }
}

/// The dismiss button shared by the About and Settings panels.
struct PanelCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Close")
                .font(AppFont.ui(12, weight: .semibold))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 22)
                .padding(.vertical, 7)
                .background(Palette.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close window")
    }
}
