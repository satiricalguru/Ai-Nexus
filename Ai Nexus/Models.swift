import Foundation

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let role: MessageRole
    var text: String
    let createdAt: Date
    let attachments: [FileAttachment]?
    var isLiked: Bool? = false
    var isDisliked: Bool? = false

    init(id: UUID = UUID(), role: MessageRole, text: String, createdAt: Date = .now, attachments: [FileAttachment]? = nil, isLiked: Bool? = false, isDisliked: Bool? = false) {
        self.id = id
        self.role = role
        self.text = text
        self.createdAt = createdAt
        self.attachments = attachments
        self.isLiked = isLiked
        self.isDisliked = isDisliked
    }
}

struct FileAttachment: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    let fileName: String
    let mimeType: String
    let base64Data: String
}

enum MessageRole: String, Codable, CaseIterable {
    case user
    case assistant
    case system
}

struct ChatThread: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var provider: Provider
    var modelID: String
    var createdAt: Date
    var messages: [ChatMessage]

    init(
        id: UUID = UUID(),
        title: String = "New Chat",
        provider: Provider = .openrouter,
        modelID: String = "openrouter/auto",
        createdAt: Date = .now,
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.title = title
        self.provider = provider
        self.modelID = modelID
        self.createdAt = createdAt
        self.messages = messages
    }
}

struct PromptItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var text: String
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, text: String, updatedAt: Date = .now) {
        self.id = id
        self.title = title
        self.text = text
        self.updatedAt = updatedAt
    }
}

extension ChatThread {
    static let mock: ChatThread = {
        ChatThread(
            title: "Product Brainstorm",
            provider: .openai,
            modelID: "gpt-4.1-mini",
            messages: [
                ChatMessage(role: .user, text: "Can you help me plan a settings-driven chat app?", createdAt: .now.addingTimeInterval(-3600)),
                ChatMessage(role: .assistant, text: "Yes. Start with MVVM, provider abstraction, and a robust settings system.", createdAt: .now.addingTimeInterval(-3500)),
                ChatMessage(role: .user, text: "Great. Keep the UI modern and dark-themed.", createdAt: .now.addingTimeInterval(-3400))
            ]
        )
    }()
}

extension PromptItem {
    static let mock: [PromptItem] = [
        PromptItem(title: "Summarize", text: "Summarize the following in 5 bullets."),
        PromptItem(title: "Code Review", text: "Review this Swift code for bugs and architecture issues.")
    ]
}

struct OpenRouterModelResponse: Codable {
    let data: [OpenRouterModel]
}

struct OpenRouterModel: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let pricing: ModelPricing?
}

struct ModelPricing: Codable, Hashable {
    let prompt: String?
    let completion: String?
}
