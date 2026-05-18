import Foundation

protocol AIProviderService {
    func send(message: String, in thread: ChatThread, attachments: [FileAttachment]) async throws -> ChatMessage
    func sendStream(message: String, in thread: ChatThread, attachments: [FileAttachment]) -> AsyncThrowingStream<String, Error>
    func fetchAvailableModels(freeOnly: Bool) async throws -> [String]
    func detectTier() async throws -> String
}

enum AIServiceError: LocalizedError {
    case missingAPIKey(provider: Provider)
    case invalidResponse
    case providerNotImplemented
    case httpError(statusCode: Int, message: String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider.displayName). Add it in Settings > API Settings."
        case .invalidResponse:
            return "The provider returned an invalid response."
        case .providerNotImplemented:
            return "Provider is not implemented yet."
        case .httpError(let statusCode, let message):
            return "Provider error \(statusCode): \(message)"
        case .network(let message):
            return message
        }
    }
}

struct LiveProviderService: AIProviderService {
    let provider: Provider

    func send(message: String, in thread: ChatThread, attachments: [FileAttachment]) async throws -> ChatMessage {
        let apiKey = KeychainService.load(key: provider.keychainKey) ?? ""
        if provider != .ollama && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AIServiceError.missingAPIKey(provider: provider)
        }

        let text: String
        var cleanThread = thread
        cleanThread.messages.removeAll { $0.role == .assistant && ($0.text.starts(with: "Thinking…") || $0.text.starts(with: "⚠️")) }
        
        switch provider {
        case .openrouter:
            text = try await openRouterReply(thread: cleanThread, apiKey: apiKey, newAttachments: attachments)
        case .openai:
            text = try await openAIReply(thread: cleanThread, apiKey: apiKey, newAttachments: attachments)
        case .anthropic:
            text = try await anthropicReply(thread: cleanThread, apiKey: apiKey, newAttachments: attachments)
        case .google:
            text = try await googleReply(thread: cleanThread, apiKey: apiKey, newAttachments: attachments)
        case .groq:
            text = try await groqReply(thread: cleanThread, apiKey: apiKey, newAttachments: attachments)
        case .ollama:
            text = try await ollamaReply(thread: cleanThread, apiKey: apiKey, newAttachments: attachments)
        case .mistral:
            text = try await mistralReply(thread: cleanThread, apiKey: apiKey, newAttachments: attachments)
        }

        return ChatMessage(role: .assistant, text: text)
    }

    func sendStream(message: String, in thread: ChatThread, attachments: [FileAttachment]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let apiKey = KeychainService.load(key: provider.keychainKey) ?? ""
                    if provider != .ollama && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        throw AIServiceError.missingAPIKey(provider: provider)
                    }

                    var cleanThread = thread
                    cleanThread.messages.removeAll { $0.role == .assistant && ($0.text.starts(with: "Thinking…") || $0.text.starts(with: "⚠️")) }

                    switch provider {
                    case .openrouter:
                        try await openRouterStream(thread: cleanThread, apiKey: apiKey, newAttachments: attachments, continuation: continuation)
                    case .openai:
                        try await openAIStream(thread: cleanThread, apiKey: apiKey, newAttachments: attachments, continuation: continuation)
                    case .anthropic:
                        try await anthropicStream(thread: cleanThread, apiKey: apiKey, newAttachments: attachments, continuation: continuation)
                    case .google:
                        try await googleStream(thread: cleanThread, apiKey: apiKey, newAttachments: attachments, continuation: continuation)
                    case .groq:
                        try await groqStream(thread: cleanThread, apiKey: apiKey, newAttachments: attachments, continuation: continuation)
                    case .ollama:
                        try await ollamaStream(thread: cleanThread, apiKey: apiKey, newAttachments: attachments, continuation: continuation)
                    case .mistral:
                        try await mistralStream(thread: cleanThread, apiKey: apiKey, newAttachments: attachments, continuation: continuation)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    func fetchAvailableModels(freeOnly: Bool = false) async throws -> [String] {
        let apiKey = KeychainService.load(key: provider.keychainKey) ?? ""
        if provider != .ollama && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AIServiceError.missingAPIKey(provider: provider)
        }

        let isFreeTier: Bool
        do {
            let tier = try await detectTier()
            isFreeTier = tier.lowercased().contains("free")
        } catch {
            isFreeTier = false
        }

        let models: [String]
        switch provider {
        case .openai:
            models = try await fetchOpenAIModels(apiKey: apiKey)
        case .openrouter:
            models = try await fetchOpenRouterModels()
        case .google:
            models = try await fetchGoogleModels(apiKey: apiKey)
        case .groq:
            models = try await fetchGroqModels(apiKey: apiKey)
        case .ollama:
            models = try await fetchOllamaModels(apiKey: apiKey)
        case .mistral:
            models = try await fetchMistralModels(apiKey: apiKey)
        default:
            models = provider.models
        }
        
        if freeOnly || isFreeTier {
            return provider.filterFreeModels(models)
        }
        return models
    }

    func detectTier() async throws -> String {
        let apiKey = KeychainService.load(key: provider.keychainKey) ?? ""
        let hasKey = !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if provider == .ollama { 
            return hasKey ? "Cloud (Keyed)" : "Local (Free)" 
        }
        
        if !hasKey {
            return "Key Missing"
        }
        
        switch provider {
        case .openai:
            // Check if gpt-4 is available
            let models = try? await fetchOpenAIModels(apiKey: apiKey)
            if let models = models, models.contains(where: { $0.contains("gpt-4") && !$0.contains("mini") }) {
                return "Paid Tier"
            }
            return "Free Tier"
        case .google:
            // Google AI Studio keys are generally free tier unless billing is attached
            return "Free/Standard Tier"
        case .groq:
            return "Beta (Free)"
        case .ollama:
            return "Local (Free)"
        case .openrouter:
            // Hit their auth info endpoint to verify the key and get some data
            let url = URL(string: "https://openrouter.ai/api/v1/auth/key")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
            request.setValue("https://openrouter.ai", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Ai Nexus", forHTTPHeaderField: "X-Title")
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { 
                    return "Invalid Key" 
                }
                struct OpenRouterAuthResponse: Codable {
                    struct Data: Codable {
                        let limit: Double?
                        let usage: Double?
                    }
                    let data: Data
                }
                let decoded = try JSONDecoder().decode(OpenRouterAuthResponse.self, from: data)
                if let limit = decoded.data.limit, let usage = decoded.data.usage {
                    let remaining = limit - usage
                    return "Active ($\(String(format: "%.2f", remaining)) left)"
                }
                return "Active"
            } catch {
                return "Verification Failed"
            }
        case .mistral:
            let models = try? await fetchMistralModels(apiKey: apiKey)
            if let models = models, !models.isEmpty {
                return "Active"
            }
            return "Free Tier"
        default:
            return "Active"
        }
    }

    // MARK: - Mistral Helpers
    
    private func mistralReply(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment]) async throws -> String {
        let messages = buildOpenAIMessages(thread: thread, newAttachments: newAttachments)
        let payload = OpenAIStyleRequest(model: thread.modelID, messages: messages)
        
        return try await openAICompatibleReply(
            url: URL(string: "https://api.mistral.ai/v1/chat/completions")!,
            apiKey: apiKey,
            payload: payload
        )
    }

    private func mistralStream(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment], continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let messages = buildOpenAIMessages(thread: thread, newAttachments: newAttachments)
        let payload = OpenAIStyleRequest(model: thread.modelID, messages: messages)
        try await openAICompatibleStream(url: URL(string: "https://api.mistral.ai/v1/chat/completions")!, apiKey: apiKey, payload: payload, continuation: continuation)
    }

    private func fetchMistralModels(apiKey: String) async throws -> [String] {
        var request = URLRequest(url: URL(string: "https://api.mistral.ai/v1/models")!)
        request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AIServiceError.invalidResponse }
        
        struct MistralModelsResponse: Codable {
            struct Model: Codable { let id: String }
            let data: [Model]
        }
        
        let decoded = try JSONDecoder().decode(MistralModelsResponse.self, from: data)
        return decoded.data.map { $0.id }.sorted()
    }

    private func fetchOpenAIModels(apiKey: String) async throws -> [String] {
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/models")!)
        request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AIServiceError.invalidResponse }
        
        struct OpenAIModelsResponse: Codable {
            struct Model: Codable { let id: String }
            let data: [Model]
        }
        
        let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
        return decoded.data.map { $0.id }.sorted()
    }

    private func fetchOpenRouterModels() async throws -> [String] {
        guard let url = URL(string: "https://openrouter.ai/api/v1/models") else { throw AIServiceError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // OpenRouter recommends these headers even for GET
        request.setValue("https://openrouter.ai", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Ai Nexus", forHTTPHeaderField: "X-Title")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AIServiceError.invalidResponse }
        
        let decoded = try JSONDecoder().decode(OpenRouterModelResponse.self, from: data)
        return decoded.data.map { $0.id }.sorted()
    }

    private func fetchGoogleModels(apiKey: String) async throws -> [String] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
        let (data, response) = try await URLSession.shared.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AIServiceError.invalidResponse }
        
        struct GoogleModelsResponse: Codable {
            struct Model: Codable { let name: String }
            let models: [Model]
        }
        
        let decoded = try JSONDecoder().decode(GoogleModelsResponse.self, from: data)
        return decoded.models.map { $0.name.replacingOccurrences(of: "models/", with: "") }.sorted()
    }

    private func ollamaReply(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment]) async throws -> String {
        let rawBaseUrl = UserDefaults.standard.string(forKey: StorageKeys.providerBaseUrlKey(for: Provider.ollama.rawValue)) ?? "http://127.0.0.1:11434"
        let baseUrl = rawBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Support OpenAI-compatible Cloud Ollama endpoints (e.g., URL ends in /v1)
        if baseUrl.hasSuffix("/v1") {
            let messages = buildOpenAIMessages(thread: thread, newAttachments: newAttachments)
            let payload = OpenAIStyleRequest(model: thread.modelID, messages: messages)
            return try await openAICompatibleReply(url: URL(string: "\(baseUrl)/chat/completions")!, apiKey: apiKey, payload: payload)
        }
        
        let url = URL(string: "\(baseUrl)/api/chat")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        
        let messages = thread.messages.map { msg -> OllamaRequest.Message in
            // Ollama support for images is via base64 strings in a 'images' array
            var images: [String]? = nil
            let isCurrent = (msg.role == .user && msg == thread.messages.last && !newAttachments.isEmpty)
            let atts = isCurrent ? newAttachments : (msg.attachments ?? [])
            let imageAtts = atts.filter { $0.mimeType.starts(with: "image/") }
            if !imageAtts.isEmpty {
                images = imageAtts.map { $0.base64Data }
            }
            
            return .init(role: mapOpenAIRole(msg.role), content: msg.text, images: images)
        }
        
        let payload = OllamaRequest(model: thread.modelID, messages: messages, stream: false)
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw buildHTTPError(from: data, statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500)
        }
        
        let decoded = try JSONDecoder().decode(OllamaResponse.self, from: data)
        return decoded.message.content
    }

    private func ollamaStream(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment], continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let rawBaseUrl = UserDefaults.standard.string(forKey: StorageKeys.providerBaseUrlKey(for: Provider.ollama.rawValue)) ?? "http://127.0.0.1:11434"
        let baseUrl = rawBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        if baseUrl.hasSuffix("/v1") {
            let messages = buildOpenAIMessages(thread: thread, newAttachments: newAttachments)
            let payload = OpenAIStyleRequest(model: thread.modelID, messages: messages)
            try await openAICompatibleStream(url: URL(string: "\(baseUrl)/chat/completions")!, apiKey: apiKey, payload: payload, continuation: continuation)
            return
        }
        
        let url = URL(string: "\(baseUrl)/api/chat")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        
        let messages = thread.messages.map { msg -> OllamaRequest.Message in
            var images: [String]? = nil
            let isCurrent = (msg.role == .user && msg == thread.messages.last && !newAttachments.isEmpty)
            let atts = isCurrent ? newAttachments : (msg.attachments ?? [])
            let imageAtts = atts.filter { $0.mimeType.starts(with: "image/") }
            if !imageAtts.isEmpty { images = imageAtts.map { $0.base64Data } }
            return .init(role: mapOpenAIRole(msg.role), content: msg.text, images: images)
        }
        
        let payload = OllamaRequest(model: thread.modelID, messages: messages, stream: true)
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AIServiceError.httpError(statusCode: http.statusCode, message: "Stream failed") }
        
        for try await line in bytes.lines {
            guard let data = line.data(using: .utf8) else { continue }
            if let decoded = try? JSONDecoder().decode(OllamaResponse.self, from: data) {
                continuation.yield(decoded.message.content)
            }
        }
    }

    private func fetchOllamaModels(apiKey: String) async throws -> [String] {
        let rawBaseUrl = UserDefaults.standard.string(forKey: StorageKeys.providerBaseUrlKey(for: Provider.ollama.rawValue)) ?? "http://127.0.0.1:11434"
        let baseUrl = rawBaseUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        // Support OpenAI-compatible Cloud Ollama endpoints (e.g., URL ends in /v1)
        if baseUrl.hasSuffix("/v1") {
            let url = URL(string: "\(baseUrl)/models")!
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AIServiceError.invalidResponse }
                struct OpenAIModelsResponse: Codable {
                    struct Model: Codable { let id: String }
                    let data: [Model]
                }
                let decoded = try JSONDecoder().decode(OpenAIModelsResponse.self, from: data)
                return decoded.data.map { $0.id }.sorted()
            } catch {
                if (error as NSError).domain == NSURLErrorDomain {
                    throw AIServiceError.network("Could not connect to Cloud Ollama at \(baseUrl). If using a physical device, ensure you use your Mac's local IP (e.g., 192.168.x.x) and not 127.0.0.1.")
                }
                throw error
            }
        }
        
        let url = URL(string: "\(baseUrl)/api/tags")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AIServiceError.invalidResponse }
            
            struct OllamaTagsResponse: Codable {
                struct Model: Codable { let name: String }
                let models: [Model]
            }
            
            let decoded = try JSONDecoder().decode(OllamaTagsResponse.self, from: data)
            return decoded.models.map { $0.name }.sorted()
        } catch {
            if (error as NSError).domain == NSURLErrorDomain {
                throw AIServiceError.network("Could not connect to Ollama. Ensure it's running at \(baseUrl). If on a physical iOS device, use your Mac's local IP (e.g., http://192.168.x.x:11434) and set OLLAMA_HOST=0.0.0.0 on your Mac.")
            }
            throw error
        }
    }

    private func openRouterReply(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment]) async throws -> String {
        let messages = buildOpenAIMessages(thread: thread, newAttachments: newAttachments)
        let payload = OpenAIStyleRequest(model: thread.modelID, messages: messages)
        
        return try await openAICompatibleReply(
            url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!,
            apiKey: apiKey,
            payload: payload
        )
    }

    private func openRouterStream(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment], continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let messages = buildOpenAIMessages(thread: thread, newAttachments: newAttachments)
        let payload = OpenAIStyleRequest(model: thread.modelID, messages: messages)
        try await openAICompatibleStream(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!, apiKey: apiKey, payload: payload, continuation: continuation)
    }

    private func openAIReply(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment]) async throws -> String {
        let messages = buildOpenAIMessages(thread: thread, newAttachments: newAttachments)
        let payload = OpenAIStyleRequest(model: thread.modelID, messages: messages)
        
        return try await openAICompatibleReply(
            url: URL(string: "https://api.openai.com/v1/chat/completions")!,
            apiKey: apiKey,
            payload: payload
        )
    }

    private func openAIStream(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment], continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let messages = buildOpenAIMessages(thread: thread, newAttachments: newAttachments)
        let payload = OpenAIStyleRequest(model: thread.modelID, messages: messages)
        try await openAICompatibleStream(url: URL(string: "https://api.openai.com/v1/chat/completions")!, apiKey: apiKey, payload: payload, continuation: continuation)
    }

    private func groqReply(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment]) async throws -> String {
        let messages = buildOpenAIMessages(thread: thread, newAttachments: newAttachments)
        let payload = OpenAIStyleRequest(model: thread.modelID, messages: messages)
        
        return try await openAICompatibleReply(
            url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!,
            apiKey: apiKey,
            payload: payload
        )
    }

    private func fetchGroqModels(apiKey: String) async throws -> [String] {
        var request = URLRequest(url: URL(string: "https://api.groq.com/openai/v1/models")!)
        request.setValue("Bearer \(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw AIServiceError.invalidResponse }
        
        struct GroqModelsResponse: Codable {
            struct Model: Codable { let id: String }
            let data: [Model]
        }
        
        let decoded = try JSONDecoder().decode(GroqModelsResponse.self, from: data)
        return decoded.data.map { $0.id }.sorted()
    }

    private func buildOpenAIMessages(thread: ChatThread, newAttachments: [FileAttachment]) -> [OpenAIStyleRequest.Message] {
        return thread.messages.map { msg in
            let role = mapOpenAIRole(msg.role)
            let isCurrentNewMessage = (msg.role == .user && msg == thread.messages.last && !newAttachments.isEmpty)
            
            if isCurrentNewMessage || !(msg.attachments?.isEmpty ?? true) {
                var parts: [OpenAIStyleRequest.Part] = []
                if !msg.text.isEmpty {
                    parts.append(.init(type: "text", text: msg.text))
                }
                
                let atts = isCurrentNewMessage ? newAttachments : (msg.attachments ?? [])
                for att in atts where att.mimeType.starts(with: "image/") {
                    parts.append(.init(type: "image_url", image_url: .init(url: "data:\(att.mimeType);base64,\(att.base64Data)")))
                }
                
                return .init(role: role, content: .parts(parts))
            } else {
                return .init(role: role, content: .text(msg.text))
            }
        }
    }

    private func groqStream(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment], continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let messages = buildOpenAIMessages(thread: thread, newAttachments: newAttachments)
        let payload = OpenAIStyleRequest(model: thread.modelID, messages: messages)
        try await openAICompatibleStream(url: URL(string: "https://api.groq.com/openai/v1/chat/completions")!, apiKey: apiKey, payload: payload, continuation: continuation)
    }

    private func openAICompatibleReply(url: URL, apiKey: String, payload: OpenAIStyleRequest) async throws -> String {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // OpenRouter specific headers
        if url.absoluteString.contains("openrouter.ai") {
            request.setValue("https://openrouter.ai", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Ai Nexus", forHTTPHeaderField: "X-Title")
        }

        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(payload)
        logRequest(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            logURLError(urlError, request: request)
            throw AIServiceError.network("Network error (\(urlError.code.rawValue)): \(urlError.localizedDescription)")
        } catch {
            print("[Network] Non-URLError: \(error.localizedDescription)")
            throw AIServiceError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw buildHTTPError(from: data, statusCode: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(OpenAIStyleResponse.self, from: data)
        guard let text = decoded.choices.first?.message.content, !text.isEmpty else {
            throw AIServiceError.invalidResponse
        }
        return text
    }

    private func anthropicStream(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment], continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let messages: [AnthropicRequest.Message] = thread.messages
            .filter { $0.role == .user || $0.role == .assistant }
            .map { msg in
                let role = msg.role == .assistant ? "assistant" : "user"
                let isCurrent = (msg.role == .user && msg == thread.messages.last && !newAttachments.isEmpty)
                
                if isCurrent || !(msg.attachments?.isEmpty ?? true) {
                    var parts: [AnthropicRequest.Part] = []
                    if !msg.text.isEmpty {
                        parts.append(.init(type: "text", text: msg.text))
                    }
                    let atts = isCurrent ? newAttachments : (msg.attachments ?? [])
                    for att in atts where att.mimeType.starts(with: "image/") {
                        let mediaType = att.mimeType
                        parts.append(.init(type: "image", source: .init(type: "base64", media_type: mediaType, data: att.base64Data)))
                    }
                    return .init(role: role, content: .parts(parts))
                } else {
                    return .init(role: role, content: .text(msg.text))
                }
            }

        let payload = AnthropicRequest(
            model: thread.modelID,
            max_tokens: 4096,
            messages: messages,
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AIServiceError.httpError(statusCode: http.statusCode, message: "Stream failed") }
        
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let dataString = line.dropFirst(6)
            guard let data = dataString.data(using: .utf8) else { continue }
            if let decoded = try? JSONDecoder().decode(AnthropicStreamResponse.self, from: data) {
                if decoded.type == "content_block_delta", let text = decoded.delta?.text {
                    continuation.yield(text)
                }
            }
        }
    }

    private func anthropicReply(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment]) async throws -> String {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let messages: [AnthropicRequest.Message] = thread.messages
            .filter { $0.role == .user || $0.role == .assistant }
            .map { msg in
                let role = msg.role == .assistant ? "assistant" : "user"
                let isCurrent = (msg.role == .user && msg == thread.messages.last && !newAttachments.isEmpty)
                
                if isCurrent || !(msg.attachments?.isEmpty ?? true) {
                    var parts: [AnthropicRequest.Part] = []
                    if !msg.text.isEmpty {
                        parts.append(.init(type: "text", text: msg.text))
                    }
                    let atts = isCurrent ? newAttachments : (msg.attachments ?? [])
                    for att in atts where att.mimeType.starts(with: "image/") {
                        // Anthropic format is slightly different for images
                        let mediaType = att.mimeType // image/jpeg, image/png, etc.
                        parts.append(.init(type: "image", source: .init(type: "base64", media_type: mediaType, data: att.base64Data)))
                    }
                    return .init(role: role, content: .parts(parts))
                } else {
                    return .init(role: role, content: .text(msg.text))
                }
            }

        let payload = AnthropicRequest(
            model: thread.modelID,
            max_tokens: 4096,
            messages: messages
        )
        request.httpBody = try JSONEncoder().encode(payload)
        logRequest(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            logURLError(urlError, request: request)
            throw AIServiceError.network("Network error (\(urlError.code.rawValue)): \(urlError.localizedDescription)")
        } catch {
            print("[Network] Non-URLError: \(error.localizedDescription)")
            throw AIServiceError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw buildHTTPError(from: data, statusCode: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let text = decoded.content.first(where: { $0.type == "text" })?.text ?? ""
        guard !text.isEmpty else { throw AIServiceError.invalidResponse }
        return text
    }

    private func googleStream(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment], continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(thread.modelID):streamGenerateContent?alt=sse&key=\(apiKey)"
        guard let url = URL(string: endpoint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? endpoint) else {
            throw AIServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var contents: [GoogleRequest.Content] = []
        for msg in thread.messages {
            let role = msg.role == .assistant ? "model" : "user"
            var parts: [GoogleRequest.Part] = []
            
            if !msg.text.isEmpty {
                parts.append(.init(text: msg.text))
            }
            
            let isCurrent = (msg.role == .user && msg == thread.messages.last && !newAttachments.isEmpty)
            let atts = isCurrent ? newAttachments : (msg.attachments ?? [])
            for att in atts where att.mimeType.starts(with: "image/") {
                parts.append(.init(inline_data: .init(mime_type: att.mimeType, data: att.base64Data)))
            }
            
            if !parts.isEmpty {
                contents.append(.init(role: role, parts: parts))
            }
        }

        let payload = GoogleRequest(contents: contents)
        request.httpBody = try JSONEncoder().encode(payload)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else { throw AIServiceError.httpError(statusCode: http.statusCode, message: "Stream failed") }
        
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let dataString = line.dropFirst(6)
            guard let data = dataString.data(using: .utf8) else { continue }
            if let decoded = try? JSONDecoder().decode(GoogleResponse.self, from: data) {
                let candidate = decoded.candidates.first
                let parts = candidate?.content.parts ?? []
                let text = parts.filter { $0.thought == nil }.compactMap { $0.text }.joined()
                if !text.isEmpty {
                    continuation.yield(text)
                }
            }
        }
    }

    private func googleReply(thread: ChatThread, apiKey: String, newAttachments: [FileAttachment]) async throws -> String {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(thread.modelID):generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? endpoint) else {
            throw AIServiceError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Google Gemini format: list of contents, each with parts
        var contents: [GoogleRequest.Content] = []
        
        for msg in thread.messages {
            let role = msg.role == .assistant ? "model" : "user"
            var parts: [GoogleRequest.Part] = []
            
            // Text part
            if !msg.text.isEmpty {
                parts.append(.init(text: msg.text))
            }
            
            // Image parts
            let isCurrent = (msg.role == .user && msg == thread.messages.last && !newAttachments.isEmpty)
            let atts = isCurrent ? newAttachments : (msg.attachments ?? [])
            for att in atts where att.mimeType.starts(with: "image/") {
                parts.append(.init(inline_data: .init(mime_type: att.mimeType, data: att.base64Data)))
            }
            
            if !parts.isEmpty {
                contents.append(.init(role: role, parts: parts))
            }
        }

        let payload = GoogleRequest(contents: contents)
        request.httpBody = try JSONEncoder().encode(payload)
        logRequest(request)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let urlError as URLError {
            logURLError(urlError, request: request)
            throw AIServiceError.network("Network error (\(urlError.code.rawValue)): \(urlError.localizedDescription)")
        } catch {
            print("[Network] Non-URLError: \(error.localizedDescription)")
            throw AIServiceError.network(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw buildHTTPError(from: data, statusCode: http.statusCode)
        }

        let decoded = try JSONDecoder().decode(GoogleResponse.self, from: data)
        let candidate = decoded.candidates.first
        let parts = candidate?.content.parts ?? []
        
        // Filter out parts that are explicitly marked as thoughts/reasoning
        // and join the remaining text parts.
        let responseText = parts
            .filter { $0.thought == nil }
            .compactMap { $0.text }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            
        guard !responseText.isEmpty else {
            // Fallback: if there's ONLY a thought/text and we filtered everything, 
            // just take the first available text.
            let fallback = parts.compactMap { $0.text }.first ?? ""
            guard !fallback.isEmpty else { throw AIServiceError.invalidResponse }
            return fallback
        }
        return responseText
    }

    private func mapOpenAIRole(_ role: MessageRole) -> String {
        switch role {
        case .user: return "user"
        case .assistant: return "assistant"
        case .system: return "system"
        }
    }

    private func buildHTTPError(from data: Data, statusCode: Int) -> Error {
        if statusCode == 401 {
            return AIServiceError.httpError(statusCode: statusCode, message: "Invalid API Key or Unauthorized. Please check your settings.")
        }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return AIServiceError.httpError(statusCode: statusCode, message: message)
        }
        return AIServiceError.httpError(statusCode: statusCode, message: "HTTP Error \(statusCode)")
    }

    private func parseErrorMessage(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return String(data: data, encoding: .utf8)
        }

        if let error = json["error"] as? [String: Any] {
            if let message = error["message"] as? String { return message }
            if let detail = error["detail"] as? String { return detail }
            if let code = error["code"] as? String { return code }
        }
        if let message = json["message"] as? String { return message }
        if let detail = json["detail"] as? String { return detail }
        return nil
    }

    private func logRequest(_ request: URLRequest) {
        let urlString = request.url?.absoluteString ?? "<nil>"
        let method = request.httpMethod ?? "GET"
        let headers = request.allHTTPHeaderFields ?? [:]
        let maskedHeaders = headers.reduce(into: [String: String]()) { partial, item in
            if item.key.caseInsensitiveCompare("Authorization") == .orderedSame {
                partial[item.key] = maskCredential(item.value)
            } else if item.key.caseInsensitiveCompare("x-api-key") == .orderedSame {
                partial[item.key] = maskCredential(item.value)
            } else {
                partial[item.key] = item.value
            }
        }

        print("[Network] URL: \(urlString)")
        print("[Network] Method: \(method)")
        print("[Network] Headers: \(maskedHeaders)")
    }

    private func logURLError(_ error: URLError, request: URLRequest) {
        let urlString = request.url?.absoluteString ?? "<nil>"
        print("[Network] URLError code: \(error.code.rawValue) (\(error.code))")
        print("[Network] URLError description: \(error.localizedDescription)")
        print("[Network] Request URL: \(urlString)")
        if let failingURL = error.userInfo[NSURLErrorFailingURLErrorKey] as? URL {
            print("[Network] Failing URL: \(failingURL.absoluteString)")
        }
    }

    private func maskCredential(_ value: String) -> String {
        guard !value.isEmpty else { return "<empty>" }
        if value.count <= 8 { return "<redacted>" }
        let prefix = value.prefix(4)
        let suffix = value.suffix(4)
        return "\(prefix)****\(suffix)"
    }
}

struct AIServiceFactory {
    static func service(for provider: Provider) -> AIProviderService {
        LiveProviderService(provider: provider)
    }
}

// -----------------------------------------------------------------------------
// MARK: - Request DTOs (Multi-Modal)

private struct OpenAIStyleRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: Content
    }
    
    enum Content: Codable {
        case text(String)
        case parts([Part])
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let s): try container.encode(s)
            case .parts(let p): try container.encode(p)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) {
                self = .text(s)
            } else if let p = try? container.decode([Part].self) {
                self = .parts(p)
            } else {
                throw DecodingError.typeMismatch(Content.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected String or [Part]"))
            }
        }
    }
    
    struct Part: Codable {
        let type: String
        var text: String? = nil
        var image_url: ImageURL? = nil
    }
    
    struct ImageURL: Codable {
        let url: String // data:image/jpeg;base64,xxxx
    }
    
    let model: String
    let messages: [Message]
    var stream: Bool? = nil
}

private struct OpenAIStyleResponse: Codable {
    struct Choice: Codable {
        struct Message: Codable {
            let role: String?
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

private struct OpenAIStreamResponse: Codable {
    struct Choice: Codable {
        struct Delta: Codable {
            let content: String?
        }
        let delta: Delta
    }
    let choices: [Choice]
}

extension LiveProviderService {
    private func openAICompatibleStream(url: URL, apiKey: String, payload: OpenAIStyleRequest, continuation: AsyncThrowingStream<String, Error>.Continuation) async throws {
        var payload = payload
        payload.stream = true
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // OpenRouter specific headers
        if url.absoluteString.contains("openrouter.ai") {
            request.setValue("https://openrouter.ai", forHTTPHeaderField: "HTTP-Referer")
            request.setValue("Ai Nexus", forHTTPHeaderField: "X-Title")
        }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty { 
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization") 
        }
        request.httpBody = try JSONEncoder().encode(payload)
        
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIServiceError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            var errorData = Data()
            do {
                for try await byte in bytes {
                    errorData.append(byte)
                }
            } catch {}
            
            let message = parseErrorMessage(from: errorData) ?? "Stream failed"
            throw AIServiceError.httpError(statusCode: http.statusCode, message: message)
        }
        
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let dataString = line.dropFirst(6)
            if dataString.trimmingCharacters(in: .whitespacesAndNewlines) == "[DONE]" { break }
            guard let data = dataString.data(using: .utf8) else { continue }
            if let decoded = try? JSONDecoder().decode(OpenAIStreamResponse.self, from: data),
               let delta = decoded.choices.first?.delta.content {
                continuation.yield(delta)
            }
        }
    }
}

private struct AnthropicRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: Content
    }
    
    enum Content: Codable {
        case text(String)
        case parts([Part])
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let s): try container.encode(s)
            case .parts(let p): try container.encode(p)
            }
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) {
                self = .text(s)
            } else if let p = try? container.decode([Part].self) {
                self = .parts(p)
            } else {
                throw DecodingError.typeMismatch(Content.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected String or [Part]"))
            }
        }
    }
    
    struct Part: Codable {
        let type: String
        var text: String? = nil
        var source: ImageSource? = nil
    }
    
    struct ImageSource: Codable {
        let type: String // base64
        let media_type: String
        let data: String
    }
    
    let model: String
    let max_tokens: Int
    let messages: [Message]
    var stream: Bool? = nil
}

private struct AnthropicResponse: Codable {
    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }
    let content: [ContentBlock]
}

private struct AnthropicStreamResponse: Codable {
    let type: String
    struct Delta: Codable {
        let type: String?
        let text: String?
    }
    let delta: Delta?
}



private struct GoogleRequest: Codable {
    struct Content: Codable {
        let role: String?
        let parts: [Part]
    }
    
    struct Part: Codable {
        var text: String? = nil
        var inline_data: InlineData? = nil
    }
    
    struct InlineData: Codable {
        let mime_type: String
        let data: String
    }
    
    let contents: [Content]
}

private struct GoogleResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String?
                let thought: Bool? // Some APIs use a flag
                let thoughtText: String? // Some use a different field name
                
                enum CodingKeys: String, CodingKey {
                    case text, thought
                    case thoughtText = "thought_text"
                }
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}

// MARK: - Ollama DTOs
struct OllamaRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
        let images: [String]?
    }
    let model: String
    let messages: [Message]
    let stream: Bool
}

struct OllamaResponse: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }
    let model: String
    let created_at: String
    let message: Message
    let done: Bool
}
