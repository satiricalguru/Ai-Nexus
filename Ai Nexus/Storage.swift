import Foundation

enum StorageKeys {
    static let appTheme = "settings.appTheme"
    static let appColourScheme = "settings.appColourScheme"
    static let lightAccentHex = "settings.lightAccentHex"
    static let darkAccentHex = "settings.darkAccentHex"
    static let fontSize = "settings.fontSize"
    static let syntaxHighlighting = "settings.syntaxHighlighting"
    static let codeColourScheme = "settings.codeColourScheme"

    static let autoRenameChat = "settings.autoRenameChat"
    static let hapticFeedback = "settings.hapticFeedback"
    static let enableImageGeneration = "settings.enableImageGeneration"
    static let enableVisionFiles = "settings.enableVisionFiles"

    static let prompts = "storage.prompts"
    static let defaultProvider = "settings.defaultProvider"
    static let providerModels = "settings.providerModels"
    
    static func providerEnabledKey(for provider: String) -> String { "settings.provider.\(provider).enabled" }
    static func providerIdentityKey(for provider: String) -> String { "settings.provider.\(provider).identity" }
    static func providerFreeOnlyKey(for provider: String) -> String { "settings.provider.\(provider).freeOnly" }
    static func providerPromptKey(for provider: String) -> String { "settings.provider.\(provider).prompt" }
    static func providerBaseUrlKey(for provider: String) -> String { "settings.provider.\(provider).baseUrl" }
}

struct PromptLibraryStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [PromptItem] {
        guard let data = defaults.data(forKey: StorageKeys.prompts) else { return [] }
        return (try? JSONDecoder().decode([PromptItem].self, from: data)) ?? []
    }

    func save(_ prompts: [PromptItem]) {
        guard let data = try? JSONEncoder().encode(prompts) else { return }
        defaults.set(data, forKey: StorageKeys.prompts)
    }
}

struct ProviderModelStore {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> [Provider: String] {
        let raw = defaults.dictionary(forKey: StorageKeys.providerModels) as? [String: String] ?? [:]
        var mapped: [Provider: String] = [:]
        for (key, value) in raw {
            if let provider = Provider(rawValue: key) {
                mapped[provider] = value
            }
        }
        return mapped
    }

    func save(_ models: [Provider: String]) {
        let raw = Dictionary(uniqueKeysWithValues: models.map { ($0.key.rawValue, $0.value) })
        defaults.set(raw, forKey: StorageKeys.providerModels)
    }
}
