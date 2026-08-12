import SwiftUI
import WhoForgotToChangeLangCore

/// The converter surface, hosted in both the menu-bar popover and the pinned panel.
///
/// Deliberately one screen with no navigation: the whole point is paste → read → copy without
/// breaking away from whatever you were doing. Every control is reachable by keyboard and
/// carries a VoiceOver label.
///
/// Chrome is English; Thai appears only where it is content — the conversion examples, the
/// privacy line, and of course the text being converted. Those use `AppFont.thai`, because the
/// system font's Thai face crowds vowel and tone marks at these sizes, and reading those marks is
/// exactly what this app asks of people.
struct ConverterView: View {
    @Bindable var model: ConverterModel
    @ObservedObject private var settings = AppSettings.shared
    @FocusState private var inputFocused: Bool

    /// `nil` in the pinned panel, which is resizable; fixed in the popover, which is not.
    var fixedWidth: CGFloat? = 360

    private var mascotMood: CatView.Mood {
        if model.didCopy { return .happy }
        return model.output.isEmpty ? .idle : .alert
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            modeRow
            field(title: "INPUT", accessory: { EmptyView() }) { inputEditor }
            field(title: "RESULT", accessory: { directionBadge }) { outputPanel }
            actionRow
            examples
            PrivacyCapsule()
        }
        .padding(14)
        .frame(width: fixedWidth, alignment: .leading)
        .frame(maxHeight: fixedWidth == nil ? .infinity : nil, alignment: .top)
        .background(Palette.panel)
        .onAppear { inputFocused = true }
        // Retract the Copy confirmation on a timer. Keyed on `didCopy`, so a second Copy restarts
        // the countdown rather than inheriting the first one's remaining time.
        .task(id: model.didCopy) {
            guard model.didCopy else { return }
            try? await Task.sleep(for: .seconds(1.6))
            model.dismissCopyConfirmation()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 7) {
            CatView(mood: mascotMood, mode: model.mode)
            Text("Who Forgot To Change Lang")
                .font(AppFont.ui(13, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 2)
            Button { Panels.pinned?.toggle() } label: {
                Image(systemName: "pin")
                    .font(AppFont.ui(11, weight: .semibold))
                    .foregroundStyle(Palette.dim)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .help("Float above other apps, so it stays open while you paste (⇧⌘P)")
            .accessibilityLabel("Pin as floating window")
        }
    }

    // MARK: - Mode

    private var modeRow: some View {
        HStack(spacing: 8) {
            Picker("", selection: $model.mode) {
                Text("Mixed").tag(ConversionMode.mixed)
                Text("EN → TH").tag(ConversionMode.englishToThai)
                Text("TH → EN").tag(ConversionMode.thaiToEnglish)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .font(AppFont.ui(11))
            .accessibilityLabel("Conversion mode")
            .onChange(of: model.mode) { _, newMode in settings.lastMode = newMode }

            Button(action: model.swapDirection) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(AppFont.ui(11, weight: .semibold))
                    .foregroundStyle(model.mode == .mixed ? Palette.dim.opacity(0.4) : Palette.mango)
            }
            .buttonStyle(.plain)
            // Mixed has no opposite direction, so there is nothing to swap.
            .disabled(model.mode == .mixed)
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .help(model.mode == .mixed ? "Mixed has no direction to swap" : "Swap direction (⇧⌘S)")
            .accessibilityLabel("Swap direction")
        }
    }

    /// A quiet reminder of what the result field is showing, tinted per script.
    @ViewBuilder private var directionBadge: some View {
        switch model.mode {
        case .mixed:
            badge("only what looks mistyped", tint: Palette.dim)
        case .englishToThai:
            badge("EN → TH", tint: Palette.thai)
        case .thaiToEnglish:
            badge("TH → EN", tint: Palette.latin)
        }
    }

    private func badge(_ label: String, tint: Color) -> some View {
        Text(label)
            .font(AppFont.ui(9, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.12), in: Capsule())
    }

    // MARK: - Fields

    private func field(title: String,
                       @ViewBuilder accessory: () -> some View,
                       @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(title)
                    .font(AppFont.ui(10, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Palette.dim)
                Spacer(minLength: 4)
                accessory()
            }
            content()
        }
    }

    private var inputEditor: some View {
        TextEditor(text: $model.input)
            .font(AppFont.thai(13))
            .foregroundStyle(Palette.text)
            .scrollContentBackground(.hidden)
            .focused($inputFocused)
            .frame(height: scaled(64))
            .padding(6)
            .background(Palette.panelEdge.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(inputFocused ? Palette.mango : Color.clear, lineWidth: 1.5)
            )
            .accessibilityLabel("Text you typed")
    }

    private var outputPanel: some View {
        ScrollView {
            Text(model.output.isEmpty ? "The corrected text appears here" : model.output)
                .font(AppFont.thai(13))
                .foregroundStyle(model.output.isEmpty ? Palette.dim : Palette.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: scaled(64))
        .padding(6)
        .background(Palette.panelEdge.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .accessibilityLabel("Result")
        .accessibilityValue(model.output.isEmpty ? "No result yet" : model.output)
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 8) {
            // Every action carries a shortcut so the whole flow works without a mouse. The input
            // is a TextEditor, which swallows Tab, so shortcuts — not focus traversal — are what
            // make that true.
            secondaryButton("Paste", systemImage: "doc.on.clipboard", action: model.paste)
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .help("Reads the clipboard only when you press this (⇧⌘V)")
            secondaryButton("Clear", systemImage: "xmark.circle", action: model.clear)
                .disabled(model.input.isEmpty)
                .keyboardShortcut("k", modifiers: [.command, .shift])
                .help("Clear the input (⇧⌘K)")

            Spacer(minLength: 4)

            Button(action: model.copyOutput) {
                HStack(spacing: 5) {
                    Image(systemName: model.didCopy ? "checkmark" : "doc.on.doc")
                    Text(model.didCopy ? "Copied" : "Copy")
                }
                .font(AppFont.ui(12, weight: .semibold))
                .foregroundStyle(model.didCopy ? Palette.green : Palette.mango)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background((model.didCopy ? Palette.green : Palette.mango).opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(model.output.isEmpty)
            .keyboardShortcut("c", modifiers: [.command, .shift])
            .help("Copy the result (⇧⌘C)")
            .accessibilityLabel(model.didCopy ? "Copied" : "Copy result")
        }
    }

    private func secondaryButton(_ title: String,
                                 systemImage: String,
                                 action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                Text(title)
            }
            .font(AppFont.ui(11, weight: .medium))
            .foregroundStyle(Palette.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Palette.panelEdge.opacity(0.7), in: RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    // MARK: - Examples

    private static let presets: [(label: String, input: String, mode: ConversionMode)] = [
        ("l;ylfu ไำะ ครับ", "l;ylfu ไำะ ครับ 2024 :)", .mixed),
        ("vpkddbodkca", "vpkddbodkca", .englishToThai),
        ("ะ้ฟืา", "ะ้ฟืา", .thaiToEnglish),
    ]

    private var examples: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("TRY ONE")
                .font(AppFont.ui(10, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Palette.dim)
            HStack(spacing: 6) {
                ForEach(Self.presets, id: \.label) { preset in
                    Button {
                        model.mode = preset.mode
                        model.input = preset.input
                        settings.lastMode = preset.mode
                    } label: {
                        Text(preset.label)
                            .font(AppFont.thai(10))
                            .foregroundStyle(Palette.dim)
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Palette.track.opacity(0.5), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Example: \(preset.label)")
                }
            }
        }
    }
}
