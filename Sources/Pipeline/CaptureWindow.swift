import AppKit

/// Off-screen key window whose text view is the paste target for Wispr.
final class CaptureWindow: NSWindow, NSTextViewDelegate {
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 120))
    var onIdleTranscript: ((String) -> Void)?
    private var idleWork: DispatchWorkItem?
    private var silenceMs: Int = 1400
    private var lastEmitted = ""

    convenience init(silenceMs: Int) {
        self.init(
            contentRect: NSRect(x: -2400, y: -2400, width: 480, height: 180),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.silenceMs = silenceMs
        isReleasedWhenClosed = false
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        ignoresMouseEvents = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hasShadow = false
        alphaValue = 0.02

        textView.delegate = self
        textView.isRichText = false
        textView.font = .systemFont(ofSize: 16)
        textView.string = ""
        contentView = textView
    }

    func arm() {
        lastEmitted = ""
        textView.string = ""
        orderFrontRegardless()
        makeKeyAndOrderFront(nil)
        makeFirstResponder(textView)
        NSApp.activate(ignoringOtherApps: true)
    }

    func disarm() {
        idleWork?.cancel()
        orderOut(nil)
    }

    func textDidChange(_ notification: Notification) {
        idleWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let text = self.textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard text.count >= 2, text != self.lastEmitted else { return }
            self.lastEmitted = text
            self.onIdleTranscript?(text)
            self.textView.string = ""
        }
        idleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(silenceMs), execute: work)
    }
}
