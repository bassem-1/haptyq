import SwiftUI
import HaptyqKit

struct PopoverView: View {
    @ObservedObject var model: AppModel
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
            HStack {
                TextButton(title: "customize…") { model.openWindow() }.padding(.leading, -6)
                Spacer()
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
                HStack(spacing: 0) {
                    Text(zone.title)
                        .font(Theme.font(13))
                        .foregroundColor(Theme.fg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    SignalBar(feel: model.binding(for: zone).feel, label: "\(zone.title) feel")
                }
                .frame(height: Theme.row)
                .padding(.horizontal, 8)
                .background(RoundedRectangle(cornerRadius: Theme.controlRadius)
                    .fill(hovered == zone ? Theme.wash : .clear))
                .padding(.horizontal, -8)
                .onHover { inside in
                    if inside { hovered = zone } else if hovered == zone { hovered = nil }
                }
            }
        }
        .opacity(enabled ? 1 : 0.32)
        .allowsHitTesting(enabled)
    }

    /// One shared line so hovering never shifts the layout.
    private var caption: some View {
        Text(hovered?.detail ?? " ")
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
