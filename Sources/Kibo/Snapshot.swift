#if KIBO_SNAPSHOT
import AppKit
import SwiftUI
import KiboCore

/// Renders the app's surfaces to PNGs without a display, for design review and README shots.
///
/// Opt-in behind the `KIBO_SNAPSHOT` compile flag, so it is absent from normal debug builds AND
/// release builds — a plain clone and the shipped DMG cannot run it:
///
///     swift run -Xswiftc -DKIBO_SNAPSHOT Kibo --snapshot [dir]
///
/// Exists because screen capture needs a permission a terminal often does not have, which makes
/// "does this actually look right?" otherwise unanswerable without a human at the keyboard.
@MainActor
enum Snapshot {

    static func renderIfRequested() {
        let arguments = CommandLine.arguments
        guard let flagIndex = arguments.firstIndex(of: "--snapshot") else { return }
        let directory = arguments.count > flagIndex + 1 ? arguments[flagIndex + 1] : "./assets"
        render(into: URL(fileURLWithPath: directory))
        NSApp.terminate(nil)
    }

    private static func render(into directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for (name, appearance) in [("light", NSAppearance(named: .aqua)!),
                                   ("dark", NSAppearance(named: .darkAqua)!)] {
            NSApp.appearance = appearance
            // `Palette` colors come from an NSColor dynamic provider, which resolves against the
            // *drawing* appearance. ImageRenderer does not inherit that from NSApp, and
            // `performAsCurrentDrawingAppearance` does not reach inside its render pass either —
            // so the deprecated setter is the one that actually works here. Confined to this
            // dev-only file.
            let previous = NSAppearance.current
            NSAppearance.current = appearance
            defer { NSAppearance.current = previous }

            // The default mode, so review sees what a new user opens into — and because its badge
            // is the longest of the four, making this the snapshot that catches overflow.
            let model = ConverterModel(mode: .default, clipboard: SystemClipboard())
            model.input = "l;ylfu ้ำสสน ครับ 2024 :)"

            write(ConverterView(model: model).environment(\.colorScheme,
                                                          name == "dark" ? .dark : .light),
                  to: directory, "converter-\(name)")
            // Empty as well as filled: the mascot only peeks when there is no result, so a
            // filled-only snapshot never shows the state most users see first.
            let empty = ConverterModel(mode: .default, clipboard: SystemClipboard())
            write(ConverterView(model: empty).environment(\.colorScheme,
                                                          name == "dark" ? .dark : .light),
                  to: directory, "converter-empty-\(name)")
            write(AboutView().frame(width: 320, height: 360)
                    .environment(\.colorScheme, name == "dark" ? .dark : .light),
                  to: directory, "about-\(name)")
            write(SettingsView().frame(width: 320, height: 400)
                    .environment(\.colorScheme, name == "dark" ? .dark : .light),
                  to: directory, "settings-\(name)")
            write(mascotSheet.environment(\.colorScheme, name == "dark" ? .dark : .light),
                  to: directory, "mascot-\(name)")
        }
        print("Wrote snapshots to \(directory.path)")
    }

    /// The mascot's moods, blown up so the pixel art can actually be judged, plus the status-item
    /// glyph at true menu-bar size. At the size these appear in the app, a sprite that reads as a
    /// blob and one that reads as a ghost look identical on a screenshot.
    private static var mascotSheet: some View {
        HStack(spacing: 66) {
            ForEach(["idle", "pleased"], id: \.self) { label in
                VStack(spacing: 14) {
                    KiboView(mood: label == "idle" ? .idle : .pleased, pixelSize: 6,
                             isSpeaking: label == "pleased")
                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Palette.dim)
                }
            }
            VStack(spacing: 14) {
                KiboView(pixelSize: 2)
                Text("native")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.dim)
            }
            VStack(spacing: 14) {
                Image(nsImage: MenuBarIcon.image())
                    .renderingMode(.template)
                    .foregroundStyle(Palette.text)
                Text("menu bar")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.dim)
            }
        }
        .padding(28)
        .background(Palette.panel)
    }

    private static func write(_ view: some View, to directory: URL, _ name: String) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:])
        else {
            print("FAILED to render \(name)")
            return
        }
        let url = directory.appendingPathComponent("\(name).png")
        try? png.write(to: url)
        print("  \(url.lastPathComponent)  \(Int(image.size.width))x\(Int(image.size.height))")
    }
}
#endif
