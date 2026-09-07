import Foundation
import SwiftUI
import Combine

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var settings: JavisSettings {
        didSet { SettingsStore.save(settings); pipe.apply(settings) }
    }
    @Published var phase: Phase = .idle
    @Published var history: [ChatTurn] = []
    @Published var partialTranscript: String = ""
    @Published var banner: String = ""
    @Published var models: [String] = []
    @Published var lmReachable: Bool = false
    @Published var wisprPresent: Bool = false

    let pipe = Orchestrator()

    var menuSymbol: String {
        switch phase {
        case .idle: return "waveform"
        case .listening: return "mic.fill"
        case .thinking: return "ellipsis.circle"
        case .speaking: return "speaker.wave.2.fill"
        }
    }

    var phaseLabel: String {
        switch phase {
        case .idle: return settings.language == "de" ? "Bereit" : "Ready"
        case .listening: return settings.language == "de" ? "Hört zu" : "Listening"
        case .thinking: return settings.language == "de" ? "Denkt" : "Thinking"
        case .speaking: return settings.language == "de" ? "Spricht" : "Speaking"
        }
    }

    private init() {
        settings = SettingsStore.load()
        pipe.attach(model: self)
        refreshStatus()
    }

    func toggleListen() {
        if phase == .listening || phase == .thinking || phase == .speaking {
            pipe.stopListen(self)
            phase = .idle
        } else {
            banner = ""
            pipe.beginListen(self)
        }
    }

    func resetConversation() {
        history.removeAll()
        partialTranscript = ""
        pipe.stopListen(self)
        phase = .idle
    }

    func refreshStatus() {
        wisprPresent = pipe.wispr.isWisprRunning(bundleIds: settings.wisprBundleIds)
        Task {
            let list = await LMStudioClient.listModels(
                baseURL: settings.lmStudioBaseURL,
                apiKey: settings.lmStudioAPIKey
            )
            await MainActor.run {
                self.models = list
                self.lmReachable = !list.isEmpty
                if settings.lmStudioModel.isEmpty, let first = list.first {
                    settings.lmStudioModel = first
                }
            }
        }
    }
}
