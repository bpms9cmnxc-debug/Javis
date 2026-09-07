import Foundation

enum InputEngine: String, CaseIterable, Identifiable, Codable {
    case wispr
    case appleSpeech
    var id: String { rawValue }
}

enum OutputEngine: String, CaseIterable, Identifiable, Codable {
    case apple
    case openaiCompat
    var id: String { rawValue }
}

struct JavisSettings: Codable, Equatable {
    var language: String = "de"
    var inputEngine: InputEngine = .wispr
    var outputEngine: OutputEngine = .apple
    var lmStudioBaseURL: String = "http://127.0.0.1:1234/v1"
    var lmStudioAPIKey: String = "lm-studio"
    var lmStudioModel: String = ""
    var systemPrompt: String = JavisSettings.defaultSystemPrompt
    var temperature: Double = 0.7
    var maxTokens: Int = 800
    var ttsBaseURL: String = "http://127.0.0.1:8880/v1"
    var ttsAPIKey: String = ""
    var ttsModel: String = "tts-1"
    var ttsVoice: String = "alloy"
    var appleVoice: String = ""
    var speakRate: Float = 0.48
    var hotkeyModifiers: UInt = 393_216
    var hotkeyKeyCode: UInt16 = 49
    var wisprKeyCode: UInt16 = 49
    var wisprModifiers: UInt = 8_388_608
    var hidePartnerApps: Bool = true
    var autoStartLMStudioServer: Bool = true
    var sentenceStreaming: Bool = true
    var keepHUD: Bool = true
    var alwaysListen: Bool = false
    var silenceTimeoutMs: Int = 1400
    var wisprBundleIds: [String] = [
        "ai.wispr.flow",
        "com.wispr.flow",
        "com.wisprflow.macos",
        "ai.wisprflow.WisprFlow",
    ]
    var lmStudioBundleIds: [String] = [
        "com.lmstudio.app",
        "ai.elementlabs.lmstudio",
        "ai.lmstudio.LMStudio",
    ]

    static let defaultSystemPrompt = """
    Du bist Javis, ein knapper Sprachassistent auf diesem Mac.
    Antworte in der Sprache des Nutzers. Halte Antworten gesprochen kurz,
    klar und ohne Markdown, Aufzählungssterne oder Codezäune, außer der
    Nutzer verlangt ausdrücklich Details.
    """
}

enum SettingsStore {
    private static let key = "javis.settings.v1"

    static func load() -> JavisSettings {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(JavisSettings.self, from: data)
        else { return JavisSettings() }
        return decoded
    }

    static func save(_ settings: JavisSettings) {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
