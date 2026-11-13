import AppKit
import SwiftUI
import HaptyqKit

/// AppKit owns the window so we control activation policy and reopen; SwiftUI only draws.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let size = NSSize(width: 620, height: 460)
    private weak var model: AppModel?
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
        super.init()
    }

    func show() {
        guard let model else { return }
        NSApp.setActivationPolicy(.regular)
        let w = window ?? makeWindow(model)
        window = w
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeWindow(_ model: AppModel) -> NSWindow {
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: Self.size),
                         styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                         backing: .buffered, defer: false)
        w.title = "haptyq"
        w.titleVisibility = .hidden
        w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        w.isMovableByWindowBackground = false
        w.appearance = NSAppearance(named: .darkAqua)
        w.backgroundColor = .black
        w.delegate = self
        let host = NSHostingView(rootView: MainView(model: model))
        host.frame = NSRect(origin: .zero, size: Self.size)
        w.contentView = host
        w.setContentSize(Self.size)
        w.center()
        w.setFrameAutosaveName("haptyq.main")
        return w
    }

    func windowWillClose(_ notification: Notification) {
        model?.engine.hover(nil, distance: nil)
        NSApp.setActivationPolicy(.accessory)
    }
}

struct MainView: View {
    @ObservedObject var model: AppModel

    private var status: String {
        if !model.trusted { return "needs accessibility ·" }
        if !model.hardwareAvailable { return "no force touch trackpad" }
        if !model.settings.enabled { return "paused" }
        return model.running ? "on · listening" : "on"
    }

    var body: some View {
        VStack(spacing: 0) {
            header.frame(height: 44)
            hairline
            HStack(alignment: .top, spacing: 24) {
                Playground(model: model).frame(width: 300, alignment: .topLeading)
                Inspector(model: model).frame(width: 256, alignment: .topLeading)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            hairline
            footer.frame(height: 40)
        }
        .frame(width: MainWindowController.size.width, height: MainWindowController.size.height)
        .background(Theme.bg)
        .ignoresSafeArea()
    }

    private var hairline: some View { Rectangle().fill(Theme.line).frame(height: 1) }

    private var header: some View {
        HStack(spacing: 12) {
            Text("haptyq").font(Theme.font(13, .medium)).foregroundColor(Theme.fg)
            PulseDot(pulses: model.pulses)
            HStack(spacing: 0) {
                Text(status).font(Theme.font(11)).foregroundColor(Theme.fg2)
                if !model.trusted {
                    TextButton(title: "grant", size: 11) { model.grantAccess() }
                }
            }
            Spacer(minLength: 8)
            HaptyqSwitch(isOn: $model.settings.enabled, label: "haptyq")
        }
        .padding(.leading, 84)
        .padding(.trailing, 20)
    }

    private var footer: some View {
        HStack(spacing: 20) {
            toggle("desktop gadget", $model.settings.showGadget)
            toggle("float", $model.settings.gadgetFloats)
            toggle("launch at login", Binding(get: { model.launchAtLogin },
                                              set: { model.setLaunchAtLogin($0) }))
            Spacer(minLength: 0)
            TextButton(title: "quit", size: 11) { model.quit() }
            Text(model.notice ?? model.version)
                .font(Theme.font(11)).foregroundColor(Theme.dim)
                .lineLimit(1)
        }
        .padding(.horizontal, 20)
    }

    private func toggle(_ title: String, _ isOn: Binding<Bool>) -> some View {
        HStack(spacing: 8) {
            Text(title).font(Theme.font(11)).foregroundColor(Theme.fg2)
            HaptyqSwitch(isOn: isOn, label: title)
        }
    }
}
