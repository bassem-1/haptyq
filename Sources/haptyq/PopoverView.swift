import SwiftUI
import HaptyqKit

struct PopoverView: View {
    @ObservedObject var model: AppModel
    @State private var expanded: Zone?
    @State private var hovered: Zone?
    @State private var grantClicked = false

    private var enabled: Bool { model.settings.enabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Spacer().frame(height: Theme.gap)
            if !model.hardwareAvailable { hardwareBanner }
            if !model.trusted {
                permissionBanner
            } else {
                zoneList
            }
            caption
            divider
            VStack(spacing: 0) {
                toggleRow("desktop gadget", $model.settings.showGadget)
                toggleRow("gadget floats above windows", $model.settings.gadgetFloats)
                toggleRow("launch at login", Binding(get: { model.launchAtLogin },
                                                     set: { model.setLaunchAtLogin($0) }))
            }
            divider
            footer
        }
        .padding(Theme.pad)
        .frame(width: 300)
        .background(Theme.bg.ignoresSafeArea())
        .background(DarkWindow())
        .onAppear { model.refreshTrust() }
    }

    // MARK: sections

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("haptyq").font(Theme.font(13, .medium)).foregroundColor(Theme.fg)
                    PulseDot(pulses: model.pulses)
                }
                Text("haptics that tell you where you are.")
                    .font(Theme.font(11)).foregroundColor(Theme.fg2)
            }
            Spacer(minLength: 8)
            HaptyqSwitch(isOn: $model.settings.enabled, label: "haptyq")
        }
    }

    private var zoneList: some View {
        VStack(spacing: 0) {
            ForEach(Zone.allCases) { zone in
                ZoneRow(zone: zone,
                        setting: model.binding(for: zone),
                        expanded: expanded == zone,
                        toggle: { expanded = expanded == zone ? nil : zone },
                        hover: { inside in
                            if inside { hovered = zone } else if hovered == zone { hovered = nil }
                        },
                        preview: { model.preview(zone) })
            }
        }
        .opacity(enabled ? 1 : 0.32)
        .allowsHitTesting(enabled)
    }

    /// One shared line so hovering never shifts the layout.
    private var caption: some View {
        Text(hovered?.detail ?? model.notice ?? " ")
            .font(Theme.font(11))
            .foregroundColor(Theme.fg2)
            .lineLimit(1)
            .frame(maxWidth: .infinity, minHeight: 16, alignment: .leading)
            .padding(.top, 8)
    }

    private var permissionBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("haptyq needs accessibility access to see where buttons are.")
                .font(Theme.font(13)).foregroundColor(Theme.fg)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                TextButton(title: "grant access") {
                    grantClicked = true
                    model.grantAccess()
                }
                if grantClicked {
                    TextButton(title: "i did it", color: Theme.fg2) { model.refreshTrust() }
                }
            }
            .padding(.leading, -6)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.line, lineWidth: 1))
        .onAppear { model.startTrustPolling() }
        .onDisappear { model.stopTrustPolling() }
    }

    private var hardwareBanner: some View {
        Text("no force touch trackpad found. settings are saved anyway.")
            .font(Theme.font(11)).foregroundColor(Theme.fg2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: Theme.radius).strokeBorder(Theme.line, lineWidth: 1))
            .padding(.bottom, 8)
    }

    private var footer: some View {
        HStack {
            TextButton(title: "quit") { model.quit() }.padding(.leading, -6)
            Spacer()
            Text(model.version).font(Theme.font(11)).foregroundColor(Theme.dim)
        }
    }

    private var divider: some View {
        Rectangle().fill(Theme.line).frame(height: 1).padding(.vertical, 8)
    }

    private func toggleRow(_ title: String, _ isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title).font(Theme.font(13)).foregroundColor(Theme.fg)
            Spacer(minLength: 8)
            HaptyqSwitch(isOn: isOn, label: title)
        }
        .frame(height: Theme.row)
    }
}

private struct ZoneRow: View {
    let zone: Zone
    @Binding var setting: ZoneSetting
    let expanded: Bool
    let toggle: () -> Void
    let hover: (Bool) -> Void
    let preview: () -> Void
    @State private var rowHover = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(zone.title)
                    .font(Theme.font(13, expanded ? .medium : .regular))
                    .foregroundColor(Theme.fg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: Theme.row)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: toggle)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("\(zone.title), \(expanded ? "collapse" : "expand")")
                SignalBar(feel: $setting.feel, label: "\(zone.title) feel")
            }
            if expanded {
                VStack(spacing: 0) {
                    if zone.allowsReach { reachRow }
                    if zone.usesProximity { confirmRow }
                    HStack {
                        TextButton(title: "feel it", action: preview).padding(.leading, -6)
                        Spacer()
                    }
                    .frame(height: Theme.row)
                }
            }
        }
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: Theme.controlRadius).fill(rowHover ? Theme.wash : .clear))
        .padding(.horizontal, -8)
        .onHover { rowHover = $0; hover($0) }
    }

    private var reachRow: some View {
        HStack(spacing: 0) {
            Text("reach").font(Theme.font(11)).foregroundColor(Theme.fg2)
            Spacer()
            ForEach(Array(Reach.allCases.enumerated()), id: \.element) { i, r in
                if i > 0 { Text("·").font(Theme.font(11)).foregroundColor(Theme.dim).padding(.horizontal, 2) }
                Button { setting.reach = r } label: {
                    Text(r.title)
                        .font(Theme.font(11))
                        .foregroundColor(setting.reach == r ? Theme.bg : Theme.fg2)
                        .padding(.horizontal, 6)
                        .frame(height: 20)
                        .background(RoundedRectangle(cornerRadius: Theme.controlRadius)
                            .fill(setting.reach == r ? Theme.fg : .clear))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .haptyqFocus()
                .accessibilityLabel("reach \(r.title)")
                .accessibilityAddTraits(setting.reach == r ? [.isButton, .isSelected] : .isButton)
            }
        }
        .frame(height: Theme.row)
    }

    private var confirmRow: some View {
        HStack {
            Text("confirm click").font(Theme.font(11)).foregroundColor(Theme.fg2)
            Spacer()
            HaptyqSwitch(isOn: $setting.confirmClick, label: "\(zone.title) confirm click")
        }
        .frame(height: Theme.row)
    }
}

/// Forces the popover window dark so system chrome never renders light.
private struct DarkWindow: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let v = NSView()
        DispatchQueue.main.async { [weak v] in v?.window?.appearance = NSAppearance(named: .darkAqua) }
        return v
    }
    func updateNSView(_ v: NSView, context: Context) {
        DispatchQueue.main.async { [weak v] in v?.window?.appearance = NSAppearance(named: .darkAqua) }
    }
}
