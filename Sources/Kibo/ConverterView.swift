import SwiftUI
import KiboCore

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

    private var mascotMood: KiboView.Mood {
        model.didCopy ? .pleased : .idle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            modeRow
            field(title: "INPUT", accessory: { ghost }) { inputEditor }
            field(title: "RESULT", accessory: { directionBadge }) { outputPanel }
            actionRow
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

    /// Perches on the top edge of the field below. The field is drawn after this row and is
    /// opaque, so it paints over the overlap — which tucks the tails behind the edge instead of
    /// leaving the ghost floating above it.
    private var ghost: some View {
        KiboView(mood: mascotMood, isSpeaking: model.didCopy)
            .padding(.bottom, -KiboView.tailTuck())
            // Inset from the field's rounded corner, which it otherwise overhangs.
            .padding(.trailing, 14)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 7) {
            Text("Kibo")
                .font(AppFont.title(15))
                .foregroundStyle(Palette.text)
                .lineLimit(1)
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
            modePicker
            Button(action: model.swapDirection) {
                Image(systemName: "arrow.left.arrow.right")
                    .font(AppFont.ui(11, weight: .semibold))
                    .foregroundStyle(model.mode == .mixed ? Palette.dim.opacity(0.4) : Palette.accent)
            }
            .buttonStyle(.plain)
            // Mixed has no opposite direction, so there is nothing to swap.
            .disabled(model.mode == .mixed)
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .help(model.mode == .mixed ? "Mixed has no direction to swap" : "Swap direction (⇧⌘S)")
            .accessibilityLabel("Swap direction")
        }
    }

    /// Hand-rolled rather than a segmented `Picker`.
    ///
    /// A segmented picker paints its selection with the *system* accent colour — whatever the
    /// user has set in System Settings — so on a Mac with a yellow accent the selected mode came
    /// out bright yellow, wrecking a deliberately near-monochrome palette. There is no supported
    /// way to override that on macOS. Twenty lines of buttons buys the theme back.
    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(Array(ConversionMode.allCases.enumerated()), id: \.element) { index, mode in
                let isSelected = model.mode == mode
                Button {
                    model.mode = mode
                } label: {
                    Text(Self.label(for: mode))
                        .font(AppFont.ui(11, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Palette.panel : Palette.text)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(isSelected ? Palette.accent : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 6))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                .help("\(Self.label(for: mode)) (⌘\(index + 1))")
                .accessibilityLabel(Self.label(for: mode))
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(Palette.fieldFill, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Conversion mode")
        .onChange(of: model.mode) { _, newMode in settings.lastMode = newMode }
    }

    private static func label(for mode: ConversionMode) -> String {
        switch mode {
        case .mixed: return "Mixed"
        case .englishToThai: return "EN → TH"
        case .thaiToEnglish: return "TH → EN"
        }
    }

    /// A quiet reminder of what the result field is showing.
    @ViewBuilder private var directionBadge: some View {
        switch model.mode {
        case .mixed:
            badge("only what looks mistyped", tint: Palette.dim)
        case .englishToThai:
            badge("EN → TH", tint: Palette.dim)
        case .thaiToEnglish:
            badge("TH → EN", tint: Palette.dim)
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .bottom, spacing: 6) {
                Text(title)
                    .font(AppFont.ui(10, weight: .heavy))
                    .tracking(0.8)
                    .foregroundStyle(Palette.dim)
                    .padding(.bottom, 4)
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
            .background(Palette.fieldFill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(inputFocused ? Palette.accent : Color.clear, lineWidth: 1.5)
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
        .background(Palette.fieldFill, in: RoundedRectangle(cornerRadius: 8))
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
                .foregroundStyle(model.didCopy ? Palette.green : Palette.accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background((model.didCopy ? Palette.green : Palette.accent).opacity(0.15),
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

}
