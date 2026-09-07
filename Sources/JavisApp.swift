import SwiftUI
import AppKit

@main
struct JavisApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = AppModel.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarRoot()
                .environmentObject(model)
        } label: {
            Image(systemName: model.menuSymbol)
        }
        .menuBarExtraStyle(.window)

        Window("Javis", id: "settings") {
            SettingsView()
                .environmentObject(model)
        }
        .defaultSize(width: 620, height: 480)
        .windowStyle(.automatic)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        AppModel.shared.pipe.cloak.hideNow()
        if AppModel.shared.settings.autoStartLMStudioServer {
            LMStudioClient.launchApp(bundleIds: AppModel.shared.settings.lmStudioBundleIds)
            LMStudioClient.startServerIfNeeded()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            AppModel.shared.refreshStatus()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }
}
