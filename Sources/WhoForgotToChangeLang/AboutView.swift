import SwiftUI

/// The About window's contents. Reads its version from the real Info.plist in the packaged
/// `.app`, falling back to "dev" when running unbundled via `swift run`.
struct AboutView: View {
    private var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
    private var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 0) {
            Image(nsImage: MenuBarIcon.image(pixelSize: 5))
                .renderingMode(.template)
                .foregroundStyle(Palette.mango)
                .padding(.top, 22)

            VStack(spacing: 6) {
                Text("ใครลืมเปลี่ยนภาษา")
                    .font(.system(size: scaled(19), weight: .heavy, design: .rounded))
                    .foregroundStyle(Palette.text)
                Text("v\(version) · build \(build)")
                    .font(.system(size: scaled(10), weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.dim)
            }
            .padding(.top, 12)

            Text("แปลงข้อความที่พิมพ์ผิดแป้นระหว่างไทย (เกษมณี) กับอังกฤษ (QWERTY)")
                .font(.system(size: scaled(11)))
                .foregroundStyle(Palette.dim)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 26)
                .padding(.top, 12)

            PrivacyCapsule(size: 10)
                .padding(.top, 14)

            Spacer(minLength: 12)

            PanelCloseButton { Panels.about.close() }
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.panel)
    }
}
