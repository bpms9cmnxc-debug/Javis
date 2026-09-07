import AppKit
import Carbon.HIToolbox

final class GlobalHotkey {
    private var local: Any?
    private var global: Any?
    private var keyCode: UInt16 = 49
    private var modifiers: NSEvent.ModifierFlags = [.control, .option]
    var onTrigger: (() -> Void)?

    func update(keyCode: UInt16, carbonModifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = Self.fromCarbon(carbonModifiers)
        start()
    }

    func start() {
        stop()
        local = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matches(event) == true {
                self?.onTrigger?()
                return nil
            }
            return event
        }
        global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.matches(event) == true {
                self?.onTrigger?()
            }
        }
    }

    func stop() {
        if let local { NSEvent.removeMonitor(local) }
        if let global { NSEvent.removeMonitor(global) }
        local = nil
        global = nil
    }

    private func matches(_ event: NSEvent) -> Bool {
        guard event.keyCode == keyCode else { return false }
        let wanted = modifiers.intersection([.command, .shift, .option, .control])
        let have = event.modifierFlags.intersection([.command, .shift, .option, .control])
        return have == wanted
    }

    static func fromCarbon(_ carbon: UInt) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & UInt(cmdKey) != 0 { flags.insert(.command) }
        if carbon & UInt(shiftKey) != 0 { flags.insert(.shift) }
        if carbon & UInt(optionKey) != 0 { flags.insert(.option) }
        if carbon & UInt(controlKey) != 0 { flags.insert(.control) }
        return flags
    }
}
