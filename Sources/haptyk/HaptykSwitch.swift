import SwiftUI

/// Capsule switch, 34x18.
struct HaptykSwitch: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Button { isOn.toggle() } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule().fill(isOn ? Theme.fg : .clear)
                Capsule().strokeBorder(isOn ? Theme.fg : Theme.line, lineWidth: 1)
                Circle()
                    .fill(isOn ? Theme.bg : Theme.dim)
                    .frame(width: 12, height: 12)
                    .padding(3)
            }
            .frame(width: 34, height: 18)
            .animation(.easeOut(duration: 0.12), value: isOn)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .haptykFocus()
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "on" : "off")
        .modifier(ToggleTrait())
    }
}

/// Announce as a toggle where the trait exists (macOS 14+), else as a button.
private struct ToggleTrait: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 14, *) {
            content.accessibilityAddTraits(.isToggle)
        } else {
            content.accessibilityAddTraits(.isButton)
        }
    }
}
