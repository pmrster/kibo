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
            // The mascot on its own, larger than the converter uses it, and fully risen — there is
            // nothing here for it to hide behind.
            // Larger pixels, not a scaled-up sprite — scaling is what made it look broken.
            KiboView(pixelSize: 5, isSpeaking: true)
                .padding(.top, 18)

            VStack(spacing: 4) {
                Text("Kibo")
                    .font(AppFont.title(22))
                    .foregroundStyle(Palette.text)
                // The name this app shipped under first, kept as the subtitle because it is what
                // says what the thing actually does.
                Text("Who Forgot To Change Lang")
                    .font(AppFont.ui(11, weight: .medium))
                    .foregroundStyle(Palette.dim)
                    .multilineTextAlignment(.center)
                Text("v\(version) · build \(build)")
                    .font(AppFont.ui(10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Palette.dim)
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)

            Text("Fixes text typed on the wrong keyboard layout, between Thai Kedmanee and US QWERTY.")
                .font(AppFont.thai(11))
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
