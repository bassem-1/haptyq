import SwiftUI
import HaptyqKit

struct GadgetView: View {
    @ObservedObject var model: AppModel

    private var caption: String {
        guard model.settings.enabled else { return "paused" }
        let active = Zone.allCases
            .map { ($0, model.settings[$0].feel) }
            .filter { $0.1 != .off }
            .max { $0.1 < $1.1 }
        guard let (zone, feel) = active else { return "all quiet" }
        return "\(zone.title) · \(feel.title)"
    }

    var body: some View {
        let on = model.settings.enabled
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(Theme.bg)
            RoundedRectangle(cornerRadius: 22).strokeBorder(Theme.line, lineWidth: 1)
            VStack(spacing: 8) {
                Text(on ? "on" : "off")
                    .font(Theme.font(22, .medium))
                    .foregroundColor(on ? Theme.fg : Theme.dim)
                PulseDot(pulses: model.pulses)
            }
            VStack {
                HStack {
                    Text("haptyq").font(Theme.font(11)).foregroundColor(Theme.fg2)
                    Spacer()
                }
                Spacer()
                HStack {
                    Text(caption)
                        .font(Theme.font(11))
                        .foregroundColor(Theme.fg2)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
            }
            .padding(14)
        }
        .frame(width: 140, height: 140)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("haptyq")
        .accessibilityValue(on ? "on" : "off")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { model.settings.enabled.toggle() }
    }
}
