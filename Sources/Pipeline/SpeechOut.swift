import AVFoundation
import Foundation

/// Second AI in the chain: spoken output for the LM Studio reply.
final class SpeechOut: NSObject, AVSpeechSynthesizerDelegate {
    private let synth = AVSpeechSynthesizer()
    private var audioPlayer: AVAudioPlayer?
    private var queue: [String] = []
    private var speaking = false
    var onStart: (() -> Void)?
    var onFinish: (() -> Void)?

    override init() {
        super.init()
        synth.delegate = self
    }

    func reset() {
        queue.removeAll()
        synth.stopSpeaking(at: .immediate)
        audioPlayer?.stop()
        speaking = false
    }

    func enqueue(_ sentence: String, settings: JavisSettings) {
        let clean = Self.stripMarkdown(sentence)
        guard !clean.isEmpty else { return }
        queue.append(clean)
        pump(settings: settings)
    }

    func speakAll(_ text: String, settings: JavisSettings) {
        reset()
        enqueue(text, settings: settings)
    }

    private func pump(settings: JavisSettings) {
        guard !speaking, let next = queue.first else {
            if queue.isEmpty { onFinish?() }
            return
        }
        speaking = true
        onStart?()
        if settings.outputEngine == .openaiCompat {
            Task { await speakRemote(next, settings: settings) }
        } else {
            speakApple(next, settings: settings)
        }
    }

    private func speakApple(_ text: String, settings: JavisSettings) {
        let u = AVSpeechUtterance(string: text)
        u.rate = settings.speakRate
        u.pitchMultiplier = 1.02
        u.preUtteranceDelay = 0.02
        u.postUtteranceDelay = 0.08
        if !settings.appleVoice.isEmpty,
           let voice = AVSpeechSynthesisVoice(identifier: settings.appleVoice) {
            u.voice = voice
        } else {
            u.voice = AVSpeechSynthesisVoice(language: settings.language == "de" ? "de-DE" : "en-US")
        }
        synth.speak(u)
    }

    private func speakRemote(_ text: String, settings: JavisSettings) async {
        guard let url = URL(string: settings.ttsBaseURL.hasSuffix("/")
                            ? settings.ttsBaseURL + "audio/speech"
                            : settings.ttsBaseURL + "/audio/speech")
        else {
            await MainActor.run { self.advance(settings: settings) }
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !settings.ttsAPIKey.isEmpty {
            req.setValue("Bearer \(settings.ttsAPIKey)", forHTTPHeaderField: "Authorization")
        }
        let body: [String: Any] = [
            "model": settings.ttsModel,
            "voice": settings.ttsVoice,
            "input": text,
            "format": "mp3",
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            await MainActor.run {
                self.audioPlayer = try? AVAudioPlayer(data: data)
                self.audioPlayer?.delegate = self
                if let player = self.audioPlayer, player.play() {
                    return
                }
                self.speakApple(text, settings: settings)
            }
        } catch {
            JLog.error("tts: \(error.localizedDescription)")
            await MainActor.run { self.speakApple(text, settings: settings) }
        }
    }

    private func advance(settings: JavisSettings) {
        if !queue.isEmpty { queue.removeFirst() }
        speaking = false
        pump(settings: settings)
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        advance(settings: SettingsStore.load())
    }

    static func stripMarkdown(_ raw: String) -> String {
        var s = raw
        s = s.replacingOccurrences(of: #"```[\s\S]*?```"#, with: " ", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\*\*|__|`|#"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^\s*[-*]\s+"#, with: "", options: .regularExpression)
        return s.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension SpeechOut: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        advance(settings: SettingsStore.load())
    }
}

enum SentenceBuffer {
    private(set) static var pending = ""

    static func reset() { pending = "" }

    static func push(_ full: String) -> [String] {
        let new = String(full.dropFirst(min(pending.count, full.count)))
        pending = full
        var out: [String] = []
        var buf = ""
        for ch in new {
            buf.append(ch)
            if ".!?\n".contains(ch), buf.trimmingCharacters(in: .whitespacesAndNewlines).count > 8 {
                out.append(buf)
                buf = ""
            }
        }
        return out
    }

    static func flushRemainder() -> String {
        pending
    }
}
