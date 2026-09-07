import AppKit
import ApplicationServices
import AVFoundation
import Speech

/// Starts Wispr dictation into the hidden capture field. Falls back to Apple Speech.
final class WisprBridge {
    private var recognizer: SFSpeechRecognizer?
    private var audioEngine: AVAudioEngine?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var idleWork: DispatchWorkItem?

    func triggerWispr(keyCode: UInt16, modifiers: UInt) {
        synthesizeKey(keyCode: keyCode, flags: CGEventFlags(rawValue: modifiers))
        if keyCode != 49 || modifiers != 8_388_608 {
            synthesizeKey(keyCode: 49, flags: .maskSecondaryFn)
        }
    }

    func isWisprRunning(bundleIds: [String]) -> Bool {
        let running = NSWorkspace.shared.runningApplications
        if running.contains(where: { bundleIds.contains($0.bundleIdentifier ?? "") }) {
            return true
        }
        return running.contains { ($0.localizedName ?? "").localizedCaseInsensitiveContains("wispr") }
    }

    func launchWisprIfNeeded(bundleIds: [String]) {
        guard !isWisprRunning(bundleIds: bundleIds) else { return }
        for bid in bundleIds {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bid) {
                let cfg = NSWorkspace.OpenConfiguration()
                cfg.activates = false
                cfg.hides = true
                NSWorkspace.shared.openApplication(at: url, configuration: cfg)
                return
            }
        }
    }

    func startAppleSpeech(locale: Locale, onPartial: @escaping (String) -> Void, onFinal: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        stopAppleSpeech()
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                guard status == .authorized else {
                    onError("Spracherkennung ist nicht erlaubt.")
                    return
                }
                self.runAppleSpeech(locale: locale, onPartial: onPartial, onFinal: onFinal, onError: onError)
            }
        }
    }

    func stopAppleSpeech() {
        idleWork?.cancel()
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
    }

    private func runAppleSpeech(locale: Locale, onPartial: @escaping (String) -> Void, onFinal: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
        recognizer = SFSpeechRecognizer(locale: locale) ?? SFSpeechRecognizer()
        guard let recognizer, recognizer.isAvailable else {
            onError("Keine Spracherkennung verfügbar.")
            return
        }
        let engine = AVAudioEngine()
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        req.requiresOnDeviceRecognition = true
        audioEngine = engine
        request = req
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            req.append(buffer)
        }
        do { try engine.start() } catch {
            onError("Mikrofon konnte nicht geöffnet werden.")
            return
        }
        task = recognizer.recognitionTask(with: req) { [weak self] result, error in
            if let error {
                onError(error.localizedDescription)
                return
            }
            guard let result else { return }
            let text = result.bestTranscription.formattedString
            onPartial(text)
            self?.idleWork?.cancel()
            if result.isFinal {
                onFinal(text)
                return
            }
            let work = DispatchWorkItem { onFinal(text) }
            self?.idleWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
        }
    }

    private func synthesizeKey(keyCode: UInt16, flags: CGEventFlags) {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: keyCode, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}
