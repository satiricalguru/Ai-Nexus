import SwiftUI

// MARK: - Settings Home

struct SettingsHomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @StateObject private var authManager = AuthManager.shared
    @State private var showNexusPlus = false
    @AppStorage("nexusPlusActive") private var isPlus = false

    var body: some View {
        Form {
            Section("Account") {
                CardRow {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                        Text(authManager.currentUserName ?? authManager.currentUserEmail ?? "Not Logged In")
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                Button(role: .destructive) {
                    do { try authManager.signOut() } catch {}
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                    }
                }
            }

            Section("Configuration") {
                NavigationLink {
                    APISettingsView(settingsViewModel: settingsViewModel)
                } label: {
                    CardRow { NavigationRow(title: "API Settings", icon: "key.fill") }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    PromptLibraryView(settingsViewModel: settingsViewModel, chatViewModel: chatViewModel)
                } label: {
                    CardRow { NavigationRow(title: "Prompt Library", icon: "text.book.closed") }
                }
                .buttonStyle(.plain)
            }

            Section("Preferences") {
                NavigationLink {
                    ThemePreferencesView()
                } label: {
                    CardRow { NavigationRow(title: "Theme", icon: "paintbrush.fill") }
                }
                .buttonStyle(.plain)

                NavigationLink {
                    GeneralSettingsView(chatViewModel: chatViewModel, settingsViewModel: settingsViewModel)
                } label: {
                    CardRow { NavigationRow(title: "General", icon: "gearshape.fill") }
                }
                .buttonStyle(.plain)
            }

            Section("Upgrade") {
                Button {
                    showNexusPlus = true
                } label: {
                    HStack(spacing: 14) {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 36, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nexus Plus")
                                .font(.headline)
                                .foregroundStyle(LinearGradient(colors: isPlus ? [.green, .teal] : [.purple, .indigo], startPoint: .leading, endPoint: .trailing))
                            Text(isPlus ? "Membership Active ✦" : "Unlock premium features")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .sheet(isPresented: $showNexusPlus) {
                #if os(macOS)
                NexusPlusView()
                    .frame(minWidth: 400, minHeight: 520)
                #else
                NexusPlusView()
                #endif
            }

            Section("Support") {
                NavigationLink { WhatsNewView() } label: {
                    CardRow { NavigationRow(title: "What's New", icon: "star.bubble.fill", trailingText: AppMeta.versionString) }
                }.buttonStyle(.plain)

                NavigationLink { ContactView() } label: {
                    CardRow { NavigationRow(title: "Contact", icon: "envelope.fill") }
                }.buttonStyle(.plain)
            }
        }
        .settingsListStyle()
        .scrollContentBackground(.hidden)
        .background(settingsBackground)
        .navigationTitle("Settings")
    }

    private var settingsBackground: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color.black, Color(red: 0.10, green: 0.11, blue: 0.16)]
                : [Color(red: 0.96, green: 0.97, blue: 1.0), Color.white],
            startPoint: .top, endPoint: .bottom
        )
    }
}

// MARK: - Theme Preferences

struct ThemePreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(StorageKeys.appTheme) private var appThemeRaw = AppThemeMode.native.rawValue
    @AppStorage(StorageKeys.appColourScheme) private var appColourSchemeRaw = AppColourScheme.dark.rawValue
    @AppStorage(StorageKeys.lightAccentHex) private var lightAccentHex = "#4F8CFF"
    @AppStorage(StorageKeys.darkAccentHex) private var darkAccentHex = "#6FB7FF"
    @AppStorage(StorageKeys.fontSize) private var fontSize = 16.0
    @AppStorage(StorageKeys.syntaxHighlighting) private var syntaxRaw = SyntaxHighlightingStyle.basic.rawValue
    @AppStorage(StorageKeys.codeColourScheme) private var codeSchemeRaw = CodeColourScheme.system.rawValue

    private var appTheme: AppThemeMode {
        get { AppThemeMode(rawValue: appThemeRaw) ?? .native }
        nonmutating set { appThemeRaw = newValue.rawValue }
    }
    private var appColourScheme: AppColourScheme {
        get { AppColourScheme(rawValue: appColourSchemeRaw) ?? .dark }
        nonmutating set { appColourSchemeRaw = newValue.rawValue }
    }
    private var syntaxStyle: SyntaxHighlightingStyle {
        get { SyntaxHighlightingStyle(rawValue: syntaxRaw) ?? .basic }
        nonmutating set { syntaxRaw = newValue.rawValue }
    }
    private var codeScheme: CodeColourScheme {
        get { CodeColourScheme(rawValue: codeSchemeRaw) ?? .system }
        nonmutating set { codeSchemeRaw = newValue.rawValue }
    }

    var body: some View {
        Form {
            Section("General") {
                SettingsPickerRow(title: "App theme", icon: appTheme.icon) {
                    ForEach(AppThemeMode.allCases) { mode in Button(mode.title) { setAppTheme(mode) } }
                } labelContent: { Text(appTheme.title) }

                Divider().opacity(0.5)
                SettingsPickerRow(title: "App colour scheme", icon: appColourScheme.icon) {
                    ForEach(AppColourScheme.allCases) { scheme in Button(scheme.title) { setAppColourScheme(scheme) } }
                } labelContent: { Text(appColourScheme.title) }

                Divider().opacity(0.5)
                SettingsRow(title: "Light accent color", icon: "sun.max") { ColorSwatch(hexValue: $lightAccentHex) }
                Divider().opacity(0.5)
                SettingsRow(title: "Dark accent color", icon: "moon") { ColorSwatch(hexValue: $darkAccentHex) }
                Divider().opacity(0.5)
                SettingsRow(title: "Base font size \(Int(fontSize))", icon: "textformat.size") { FontSizeStepper(fontSize: $fontSize) }
            }

            Section("Code formatting") {
                SettingsPickerRow(title: "Syntax highlighting", icon: syntaxStyle.icon) {
                    ForEach(SyntaxHighlightingStyle.allCases) { style in Button(style.title) { syntaxStyle = style } }
                } labelContent: { Text(syntaxStyle.title) }
                Divider().opacity(0.5)
                SettingsPickerRow(title: "Code colour scheme", icon: codeScheme.icon) {
                    ForEach(CodeColourScheme.allCases) { scheme in Button(scheme.title) { codeScheme = scheme } }
                } labelContent: { Text(codeScheme.title) }
                CodePreview(fontSize: fontSize, syntaxStyle: syntaxStyle, codeScheme: codeScheme)
            }
        }
        .settingsListStyle()
        .navigationTitle("Preferences")
        .settingsBackButton(dismiss: dismiss)
    }

    private func setAppTheme(_ theme: AppThemeMode) {
        appTheme = theme
        if theme == .native { appColourScheme = .system }
        else if appColourScheme == .system { appColourScheme = .dark }
    }
    private func setAppColourScheme(_ scheme: AppColourScheme) {
        appColourScheme = scheme
        appTheme = (scheme == .system) ? .native : .custom
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel
    @AppStorage("nexusPlusActive") private var isPlus = false

    @AppStorage(StorageKeys.appTheme) private var appThemeRaw = AppThemeMode.native.rawValue
    @AppStorage(StorageKeys.appColourScheme) private var appColourSchemeRaw = AppColourScheme.dark.rawValue
    @AppStorage(StorageKeys.lightAccentHex) private var lightAccentHex = "#4F8CFF"
    @AppStorage(StorageKeys.darkAccentHex) private var darkAccentHex = "#6FB7FF"
    @AppStorage(StorageKeys.fontSize) private var fontSize = 16.0
    @AppStorage(StorageKeys.syntaxHighlighting) private var syntaxRaw = SyntaxHighlightingStyle.basic.rawValue
    @AppStorage(StorageKeys.codeColourScheme) private var codeSchemeRaw = CodeColourScheme.system.rawValue
    @AppStorage(StorageKeys.autoRenameChat) private var autoRenameChat = true
    @AppStorage(StorageKeys.hapticFeedback) private var hapticFeedback = true
    @AppStorage(StorageKeys.enableImageGeneration) private var enableImageGeneration = false
    @AppStorage(StorageKeys.enableVisionFiles) private var enableVisionFiles = false

    @State private var cacheStatus = "0 Mb"
    @State private var showDeleteChatsConfirmation = false
    @State private var showResetSettingsConfirmation = false
    @State private var showDeleteAllDataConfirmation = false

    var body: some View {
        Form {
            Section {
                SettingsToggleRow(title: "Auto rename chat", icon: "text.bubble", description: "An additional request will be sent after the first reply.", isOn: $autoRenameChat)
                Divider().opacity(0.5)
                SettingsToggleRow(title: "Haptic feedback", icon: "iphone.radiowaves.left.and.right", description: "Turns off most haptic feedback.", isOn: $hapticFeedback)
                Divider().opacity(0.5)
                SettingsToggleRow(title: "Enable Image Generation", icon: "photo", description: "Generate images with GPT Image or DALL-E 2 and 3.", isOn: $enableImageGeneration, isLocked: !isPlus)
                Divider().opacity(0.5)
                SettingsToggleRow(title: "Enable Vision and Files", icon: "eye", description: "Send images to models with vision and attach files to chats.", isOn: $enableVisionFiles, isLocked: !isPlus)
                Divider().opacity(0.5)
                SettingsActionRow(title: "Clear image cache", icon: "trash.square", description: "Current cache size: \(cacheStatus)", actionTitle: "Delete") {
                    withAnimation { cacheStatus = "0 Mb" }
                }
            }

            Section("Data Management") {
                Button { showDeleteChatsConfirmation = true } label: {
                    SettingsRow(title: "Delete all chats", icon: "bubble.left.and.exclamationmark.bubble.right.fill").foregroundStyle(.cyan)
                }
                Divider().opacity(0.5)
                Button { showResetSettingsConfirmation = true } label: {
                    SettingsRow(title: "Reset all settings", icon: "arrow.counterclockwise").foregroundStyle(.cyan)
                }
                Divider().opacity(0.5)
                Button(role: .destructive) { showDeleteAllDataConfirmation = true } label: {
                    SettingsRow(title: "Delete all data", icon: "trash.fill").foregroundStyle(.red)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("General")
        .settingsBackButton(dismiss: dismiss)
        .confirmationDialog("Delete all chats?", isPresented: $showDeleteChatsConfirmation, titleVisibility: .visible) {
            Button("Delete All Chats", role: .destructive) { chatViewModel.deleteAllChats() }
        } message: { Text("This cannot be undone.") }
        .confirmationDialog("Reset all settings?", isPresented: $showResetSettingsConfirmation, titleVisibility: .visible) {
            Button("Reset", role: .destructive) { resetAllSettings() }
        } message: { Text("All preferences will return to defaults.") }
        .confirmationDialog("Delete all data?", isPresented: $showDeleteAllDataConfirmation, titleVisibility: .visible) {
            Button("Delete Everything", role: .destructive) { deleteAllData() }
        } message: { Text("This will permanently delete all chats, prompts, API keys, and settings.") }
    }

    private func resetAllSettings() {
        appThemeRaw = AppThemeMode.native.rawValue
        appColourSchemeRaw = AppColourScheme.dark.rawValue
        lightAccentHex = "#4F8CFF"; darkAccentHex = "#6FB7FF"; fontSize = 16
        syntaxRaw = SyntaxHighlightingStyle.basic.rawValue
        codeSchemeRaw = CodeColourScheme.system.rawValue
        autoRenameChat = true; hapticFeedback = true
        enableImageGeneration = false; enableVisionFiles = false
        settingsViewModel.resetProviderModels()
    }
    private func deleteAllData() {
        chatViewModel.deleteAllChats()
        settingsViewModel.clearPrompts()
        settingsViewModel.deleteAllAPIKeys()
        resetAllSettings()
    }
}

// MARK: - Prompt Library

struct PromptLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settingsViewModel: SettingsViewModel
    @ObservedObject var chatViewModel: ChatViewModel
    @State private var showAddPrompt = false
    @State private var promptToEdit: PromptItem?

    var body: some View {
        Form {
            Section("Prompt Library") {
                Text("Prompts sync with iCloud when account and app sync are enabled.")
                    .font(.footnote).foregroundStyle(.secondary)
                if settingsViewModel.prompts.isEmpty {
                    VStack(spacing: 12) {
                        Text("No saved prompts yet").font(.headline)
                        Button { showAddPrompt = true } label: {
                            Image(systemName: "plus").font(.headline).frame(width: 36, height: 36).background(.regularMaterial, in: Circle())
                        }
                    }.frame(maxWidth: .infinity, minHeight: 140)
                } else {
                    ForEach(settingsViewModel.prompts) { prompt in
                        Button {
                            chatViewModel.composerText = prompt.text
                            Task {
                                let defaultProvider = Provider(rawValue: UserDefaults.standard.string(forKey: StorageKeys.defaultProvider) ?? "openrouter") ?? .openrouter
                                await chatViewModel.sendCurrentMessage(
                                    defaultProvider: defaultProvider,
                                    defaultModel: settingsViewModel.model(for: defaultProvider),
                                    attachmentURLs: []
                                )
                            }
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(prompt.title).font(.headline).foregroundStyle(.primary)
                                Text(prompt.text).foregroundStyle(.secondary).lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button {
                                promptToEdit = prompt
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) {
                                settingsViewModel.deletePrompt(id: prompt.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                settingsViewModel.deletePrompt(id: prompt.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                promptToEdit = prompt
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("Prompt Library")
        .settingsBackButton(dismiss: dismiss)
        .toolbar { Button { showAddPrompt = true } label: { Image(systemName: "plus") } }
        .sheet(isPresented: $showAddPrompt) {
            AddPromptView(settingsViewModel: settingsViewModel)
                #if !os(macOS)
                .presentationDetents([.medium])
                #endif
        }
        .sheet(item: $promptToEdit) { prompt in
            AddPromptView(settingsViewModel: settingsViewModel, promptToEdit: prompt)
                #if !os(macOS)
                .presentationDetents([.medium])
                #endif
        }
    }
}

struct AddPromptView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settingsViewModel: SettingsViewModel
    var promptToEdit: PromptItem? = nil

    @State private var title = ""
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
                TextField("Prompt", text: $text, axis: .vertical).lineLimit(4...8)
            }
            .navigationTitle(promptToEdit == nil ? "New Prompt" : "Edit Prompt")
            .toolbar {
                ToolbarItem { Button("Cancel") { dismiss() } }
                ToolbarItem {
                    Button(promptToEdit == nil ? "Add" : "Save") {
                        if let prompt = promptToEdit {
                            settingsViewModel.updatePrompt(id: prompt.id, title: title, text: text)
                        } else {
                            settingsViewModel.addPrompt(title: title, text: text)
                        }
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let prompt = promptToEdit {
                    title = prompt.title
                    text = prompt.text
                }
            }
        }
    }
}

// MARK: - API Settings

struct APISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settingsViewModel: SettingsViewModel
    @AppStorage(StorageKeys.defaultProvider) private var defaultProviderRaw = Provider.openrouter.rawValue

    private var defaultProvider: Provider {
        get { Provider(rawValue: defaultProviderRaw) ?? .openrouter }
        nonmutating set { defaultProviderRaw = newValue.rawValue }
    }

    var body: some View {
        Form {
            Section("API") {
                Text("API keys are stored securely in the keychain.").font(.footnote).foregroundStyle(.secondary)
                Picker("Default provider", selection: Binding(get: { defaultProvider }, set: { defaultProvider = $0 })) {
                    ForEach(Provider.allCases) { provider in Text(provider.displayName).tag(provider) }
                }
            }
            Section("Providers") {
                ForEach(Provider.allCases) { provider in
                    NavigationLink {
                        ProviderModelView(provider: provider, settingsViewModel: settingsViewModel)
                    } label: {
                        CardRow {
                            NavigationRow(title: provider.displayName, icon: provider.iconName,
                                          trailingText: settingsViewModel.loadAPIKey(for: provider).isEmpty ? "Missing" : "✓ Active")
                        }
                    }.buttonStyle(.plain)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("API Settings")
    }
}

// MARK: - Provider Model View

struct ProviderModelView: View {
    @Environment(\.dismiss) private var dismiss
    let provider: Provider
    @ObservedObject var settingsViewModel: SettingsViewModel

    @State private var apiKey = ""
    @State private var keyStatus = ""
    @FocusState private var apiKeyFocused: Bool
    @State private var isEnabled = true
    @State private var identity = ""
    @State private var freeModelsOnly = false
    @State private var selectedPrompt = "None"
    @State private var defaultModel = ""
    @State private var isFetching = false
    @State private var ollamaBaseUrl = "http://127.0.0.1:11434"
    @State private var showDeleteKeyConfirmation = false

    var body: some View {
        Form {
            VStack(spacing: 12) {
                Image(systemName: provider.iconName).font(.system(size: 40)).foregroundStyle(.secondary)
                    .frame(width: 80, height: 80).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                VStack(spacing: 4) {
                    Text(provider.displayName).font(.title2.bold())
                    Text(provider.subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }.frame(maxWidth: .infinity).padding(.vertical, 20).listRowBackground(Color.clear)

            Section("API Key") {
                Toggle(isOn: $isEnabled) { Label("Enable \(provider.displayName)", systemImage: "checkmark.circle") }.tint(.green)
                HStack {
                    Image(systemName: "eye.slash").foregroundStyle(.secondary).frame(width: 24)
                    SecureField("API key", text: $apiKey).focused($apiKeyFocused)
                    if !apiKey.isEmpty {
                        Button {
                            apiKeyFocused = false
                            let ok = settingsViewModel.saveAPIKey(apiKey, for: provider)
                            keyStatus = ok ? "✓ Saved" : "✕ Failed"
                        } label: {
                            Text("Save").font(.caption.bold()).padding(.horizontal, 10).padding(.vertical, 4)
                                .background(.blue, in: Capsule()).foregroundStyle(.white)
                        }
                    }
                }
            }

            if provider == .ollama {
                Section("Ollama Server") {
                    Toggle(isOn: Binding(
                        get: { ollamaBaseUrl != "http://127.0.0.1:11434" },
                        set: { isCloud in
                            ollamaBaseUrl = isCloud ? "https://ollama.com/v1" : "http://127.0.0.1:11434"
                            saveSettings()
                        }
                    )) { Label("Use Cloud Models", systemImage: "cloud") }
                    HStack {
                        Image(systemName: "server.rack").foregroundStyle(.secondary).frame(width: 24)
                        TextField("http://127.0.0.1:11434", text: $ollamaBaseUrl).autocorrectionDisabled()
                            #if !os(macOS)
                            .textInputAutocapitalization(.never)
                            #endif
                    }
                }
            }

            Section("Model") {
                Menu {
                    ForEach(settingsViewModel.models(for: provider), id: \.self) { model in
                        Button(model) { settingsViewModel.setModel(model, for: provider); defaultModel = model }
                    }
                } label: { NavigationRow(title: "Default model", icon: "atom", trailingText: defaultModel) }

                Toggle(isOn: $freeModelsOnly) { Label("Free models only", systemImage: "gift") }
            }

            Section {
                Button { fetchModels() } label: {
                    HStack {
                        Label("Get \(provider.displayName) Models", systemImage: "arrow.down.circle")
                        Spacer()
                        if isFetching { ProgressView().scaleEffect(0.8) } else { Text("Load").foregroundStyle(.blue) }
                    }
                }.disabled(isFetching)
            }

            Section {
                Button { testKey() } label: {
                    HStack { Label("Test API Key", systemImage: "key.viewfinder"); Spacer(); Text("Submit").foregroundStyle(.secondary) }
                }
                if !keyStatus.isEmpty {
                    Text(keyStatus).font(.caption).foregroundStyle(keyStatus.contains("✓") ? .green : .red)
                }
            }

            Section {
                Button(role: .destructive) { showDeleteKeyConfirmation = true } label: {
                    Text("Delete Key").frame(maxWidth: .infinity)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle(provider.displayName)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear(perform: loadSettings)
        .onChange(of: isEnabled) { saveSettings() }
        .onChange(of: identity) { saveSettings() }
        .onChange(of: freeModelsOnly) { saveSettings() }
        .onChange(of: ollamaBaseUrl) { saveSettings() }
        .confirmationDialog("Delete API key?", isPresented: $showDeleteKeyConfirmation, titleVisibility: .visible) {
            Button("Delete Key", role: .destructive) {
                settingsViewModel.deleteAPIKey(for: provider); apiKey = ""; keyStatus = "Key deleted."
            }
        } message: { Text("This cannot be undone.") }
    }

    private func loadSettings() {
        apiKey = settingsViewModel.loadAPIKey(for: provider)
        let defaults = UserDefaults.standard
        isEnabled = defaults.object(forKey: StorageKeys.providerEnabledKey(for: provider.rawValue)) == nil ? true : defaults.bool(forKey: StorageKeys.providerEnabledKey(for: provider.rawValue))
        identity = defaults.string(forKey: StorageKeys.providerIdentityKey(for: provider.rawValue)) ?? provider.displayName
        freeModelsOnly = defaults.bool(forKey: StorageKeys.providerFreeOnlyKey(for: provider.rawValue))
        selectedPrompt = defaults.string(forKey: StorageKeys.providerPromptKey(for: provider.rawValue)) ?? "None"
        defaultModel = settingsViewModel.model(for: provider)
        if provider == .ollama {
            ollamaBaseUrl = defaults.string(forKey: StorageKeys.providerBaseUrlKey(for: provider.rawValue)) ?? "http://127.0.0.1:11434"
        }
    }
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(isEnabled, forKey: StorageKeys.providerEnabledKey(for: provider.rawValue))
        defaults.set(identity, forKey: StorageKeys.providerIdentityKey(for: provider.rawValue))
        defaults.set(freeModelsOnly, forKey: StorageKeys.providerFreeOnlyKey(for: provider.rawValue))
        defaults.set(selectedPrompt, forKey: StorageKeys.providerPromptKey(for: provider.rawValue))
        if provider == .ollama { defaults.set(ollamaBaseUrl, forKey: StorageKeys.providerBaseUrlKey(for: provider.rawValue)) }
    }
    private func fetchModels() {
        isFetching = true
        Task {
            do {
                let service = LiveProviderService(provider: provider)
                let models = try await service.fetchAvailableModels(freeOnly: freeModelsOnly)
                settingsViewModel.setCustomModels(models, for: provider)
                if let first = models.first { settingsViewModel.setModel(first, for: provider); defaultModel = first }
                keyStatus = "✓ \(models.count) models loaded"
            } catch { keyStatus = "✕ \(error.localizedDescription)" }
            isFetching = false
        }
    }
    private func testKey() {
        Task {
            keyStatus = "Testing..."
            do {
                let service = LiveProviderService(provider: provider)
                let tier = try await service.detectTier()
                keyStatus = "✓ \(tier)"
            } catch { keyStatus = "✕ \(error.localizedDescription)" }
        }
    }
}

