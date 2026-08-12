import SwiftUI
import WhoForgotToChangeLangCore

/// Appearance and text-size pickers, themed like the rest of the app. Observes
/// `AppSettings.shared`, so picking a value updates this window and everything else at once.
struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("ตั้งค่า")
                .font(.system(size: scaled(17), weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.text)

            section("ธีม") {
                Picker("", selection: $settings.appearance) {
                    Text("ตามระบบ").tag(Appearance.system)
                    Text("สว่าง").tag(Appearance.light)
                    Text("มืด").tag(Appearance.dark)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("ธีมของแอป")
            }

            section("ขนาดตัวอักษร") {
                Picker("", selection: $settings.fontSize) {
                    Text("เล็ก").tag(FontSize.small)
                    Text("กลาง").tag(FontSize.medium)
                    Text("ใหญ่").tag(FontSize.large)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("ขนาดตัวอักษร")
            }

            section("ตัวอย่าง") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("l;ylfu ไำะ ครับ")
                        .font(.system(size: scaled(11), design: .monospaced))
                        .foregroundStyle(Palette.dim)
                    Text("สวัสดี wet ครับ")
                        .font(.system(size: scaled(13)))
                        .foregroundStyle(Palette.text)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Palette.panelEdge.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
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
                .font(.system(size: scaled(10), weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Palette.dim)
            content()
        }
    }
}
