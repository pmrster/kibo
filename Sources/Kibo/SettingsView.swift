import SwiftUI
import KiboCore

/// Appearance and text-size pickers, themed like the rest of the app. Observes
/// `AppSettings.shared`, so picking a value updates this window and everything else at once.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 8) {
                KiboView()
                Text("Settings")
                    .font(AppFont.title(17))
                    .foregroundStyle(Palette.text)
            }

            section("APPEARANCE") {
                ThemedSegmentedControl(options: Appearance.allCases,
                                       selection: settings.appearance,
                                       label: Self.label(for:),
                                       accessibilityTitle: "Appearance") {
                    settings.appearance = $0
                }
            }

            section("TEXT SIZE") {
                ThemedSegmentedControl(options: FontSize.allCases,
                                       selection: settings.fontSize,
                                       label: Self.label(for:),
                                       accessibilityTitle: "Text size") {
                    settings.fontSize = $0
                }
            }

            // Shows the Thai face at the chosen size, since that is what the text-size setting is
            // really for — the vowel and tone marks are the hard part to read.
            section("PREVIEW") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("l;ylfu ้ำสสน ครับ")
                        .font(AppFont.thai(11))
                        .foregroundStyle(Palette.dim)
                    Text("สวัสดี hello ครับ")
                        .font(AppFont.thai(13))
                        .foregroundStyle(Palette.text)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.fieldFill, in: RoundedRectangle(cornerRadius: 8))
            }

            Spacer(minLength: 4)

            HStack {
                Spacer()
                PanelCloseButton { Panels.settings.close() }
                Spacer()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Palette.panel)
    }

    private static func label(for appearance: Appearance) -> String {
        switch appearance {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    private static func label(for size: FontSize) -> String {
        switch size {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppFont.ui(10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Palette.dim)
            content()
        }
    }
}
