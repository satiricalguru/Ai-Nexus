import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - ChatWorkspaceView -------------------------------------------------

struct ChatWorkspaceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var settingsViewModel: SettingsViewModel

    @State private var showThreadPicker = false
    @State private var showPromptLibrary = false
    @State private var showFileImporter = false
    @State private var selectedFileURLs: [URL] = []
    
    @StateObject private var voiceManager = VoiceManager()
    @State private var showingVoiceError = false

    @AppStorage(StorageKeys.defaultProvider) private var defaultProviderRaw = Provider.openrouter.rawValue

    @FocusState private var isComposerFocused: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: chatBackgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Divider().overlay(dividerColor)
                
                if let thread = selectedThread {
                    if thread.messages.isEmpty {
                        chatEmptyState
                    } else {
                        MessageAreaView(
                            chatViewModel: chatViewModel,
                            thread: thread,
                            isComposerFocused: $isComposerFocused
                        )
                    }
                } else {
                    chatEmptyState
                }

                ComposerBarView(
                    chatViewModel: chatViewModel,
                    voiceManager: voiceManager,
                    selectedFileURLs: $selectedFileURLs,
                    isFocused: $isComposerFocused,
                    defaultProvider: defaultProvider,
                    settingsViewModel: settingsViewModel
                )
            }
            .padding(16)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("TriggerFilePicker"))) { _ in
                showFileImporter = true
            }
        }
        .sheet(isPresented: $showThreadPicker) {
            ThreadPickerView(chatViewModel: chatViewModel)
                #if !os(macOS)
                .presentationDetents([.medium, .large])
                #endif
        }
        .sheet(isPresented: $showPromptLibrary) {
            NavigationStack {
                PromptLibraryView(settingsViewModel: settingsViewModel, chatViewModel: chatViewModel)
            }
            #if !os(macOS)
            .presentationDetents([.medium, .large])
            #endif
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                selectedFileURLs.append(contentsOf: urls)
            case .failure(let error):
                print("Error selecting files: \(error.localizedDescription)")
            }
        }
        .alert("Voice Error", isPresented: $showingVoiceError, actions: {
            Button("OK", role: .cancel) {}
        }, message: {
            Text(voiceManager.error ?? "Unknown error")
        })
        .onChange(of: voiceManager.transcript) { _, newTranscript in
            if !newTranscript.isEmpty {
                chatViewModel.composerText = newTranscript
            }
        }
        .onChange(of: voiceManager.error) { _, newError in
            if newError != nil {
                showingVoiceError = true
            }
        }
    }

    private var selectedThread: ChatThread? {
        chatViewModel.selectedThread
    }

    private var selectedProvider: Provider {
        selectedThread?.provider ?? defaultProvider
    }

    private var selectedModel: String {
        selectedThread?.modelID ?? settingsViewModel.model(for: selectedProvider)
    }

    private var selectedModelTitle: String {
        selectedModel
    }

    private var defaultProvider: Provider {
        Provider(rawValue: defaultProviderRaw) ?? .openrouter
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                showThreadPicker = true
            } label: {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }

            Spacer()

            Menu {
                ForEach(Provider.allCases) { provider in
                    Menu(provider.displayName) {
                        let models = settingsViewModel.models(for: provider)
                        ForEach(models, id: \.self) { model in
                            Button(model) {
                                selectModel(model, for: provider)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selectedModelTitle)
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .frame(maxWidth: 260)

            Spacer()

            Menu {
                Button("New Chat", systemImage: "plus.bubble") {
                    let provider = defaultProvider
                    chatViewModel.newChat(defaultProvider: provider, defaultModel: settingsViewModel.model(for: provider))
                }
                Button("Prompt Library", systemImage: "text.book.closed") {
                    showPromptLibrary = true
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .foregroundStyle(primaryForegroundColor)
    }

    private var chatEmptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("What's on the agenda today?")
                .font(.largeTitle)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            VStack(spacing: 10) {
                ForEach(emptyStateSuggestions, id: \.text) { suggestion in
                    Button {
                        sendMessage(prefilledText: suggestion.text)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: suggestion.symbol)
                                .font(.body)
                                .foregroundStyle(.secondary)

                            Text(suggestion.text)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(.thinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 560)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { isComposerFocused = false }
        .simultaneousGesture(
            DragGesture().onChanged { _ in
                isComposerFocused = false
            }
        )
    }

    private var emptyStateSuggestions: [(symbol: String, text: String)] {
        [
            ("text.bubble", "Summarize notes from a meeting"),
            ("text.viewfinder", "Help me translate text in an image"),
            ("leaf", "Help me identify plants in an image")
        ]
    }

    private func sendMessage(prefilledText: String) {
        let trimmed = prefilledText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        chatViewModel.composerText = trimmed
        
        Task {
            await chatViewModel.sendCurrentMessage(
                defaultProvider: defaultProvider,
                defaultModel: settingsViewModel.model(for: defaultProvider),
                attachmentURLs: []
            )
        }
    }

    private func selectModel(_ modelID: String, for provider: Provider) {
        settingsViewModel.setModel(modelID, for: provider)
        if selectedThread != nil {
            chatViewModel.updateModel(provider: provider, model: modelID)
        } else {
            defaultProviderRaw = provider.rawValue
        }
    }

    private var primaryForegroundColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var dividerColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.12)
    }

    private var chatBackgroundColors: [Color] {
        if colorScheme == .dark {
            return [Color.black, Color(red: 0.07, green: 0.09, blue: 0.15)]
        }
        return [Color(red: 0.96, green: 0.97, blue: 1.0), Color.white]
    }
}

// MARK: - MessageBubbleView -------------------------------------------------

struct MessageBubbleView: View {
    @Environment(\.colorScheme) private var colorScheme
    let message: ChatMessage
    @ObservedObject var chatViewModel: ChatViewModel

    var body: some View {
        HStack {
            if message.role == .assistant || message.role == .system {
                VStack(alignment: .leading, spacing: 4) {
                    bubble(content: message.text, color: assistantBubbleColor)
                    if message.role == .assistant && message.text != "Thinking…" && !message.text.starts(with: "⚠️") {
                        messageActions
                    }
                }
                Spacer(minLength: 40)
            } else {
                Spacer(minLength: 40)
                bubble(content: message.text, color: userBubbleColor)
            }
        }
    }

    private var messageActions: some View {
        HStack(spacing: 16) {
            Button {
                chatViewModel.toggleLike(messageID: message.id)
            } label: {
                Image(systemName: (message.isLiked ?? false) ? "hand.thumbsup.fill" : "hand.thumbsup")
                    .foregroundStyle((message.isLiked ?? false) ? .blue : .secondary)
            }
            
            Button {
                chatViewModel.toggleDislike(messageID: message.id)
            } label: {
                Image(systemName: (message.isDisliked ?? false) ? "hand.thumbsdown.fill" : "hand.thumbsdown")
                    .foregroundStyle((message.isDisliked ?? false) ? .red : .secondary)
            }
            
            Button {
                Task {
                    await chatViewModel.regenerateResponse(for: message.id)
                }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .foregroundStyle(.secondary)
            }
            
            Button {
                copyToClipboard(message.text)
            } label: {
                Image(systemName: "doc.on.doc")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
        .padding(.leading, 8)
        .padding(.top, 2)
    }

    private func bubble(content: String, color: Color) -> some View {
        VStack(alignment: message.role == .assistant ? .leading : .trailing, spacing: 8) {
            // Render attachments if any
            if let attachments = message.attachments, !attachments.isEmpty {
                ForEach(attachments) { att in
                    if att.mimeType.starts(with: "image/"), let data = Data(base64Encoded: att.base64Data) {
                        #if os(macOS)
                        if let image = NSImage(data: data) {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 200, maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        #else
                        if let image = UIImage(data: data) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 200, maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        #endif
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.fill")
                            Text(att.fileName)
                                .font(.caption)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            
            if !content.isEmpty && content != "Thinking…" {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                let markdownText = (try? AttributedString(markdown: trimmed, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(trimmed)
                Text(markdownText)
                    .font(.body)
                    .foregroundStyle(bubbleForegroundColor)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(color, in: RoundedRectangle(cornerRadius: 16))
                    .contextMenu {
                        Button {
                            copyToClipboard(message.text)
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        if message.role == .assistant {
                            Button {
                                Task {
                                    await chatViewModel.regenerateResponse(for: message.id)
                                }
                            } label: {
                                Label("Regenerate", systemImage: "arrow.clockwise")
                            }
                        }
                        Button(role: .destructive) {
                            if let index = chatViewModel.selectedThread?.messages.firstIndex(where: { $0.id == message.id }) {
                                chatViewModel.deleteMessage(at: index)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            } else if content == "Thinking…" {
                HStack(spacing: 0) {
                    NexusThinkingAnimation()
                }
                .padding(12)
                .background(color, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
            }
        }
    }

    private var bubbleForegroundColor: Color {
        colorScheme == .dark ? .white : .primary
    }

    private var assistantBubbleColor: Color {
        colorScheme == .dark ? .bubbleAssistant : Color.black.opacity(0.06)
    }

    private var userBubbleColor: Color {
        colorScheme == .dark ? .bubbleUser : Color.blue.opacity(0.20)
    }
}



