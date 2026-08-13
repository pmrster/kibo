import SwiftUI

/// The product's central promise, stated on the surface rather than buried in an About box.
/// Shown both on the converter itself and in the About window.
///
/// Phrased the same way as Tama's badge, since the two apps make the same promise and a user who
/// runs both should recognise it at a glance.
struct PrivacyCapsule: View {
    var size: CGFloat = 9

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "lock.shield.fill").font(AppFont.ui(size))
            Text("Local-only · No network")
                .font(AppFont.ui(size, weight: .semibold))
        }
        .foregroundStyle(Palette.green)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Palette.green.opacity(0.12), in: Capsule())
        .accessibilityElement()
        .accessibilityLabel("Runs entirely on this Mac. Never connects to the internet.")
    }
}

/// A segmented control the app paints itself, used everywhere a segmented `Picker` would be.
///
/// **Do not replace this with `.pickerStyle(.segmented)`.** AppKit paints a segmented picker's
/// selection with the *system* accent colour — whatever the user set in System Settings — so on a
/// Mac with a yellow accent the selection came out bright yellow and wrecked a deliberately
/// near-monochrome palette. macOS offers no supported override. This also renders under
/// `--snapshot`, which the AppKit-backed picker never did, so these surfaces can be design-reviewed.
///
/// Selection is reported through `onSelect` rather than a `Binding`, because the two call sites
/// keep their state in different places — an `@Observable` model and an `ObservableObject` — and a
/// closure fits both without either having to grow a binding it does not otherwise need.
struct ThemedSegmentedControl<Value: Hashable>: View {
    let options: [Value]
    let selection: Value
    let label: (Value) -> String
    let accessibilityTitle: String
    /// ⌘1–⌘4 on the converter's mode picker, where the keyboard matters. Off elsewhere, so
    /// Settings does not silently claim shortcuts the converter is already using.
    var numberKeyShortcuts = false
    /// What the segment does, for the tooltip, when the label is too short to say it. Falls back
    /// to the label — Settings' options explain themselves, the conversion modes do not.
    var help: ((Value) -> String)?
    let onSelect: (Value) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                segment(option, index: index)
            }
        }
        .padding(2)
        .background(Palette.fieldFill, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityTitle)
    }

    /// The shortcut is appended rather than built into the description, so the description stays
    /// one translatable sentence and the key stays readable at the end of it.
    private func tooltip(for option: Value, title: String, index: Int) -> String {
        let description = help?(option) ?? title
        return numberKeyShortcuts ? "\(description) (⌘\(index + 1))" : description
    }

    @ViewBuilder
    private func segment(_ option: Value, index: Int) -> some View {
        let isSelected = option == selection
        let title = label(option)
        Button {
            onSelect(option)
        } label: {
            Text(title)
                .font(AppFont.ui(11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Palette.panel : Palette.text)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(isSelected ? Palette.accent : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6))
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .modifier(NumberKeyShortcut(index: index, enabled: numberKeyShortcuts))
        .help(tooltip(for: option, title: title, index: index))
        .accessibilityLabel(title)
        .accessibilityHint(help?(option) ?? "")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

/// `.keyboardShortcut` has no "no shortcut" value, so the choice has to be made structurally.
private struct NumberKeyShortcut: ViewModifier {
    let index: Int
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled, index < 9 {
            content.keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
        } else {
            content
        }
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
                .background(Palette.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close window")
    }
}
