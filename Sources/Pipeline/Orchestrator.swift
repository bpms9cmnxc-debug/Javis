import Foundation
import AppKit

enum Phase: String {
    case idle
    case listening
    case thinking
    case speaking
}

@MainActor
final class Orchestrator {
    let cloak = WindowCloak()
    let hotkey = GlobalHotkey()
    let wispr = WisprBridge()
    let speech = SpeechOut()
    private var capture: CaptureWindow?
    private var spokenPrefix = ""

    func attach(model: AppModel) {
        hotkey.onTrigger = { [weak model] in
            Task { @MainActor in model?.toggleListen() }
        }
        speech.onStart = { [weak model] in
            model?.phase = .speaking
        }
        speech.onFinish = { [weak model] in
            if model?.phase == .speaking { model?.phase = .idle }
        }
        apply(model.settings)
    }

    func apply(_ settings: JavisSettings) {
        hotkey.update(keyCode: settings.hotkeyKeyCode, carbonModifiers: settings.hotkeyModifiers)
        let ids = settings.wisprBundleIds + settings.lmStudioBundleIds
        cloak.start(bundleIds: ids, enabled: settings.hidePartnerApps)
        if capture == nil {
            let win = CaptureWindow(silenceMs: settings.silenceTimeoutMs)
            win.onIdleTranscript = { [weak self] text in
                Task { @MainActor in
                    await self?.handleTranscript(text)
                }
            }
            capture = win
        }
    }

    func beginListen(_ model: AppModel) {
        speech.reset()
        spokenPrefix = ""
        SentenceBuffer.reset()
        model.partialTranscript = ""
        model.phase = .listening
        cloak.hideNow()

        if model.settings.autoStartLMStudioServer {
            LMStudioClient.launchApp(bundleIds: model.settings.lmStudioBundleIds)
            LMStudioClient.startServerIfNeeded()
        }

        if model.settings.inputEngine == .wispr {
            wispr.launchWisprIfNeeded(bundleIds: model.settings.wisprBundleIds)
            capture?.arm()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.wispr.triggerWispr(
                    keyCode: model.settings.wisprKeyCode,
                    modifiers: model.settings.wisprModifiers
                )
            }
            if !wispr.isWisprRunning(bundleIds: model.settings.wisprBundleIds) {
                model.banner = "Wispr nicht gefunden — integrierte Diktierfunktion."
                startApple(model)
            }
        } else {
            startApple(model)
        }
    }

    func stopListen(_ model: AppModel) {
        wispr.stopAppleSpeech()
        capture?.disarm()
        speech.reset()
        if model.phase != .thinking { model.phase = .idle }
    }

    private func startApple(_ model: AppModel) {
        let loc = Locale(identifier: model.settings.language == "de" ? "de-DE" : "en-US")
        wispr.startAppleSpeech(locale: loc, onPartial: { text in
            Task { @MainActor in model.partialTranscript = text }
        }, onFinal: { text in
            Task { @MainActor in await self.handleTranscript(text) }
        }, onError: { err in
            Task { @MainActor in
                model.banner = err
                model.phase = .idle
            }
        })
    }

    func handleTranscript(_ raw: String) async {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return }
        let model = AppModel.shared
        if interceptCommand(text, model: model) { return }

        capture?.disarm()
        wispr.stopAppleSpeech()
        model.partialTranscript = ""
        model.history.append(ChatTurn(role: "user", content: text))
        model.phase = .thinking
        cloak.hideNow()

        let assistant = ChatTurn(role: "assistant", content: "")
        model.history.append(assistant)
        let aid = assistant.id
        spokenPrefix = ""
        SentenceBuffer.reset()

        do {
            let reply = try await LMStudioClient.stream(
                baseURL: model.settings.lmStudioBaseURL,
                apiKey: model.settings.lmStudioAPIKey,
                model: model.settings.lmStudioModel,
                systemPrompt: model.settings.systemPrompt,
                history: Array(model.history.dropLast()),
                user: text,
                temperature: model.settings.temperature,
                maxTokens: model.settings.maxTokens,
                onDelta: { full in
                    Task { @MainActor in
                        if let i = model.history.firstIndex(where: { $0.id == aid }) {
                            model.history[i].content = full
                        }
                        if model.settings.sentenceStreaming {
                            let bits = SentenceBuffer.push(full)
                            for bit in bits {
                                self.speech.enqueue(bit, settings: model.settings)
                                self.spokenPrefix += bit
                            }
                        }
                    }
                }
            )
            if let i = model.history.firstIndex(where: { $0.id == aid }) {
                model.history[i].content = reply.text
            }
            if !model.settings.lmStudioModel.isEmpty { /* keep */ }
            else if !reply.model.isEmpty {
                model.settings.lmStudioModel = reply.model
            }
            let leftover = String(reply.text.dropFirst(min(spokenPrefix.count, reply.text.count)))
            if leftover.trimmingCharacters(in: .whitespacesAndNewlines).count > 1 {
                speech.enqueue(leftover, settings: model.settings)
            } else if spokenPrefix.isEmpty {
                speech.speakAll(reply.text, settings: model.settings)
            }
            model.phase = .speaking
        } catch {
            model.banner = "LM Studio: \(error.localizedDescription)"
            model.phase = .idle
            JLog.error(error.localizedDescription)
        }
    }

    private func interceptCommand(_ text: String, model: AppModel) -> Bool {
        let t = text.lowercased()
        let stop = ["stopp", "stop", "halt", "ruhe", "sei still", "quiet"]
        let reset = ["neue unterhaltung", "new conversation", "reset", "vergiss das"]
        let hide = ["verstecke", "hide windows", "verschwinde"]
        if stop.contains(where: { t.contains($0) }) {
            stopListen(model)
            model.phase = .idle
            return true
        }
        if reset.contains(where: { t.contains($0) }) {
            model.history.removeAll()
            model.banner = "Neue Unterhaltung."
            return true
        }
        if hide.contains(where: { t.contains($0) }) {
            cloak.hideNow()
            return true
        }
        return false
    }
}
