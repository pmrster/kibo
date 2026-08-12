import SwiftUI

/// The product's central promise, stated on the surface rather than buried in an About box.
/// Shown both on the converter itself and in the About window.
///
/// Kept in Thai: it is the reassurance the app's Thai audience actually reads, and unlike the
/// buttons around it, it is a claim rather than chrome.
struct PrivacyCapsule: View {
    var size: CGFloat = 9

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.shield.fill").font(AppFont.ui(size))
            Text("ทำงานบนเครื่องนี้ · ไม่ต่ออินเทอร์เน็ต")
                .font(AppFont.thai(size, weight: .semibold))
        }
        .foregroundStyle(Palette.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Palette.green.opacity(0.12), in: Capsule())
        .accessibilityElement()
        .accessibilityLabel("Runs on this Mac. Never connects to the internet.")
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
                .background(Palette.mango.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close window")
    }
}
