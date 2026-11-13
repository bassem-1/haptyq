import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppModel.shared.openWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        AppModel.shared.openWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}

@main
struct HaptyqApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    private var model: AppModel { AppModel.shared }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Image(nsImage: MenuBarIcon.image(enabled: model.settings.enabled))
            .accessibilityLabel("haptyq")
    }
}
