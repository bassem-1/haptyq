import SwiftUI
import HaptyqKit

/// Zone list plus the selected zone's controls. Every row is always present so nothing jumps.
struct Inspector: View {
    @ObservedObject var model: AppModel

    private var zone: Zone { model.selected }
    private var setting: Binding<ZoneSetting> { model.binding(for: model.selected) }
    private var active: Bool { setting.wrappedValue.feel != .off }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Zone.allCases) { z in zoneRow(z) }
            Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 8)
            controlRow("rhythm") {
                SignalBar(feel: setting.feel, label: "\(zone.title) rhythm")
            }
            controlRow("reach") {
                HStack(spacing: 8) {
                    ReachSlider(value: setting.radius, range: ZoneSetting.radiusRange, label: "\(zone.title) reach")
                    Text("\(Int(setting.wrappedValue.radius)) pt")
                        .font(Theme.font(11)).foregroundColor(Theme.fg2)
                        .frame(width: 48, alignment: .trailing)
                }
            }
            .opacity(zone.allowsRadius && active ? 1 : 0.32)
            .disabled(!(zone.allowsRadius && active))
            controlRow("strength") {
                StrengthBar(strength: setting.strength, label: "\(zone.title) strength")
            }
            .opacity(active ? 1 : 0.32)
            .disabled(!active)
            controlRow("confirm click") {
                HaptyqSwitch(isOn: setting.confirmClick, label: "\(zone.title) confirm click")
            }
            .opacity(zone.usesProximity && active ? 1 : 0.32)
            .disabled(!(zone.usesProximity && active))
            HStack {
                TextButton(title: "feel it") { model.preview(zone) }.padding(.leading, -6)
                Spacer()
            }
            .frame(height: Theme.row)
        }
    }

    private func zoneRow(_ z: Zone) -> some View {
        let selected = z == zone
        return HStack(spacing: 0) {
            Text(z.title)
                .font(Theme.font(13, selected ? .medium : .regular))
                .foregroundColor(Theme.fg)
                .frame(maxWidth: .infinity, alignment: .leading)
            SignalBar(feel: model.binding(for: z).feel, label: "\(z.title) feel")
        }
        .frame(height: Theme.row)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: Theme.controlRadius).fill(selected ? Theme.wash : .clear))
        .padding(.horizontal, -8)
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { model.selected = z })
        .accessibilityElement(children: .contain)
        .accessibilityLabel(z.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func controlRow<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack(spacing: 0) {
            Text(title).font(Theme.font(11)).foregroundColor(Theme.fg2).frame(width: 88, alignment: .leading)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: Theme.row)
    }
}
