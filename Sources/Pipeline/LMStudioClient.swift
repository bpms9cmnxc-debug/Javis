import Foundation
import AppKit

struct ChatTurn: Identifiable, Equatable {
    let id: UUID
    var role: String
    var content: String
    init(id: UUID = UUID(), role: String, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

enum LMStudioClient {
    struct Reply {
        var text: String
        var model: String
    }

    static func listModels(baseURL: String, apiKey: String) async -> [String] {
        guard let url = URL(string: baseURL.hasSuffix("/") ? baseURL + "models" : baseURL + "/models") else { return [] }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 3
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArr = json["data"] as? [[String: Any]] {
                return dataArr.compactMap { $0["id"] as? String }
            }
        } catch {
            JLog.error("models: \(error.localizedDescription)")
        }
        return []
    }

    static func isReachable(baseURL: String, apiKey: String) async -> Bool {
        !(await listModels(baseURL: baseURL, apiKey: apiKey).isEmpty) || await ping(baseURL: baseURL)
    }

    static func ping(_ baseURL: String) async -> Bool {
        let root = baseURL.replacingOccurrences(of: "/v1", with: "")
        guard let url = URL(string: root) else { return false }
        var req = URLRequest(url: url)
        req.timeoutInterval = 2
        do {
            _ = try await URLSession.shared.data(for: req)
            return true
        } catch { return false }
    }

    static func startServerIfNeeded() {
        let candidates = [
            NSHomeDirectory() + "/.lmstudio/bin/lms",
            "/usr/local/bin/lms",
            "/opt/homebrew/bin/lms",
        ]
        guard let bin = candidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            JLog.info("lms CLI nicht gefunden")
            return
        }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: bin)
        proc.arguments = ["server", "start"]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch {
            JLog.error("lms start: \(error.localizedDescription)")
        }
    }

    static func launchApp(bundleIds: [String]) {
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

    static func stream(
        baseURL: String,
        apiKey: String,
        model: String,
        systemPrompt: String,
        history: [ChatTurn],
        user: String,
        temperature: Double,
        maxTokens: Int,
        onDelta: @escaping (String) -> Void
    ) async throws -> Reply {
        guard let url = URL(string: baseURL.hasSuffix("/") ? baseURL + "chat/completions" : baseURL + "/chat/completions") else {
            throw URLError(.badURL)
        }
        var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for turn in history.suffix(16) {
            messages.append(["role": turn.role, "content": turn.content])
        }
        messages.append(["role": "user", "content": user])

        var body: [String: Any] = [
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": true,
        ]
        if !model.isEmpty { body["model"] = model }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120

        let (bytes, response) = try await URLSession.shared.bytes(for: req)
        if let http = response as? HTTPURLResponse, http.statusCode >= 400 {
            throw NSError(domain: "LMStudio", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "LM Studio HTTP \(http.statusCode)"])
        }

        var full = ""
        var usedModel = model
        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data:") else { continue }
            let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { continue }
            if let m = json["model"] as? String, !m.isEmpty { usedModel = m }
            if let choices = json["choices"] as? [[String: Any]],
               let delta = choices.first?["delta"] as? [String: Any],
               let content = delta["content"] as? String, !content.isEmpty {
                full += content
                onDelta(full)
            }
        }
        return Reply(text: full.trimmingCharacters(in: .whitespacesAndNewlines), model: usedModel)
    }
}
