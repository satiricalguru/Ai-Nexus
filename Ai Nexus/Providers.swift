import Foundation

enum Provider: String, CaseIterable, Codable, Identifiable {
    case openai
    case anthropic
    case google
    case openrouter
    case groq
    case ollama
    case mistral

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic"
        case .google: return "Google"
        case .openrouter: return "OpenRouter"
        case .groq: return "Groq"
        case .ollama: return "Ollama"
        case .mistral: return "Mistral AI"
        }
    }

    var iconName: String {
        switch self {
        case .openai: return "square.grid.3x3.fill"
        case .anthropic: return "aqi.medium"
        case .google: return "g.circle.fill"
        case .openrouter: return "bolt.shield.fill"
        case .groq: return "cpu.fill"
        case .ollama: return "terminal.fill"
        case .mistral: return "wind"
        }
    }

    var subtitle: String {
        switch self {
        case .openai: return "GPT models"
        case .anthropic: return "Claude models"
        case .google: return "Gemini models"
        case .openrouter: return "OpenRouter models"
        case .groq: return "Groq Cloud models"
        case .ollama: return "Local models via Ollama"
        case .mistral: return "Mistral & Pixtral models"
        }
    }

    var models: [String] {
        switch self {
        case .openai:
            return ["gpt-4.1", "gpt-4.1-mini", "gpt-4o-mini"]
        case .anthropic:
            return ["claude-3.7-sonnet", "claude-3.5-haiku"]
        case .google:
            return ["gemini-2.5-pro", "gemini-2.5-flash", "gemini-2.0-flash", "gemini-2.0-flash-lite", "gemini-1.5-pro", "gemini-1.5-flash", "gemini-1.5-flash-8b"]
        case .openrouter:
            return ["openrouter/auto", "deepseek/deepseek-chat", "qwen/qwen-2.5-coder-32b"]
        case .groq:
            return ["llama-3.3-70b-versatile", "llama-3.1-8b-instant", "mixtral-8x7b-32768", "gemma2-9b-it"]
        case .ollama:
            return ["llama3", "mistral", "phi3"]
        case .mistral:
            return ["mistral-large-latest", "pixtral-large-latest", "mistral-small-latest", "ministral-8b-latest"]
        }
    }

    var keychainKey: String {
        "api.provider.\(rawValue).key"
    }

    func filterFreeModels(_ models: [String]) -> [String] {
        switch self {
        case .openrouter:
            // For OpenRouter we can't easily filter by cost here without re-fetching full catalog,
            // but we can look for ":free" suffix which is their convention.
            return models.filter { $0.lowercased().contains(":free") }
        case .google:
            // Gemini Flash models have a generous free tier.
            return models.filter { $0.lowercased().contains("flash") || $0.lowercased().contains("lite") }
        case .openai:
            // 'mini' models are the most budget-friendly/free-credit friendly.
            return models.filter { $0.lowercased().contains("mini") || $0.lowercased().contains("3.5") }
        case .groq:
            // Groq is currently free/beta for many users.
            return models
        case .mistral:
            return models.filter { $0.lowercased().contains("small") || $0.lowercased().contains("8b") || $0.lowercased().contains("free") }
        default:
            return models
        }
    }
}

struct ProviderConfig: Identifiable, Codable, Hashable {
    let id: UUID
    var provider: Provider
    var selectedModel: String

    init(id: UUID = UUID(), provider: Provider, selectedModel: String? = nil) {
        self.id = id
        self.provider = provider
        self.selectedModel = selectedModel ?? provider.models.first ?? ""
    }
}
