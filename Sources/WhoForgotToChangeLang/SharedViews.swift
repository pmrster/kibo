import SwiftUI

/// The product's central promise, stated on the surface rather than buried in an About box.
/// Shown both on the converter itself and in the About window.
struct PrivacyCapsule: View {
    var size: CGFloat = 9

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.shield.fill").font(.system(size: scaled(size)))
            Text("ทำงานบนเครื่องนี้ · ไม่ต่ออินเทอร์เน็ต")
                .font(.system(size: scaled(size), weight: .semibold))
        }
        .foregroundStyle(Palette.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Palette.green.opacity(0.12), in: Capsule())
        .accessibilityElement()
        .accessibilityLabel("แปลงข้อความบนเครื่องนี้ ไม่ส่งข้อมูลออกอินเทอร์เน็ต")
    }
}

/// The dismiss button shared by the About and Settings panels.
struct PanelCloseButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("ปิด")
                .font(.system(size: scaled(12), weight: .semibold))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 22)
                .padding(.vertical, 7)
                .background(Palette.mango.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("ปิดหน้าต่าง")
    }
}
