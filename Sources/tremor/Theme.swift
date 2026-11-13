import Combine
import SwiftUI

/// Two colors only: black and #E4FF1A at fixed opacities. Nothing else is allowed in the ui.
enum Theme {
    static let yellowNS = NSColor(srgbRed: 228 / 255, green: 1, blue: 26 / 255, alpha: 1)
    static let bg = Color.black
    static let fg = Color(nsColor: yellowNS)
    static let fg2 = fg.opacity(0.55)   // secondary text
    static let dim = fg.opacity(0.32)   // disabled
    static let line = fg.opacity(0.16)  // hairlines, borders
    static let wash = fg.opacity(0.08)  // hover, pressed

    static let pad: CGFloat = 16
    static let row: CGFloat = 32
    static let gap: CGFloat = 16
    static let radius: CGFloat = 10
    static let controlRadius: CGFloat = 6

    static func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension View {
    /// System focus rings use the accent color, so turn them off where we can.
    @ViewBuilder func tremorFocus() -> some View {
        if #available(macOS 14, *) {
            self.focusEffectDisabled()
        } else {
            self
        }
    }
}

/// Plain text button with a hover/pressed wash. Hover only changes the background, never the layout.
struct TextButton: View {
    let title: String
    var size: CGFloat = 13
    var color: Color = Theme.fg
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.font(size))
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: Theme.controlRadius).fill(hover ? Theme.wash : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .tremorFocus()
        .onHover { hover = $0 }
        .accessibilityLabel(title)
    }
}

/// Dot that flashes when a haptic fires: opacity 1 -> 0.16 over 180ms.
struct PulseDot: View {
    let pulses: PassthroughSubject<Void, Never>
    var size: CGFloat = 6
    @State private var opacity = 0.16

    var body: some View {
        Circle()
            .fill(Theme.fg)
            .frame(width: size, height: size)
            .opacity(opacity)
            .onReceive(pulses) { _ in flash() }
            .accessibilityHidden(true)
    }

    private func flash() {
        var t = Transaction()
        t.disablesAnimations = true
        withTransaction(t) { opacity = 1 }
        Task { @MainActor in
            withAnimation(.linear(duration: 0.18)) { opacity = 0.16 }
        }
    }
}
