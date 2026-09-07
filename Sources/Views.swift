import SwiftUI
import AVFoundation

struct MenuBarRoot: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Circle()
                    .fill(indicator)
                    .frame(width: 8, height: 8)
                Text("Javis")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(model.phaseLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            PipelineStrip(model: model)

            if !model.banner.isEmpty {
                Text(model.banner)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if !model.partialTranscript.isEmpty {
                Text(model.partialTranscript)
                    .font(.system(size: 12))
                    .foregroundStyle(.primary)
                    .lineLimit(4)
            } else if let last = model.history.last {
                Text(last.content)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }

            HStack(spacing: 8) {
                Button(model.phase == .idle ? de("Sprechen", "Talk") : de("Stopp", "Stop")) {
                    model.toggleListen()
                }
                .keyboardShortcut(.space, modifiers: [.control, .option])

                Button(de("Neu", "New")) { model.resetConversation() }

                Spacer()

                Button(de("Einstellungen", "Settings")) {
                    NSApp.activate(ignoringOtherApps: true)
                    openSettings()
                }
            }

            Divider()

            HStack {
                statusDot(model.wisprPresent, de("Wispr", "Wispr"))
                statusDot(model.lmReachable, "LM Studio")
                Spacer()
                Button(de("Beenden", "Quit")) { NSApp.terminate(nil) }
            }
            .font(.system(size: 11))
        }
        .padding(14)
        .frame(width: 360)
        .onAppear { model.refreshStatus() }
    }

    private var indicator: Color {
        switch model.phase {
        case .idle: return Color.secondary.opacity(0.5)
        case .listening: return Color.white
        case .thinking: return Color.gray
        case .speaking: return Color(red: 0.62, green: 0.72, blue: 0.80)
        }
    }

    private func statusDot(_ on: Bool, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(on ? Color.green.opacity(0.85) : Color.secondary.opacity(0.35)).frame(width: 6, height: 6)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private func de(_ d: String, _ e: String) -> String {
        model.settings.language == "de" ? d : e
    }

    private func openSettings() {
        for w in NSApp.windows where w.title == "Javis" {
            w.makeKeyAndOrderFront(nil)
            return
        }
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}

struct PipelineStrip: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 0) {
            chip("Mic", on: model.phase == .listening)
            chev()
            chip("Wispr", on: model.wisprPresent)
            chev()
            chip("LM Studio", on: model.lmReachable || model.phase == .thinking)
            chev()
            chip(model.settings.outputEngine == .apple ? "Voice" : "TTS KI", on: model.phase == .speaking)
        }
        .font(.system(size: 10, weight: .medium))
    }

    private func chip(_ t: String, on: Bool) -> some View {
        Text(t)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(on ? Color.white.opacity(0.16) : Color.white.opacity(0.05), in: Capsule())
    }

    private func chev() -> some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 3)
    }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        TabView {
            general.tabItem { Label(de("Allgemein", "General"), systemImage: "slider.horizontal.3") }
            models.tabItem { Label("Modelle", systemImage: "cpu") }
            voice.tabItem { Label(de("Stimme", "Voice"), systemImage: "waveform") }
            privacy.tabItem { Label(de("Privat", "Privacy"), systemImage: "eye.slash") }
        }
        .padding(18)
        .frame(minWidth: 560, minHeight: 420)
    }

    private var general: some View {
        Form {
            Picker(de("Sprache", "Language"), selection: $model.settings.language) {
                Text("Deutsch").tag("de")
                Text("English").tag("en")
            }
            Picker(de("Eingabe", "Input"), selection: $model.settings.inputEngine) {
                Text("Wispr Flow").tag(InputEngine.wispr)
                Text(de("Apple Diktat", "Apple Speech")).tag(InputEngine.appleSpeech)
            }
            Toggle(de("Partner-Apps verborgen halten", "Keep partner apps hidden"), isOn: $model.settings.hidePartnerApps)
            Toggle(de("LM-Studio-Server selbst starten", "Auto-start LM Studio server"), isOn: $model.settings.autoStartLMStudioServer)
            Toggle(de("Sätze streamen (früher sprechen)", "Speak sentences as they arrive"), isOn: $model.settings.sentenceStreaming)
            Toggle(de("HUD-Orb", "HUD orb"), isOn: $model.settings.keepHUD)
        }
    }

    private var models: some View {
        Form {
            TextField("LM Studio URL", text: $model.settings.lmStudioBaseURL)
            TextField("API Key", text: $model.settings.lmStudioAPIKey)
            Picker(de("Modell", "Model"), selection: $model.settings.lmStudioModel) {
                Text(de("automatisch", "auto")).tag("")
                ForEach(model.models, id: \.self) { Text($0).tag($0) }
            }
            Slider(value: $model.settings.temperature, in: 0...1.5) {
                Text("Temperature \(model.settings.temperature, specifier: \"%.2f\")")
            }
            Stepper(value: $model.settings.maxTokens, in: 128...4096, step: 64) {
                Text("max tokens \(model.settings.maxTokens)")
            }
            TextEditor(text: $model.settings.systemPrompt)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 120)
            Button(de("Modelle aktualisieren", "Refresh models")) { model.refreshStatus() }
        }
    }

    private var voice: some View {
        Form {
            Picker(de("Ausgabe-KI", "Output engine"), selection: $model.settings.outputEngine) {
                Text(de("Apple Stimme (lokal)", "Apple voice (on-device)")).tag(OutputEngine.apple)
                Text(de("TTS-KI (OpenAI-kompatibel)", "TTS AI (OpenAI-compatible)")).tag(OutputEngine.openaiCompat)
            }
            if model.settings.outputEngine == .openaiCompat {
                TextField("TTS Base URL", text: $model.settings.ttsBaseURL)
                TextField("TTS Key", text: $model.settings.ttsAPIKey)
                TextField("Voice", text: $model.settings.ttsVoice)
                TextField("Model", text: $model.settings.ttsModel)
            }
            Slider(value: Binding(
                get: { Double(model.settings.speakRate) },
                set: { model.settings.speakRate = Float($0) }
            ), in: 0.3...0.65) {
                Text(de("Sprechtempo", "Rate"))
            }
        }
    }

    private var privacy: some View {
        Form {
            LabeledContent("Accessibility") {
                Text(Permissions.accessibilityTrusted ? de("erlaubt", "granted") : de("fehlt", "missing"))
            }
            Button(de("Bedienungshilfen anfordern", "Request Accessibility")) {
                Permissions.promptAccessibility()
            }
            Button(de("Mikrofon-Einstellungen", "Microphone settings")) {
                Permissions.openPrivacyPane(anchor: "Privacy_Microphone")
            }
            Text(de(
                "Wispr und LM Studio bleiben im Dock unsichtbar geführt, sobald Javis sie versteckt. Es verlassen keine Sprachdaten Javis selbst — Wispr und das gewählte TTS folgen ihren eigenen Pfaden.",
                "Wispr and LM Studio stay hidden while Javis runs. Javis itself does not upload audio. Wispr and the chosen TTS follow their own privacy paths."
            ))
            .foregroundStyle(.secondary)
            .font(.system(size: 12))
        }
    }

    private func de(_ d: String, _ e: String) -> String {
        model.settings.language == "de" ? d : e
    }
}
