import AppKit

/// Keeps Wispr and LM Studio running but out of sight while Javis talks.
final class WindowCloak {
    private var timer: Timer?
    private var names = ["wispr", "lm studio", "lmstudio"]
    private var bundleIds: [String] = []

    func start(bundleIds: [String], enabled: Bool) {
        stop()
        self.bundleIds = bundleIds
        guard enabled else { return }
        hideNow()
        timer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] _ in
            self?.hideNow()
        }
        timer?.tolerance = 0.3
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func hideNow() {
        let running = NSWorkspace.shared.runningApplications
        for app in running {
            guard app.bundleIdentifier != "app.javis.macos" else { continue }
            let bid = app.bundleIdentifier ?? ""
            let name = (app.localizedName ?? "").lowercased()
            let byId = bundleIds.contains(bid)
            let byName = names.contains { name.contains($0) }
            if byId || byName {
                if !app.isHidden { app.hide() }
            }
        }
    }
}
