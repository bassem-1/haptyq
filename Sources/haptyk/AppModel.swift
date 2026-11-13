import AppKit
import Combine
import SwiftUI
import HaptykKit

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: HaptykKit.Settings
    @Published private(set) var trusted: Bool
    /// Not @Published: pulses arrive at up to 30 Hz and must not re-render every observer of the model.
    let pulses = PassthroughSubject<Void, Never>()
    @Published private(set) var launchAtLogin: Bool
    @Published var notice: String?

    let engine = HaptykEngine()
    private var gadget: GadgetController?
    private var bag = Set<AnyCancellable>()
    private var trustTimer: Timer?

    var hardwareAvailable: Bool { engine.hardwareAvailable }

    var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String).map { "v\($0)" } ?? "dev"
    }

    init() {
        let loaded = SettingsStore.load()
        settings = loaded
        trusted = Permissions.isTrusted
        launchAtLogin = LaunchAtLogin.isEnabled
        NSApp?.setActivationPolicy(.accessory)

        engine.onPulse = { [weak self] in self?.pulses.send() }
        engine.apply(loaded)

        $settings.dropFirst()
            .sink { [weak self] s in self?.engine.apply(s) }
            .store(in: &bag)
        $settings.dropFirst()
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { SettingsStore.save($0) }
            .store(in: &bag)
        NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                SettingsStore.save(self.settings)
                self.engine.shutdown()
            }
            .store(in: &bag)

        gadget = GadgetController(model: self)
    }

    func binding(for zone: Zone) -> Binding<ZoneSetting> {
        Binding(get: { [weak self] in self?.settings[zone] ?? HaptykKit.Settings.defaults[zone] },
                set: { [weak self] in self?.settings[zone] = $0 })
    }

    func preview(_ zone: Zone) { engine.preview(zone, settings[zone]) }

    // MARK: permission

    func grantAccess() {
        Permissions.request()
        Permissions.openSettings()
    }

    func refreshTrust() {
        let now = Permissions.isTrusted
        if now != trusted { trusted = now }
        // also when revoked, so a running tap is torn down
        engine.refresh()
    }

    /// Poll while the permission banner is visible; dismisses itself once access is granted.
    func startTrustPolling() {
        guard trustTimer == nil else { return }
        trustTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshTrust()
                if self.trusted { self.stopTrustPolling() }
            }
        }
    }

    func stopTrustPolling() {
        trustTimer?.invalidate()
        trustTimer = nil
    }

    // MARK: misc

    func setLaunchAtLogin(_ on: Bool) {
        notice = LaunchAtLogin.set(on)
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    func quit() {
        SettingsStore.save(settings)
        engine.shutdown()
        NSApp.terminate(nil)
    }
}
