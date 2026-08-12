import SwiftUI
import WhoForgotToChangeLangCore

/// Appearance and text-size pickers, themed like the rest of the app. Observes
/// `AppSettings.shared`, so picking a value updates this window and everything else at once.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 8) {
                GhostView(mood: .risen)
                Text("Settings")
                    .font(AppFont.title(17))
                    .foregroundStyle(Palette.text)
            }

            section("APPEARANCE") {
                Picker("", selection: $settings.appearance) {
                    Text("System").tag(Appearance.system)
                    Text("Light").tag(Appearance.light)
                    Text("Dark").tag(Appearance.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Appearance")
            }

            section("TEXT SIZE") {
                Picker("", selection: $settings.fontSize) {
                    Text("S").tag(FontSize.small)
                    Text("M").tag(FontSize.medium)
                    Text("L").tag(FontSize.large)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Text size")
            }

            // Shows the Thai face at the chosen size, since that is what the text-size setting is
            // really for — the vowel and tone marks are the hard part to read.
            section("PREVIEW") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("l;ylfu ไำะ ครับ")
                        .font(AppFont.thai(11))
                        .foregroundStyle(Palette.dim)
                    Text("สวัสดี wet ครับ")
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
