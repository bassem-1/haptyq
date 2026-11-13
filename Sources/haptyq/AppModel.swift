import AppKit
import Combine
import SwiftUI
import HaptyqKit

@MainActor
final class AppModel: ObservableObject {
    /// One model for the app delegate, the popover and the window, so no state is duplicated.
    static let shared = AppModel()

    /// Zone shown in the window's inspector. Window-only state.
    @Published var selected: Zone = .close
    @Published var settings: HaptyqKit.Settings
    @Published private(set) var trusted: Bool
    /// Not @Published: pulses arrive at up to 30 Hz and must not re-render every observer of the model.
    let pulses = PassthroughSubject<Void, Never>()
    @Published private(set) var launchAtLogin: Bool
    @Published var notice: String?
    /// Mirrors engine.isRunning (not observable itself) for the status line.
    @Published private(set) var running = false

    let engine = HaptyqEngine()
    private var gadget: GadgetController?
    private var bag = Set<AnyCancellable>()
    private var trustTimer: Timer?
    private lazy var mainWindow = MainWindowController(model: self)

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
        running = engine.isRunning

        $settings.dropFirst()
            .sink { [weak self] s in self?.engine.apply(s); self?.syncRunning() }
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
        scheduleTrustPoll()
    }

    func openWindow() { mainWindow.show() }

    func binding(for zone: Zone) -> Binding<ZoneSetting> {
        Binding(get: { [weak self] in self?.settings[zone] ?? HaptyqKit.Settings.defaults[zone] },
                set: { [weak self] in self?.settings[zone] = $0 })
    }

    func preview(_ zone: Zone) { engine.preview(zone, settings[zone]) }

    // MARK: permission

    func grantAccess() {
        Permissions.request()
        Permissions.openSettings()
    }

    /// Manual re-check (popover appearing, "i did it"). Always nudges the engine.
    func refreshTrust() {
        let now = Permissions.isTrusted
        if now != trusted { trusted = now }
        engine.refresh()
        syncRunning()
        scheduleTrustPoll()
    }

    private func syncRunning() {
        if running != engine.isRunning { running = engine.isRunning }
    }

    /// Always-on poll, independent of any ui: every 2 s while untrusted, every 10 s while trusted (revocation).
    private func scheduleTrustPoll() {
        trustTimer?.invalidate()
        let timer = Timer(timeInterval: trusted ? 10 : 2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.pollTrust() }
        }
        RunLoop.main.add(timer, forMode: .common)
        trustTimer = timer
    }

    private func pollTrust() {
        let now = Permissions.isTrusted
        guard now != trusted else { return }
        trusted = now
        engine.refresh()
        syncRunning()
        scheduleTrustPoll()
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
