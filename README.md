# Ai Nexus 🇳

A powerful, multi-provider AI chat app for iOS/macOS built with SwiftUI.

Connect to OpenAI, Anthropic (Claude), Google Gemini, Groq, Mistral, OpenRouter, and local Ollama models — all from one clean interface.

---

## Features

- 🤖 **7 AI Providers** — OpenAI, Anthropic, Google, Groq, Mistral, OpenRouter, Ollama
- 🔑 **Secure Key Storage** — API keys stored in the iOS Keychain, never in plain text
- 💬 **Streaming Responses** — Real-time token-by-token streaming for all providers
- 🖼 **Multimodal** — Attach images to messages (vision-capable models)
- 🎙 **Voice Input** — Dictate messages with on-device speech recognition
- 🌗 **Themes** — Light, dark, and system-adaptive UI
- 📁 **File Attachments** — Send documents alongside your prompts
- 🔄 **Thread Management** — Organise and switch between multiple conversations
- 🔐 **Firebase Auth** — Optional Google Sign-In via Firebase

---

## Requirements

| Tool | Version |
|------|---------|
| Xcode | 15+ |
| iOS target | 17+ |
| Swift | 5.9+ |
| Firebase SDK | via Swift Package Manager |

---

## Screenshots

<>




---

## Setup

### 1. Clone the repo

```bash
git clone https://github.com/YOUR_USERNAME/ai-nexus.git
cd ai-nexus
```

### 2. Add Firebase config

Copy the example file and fill in your own Firebase credentials:

```bash
cp "Ai Nexus/GoogleService-Info.plist.example" "Ai Nexus/GoogleService-Info.plist"
```

Then edit `GoogleService-Info.plist` with values from your [Firebase Console](https://console.firebase.google.com).

> ⚠️ **Never commit the real `GoogleService-Info.plist`.** It is listed in `.gitignore`.

### 3. Open in Xcode

```bash
open "Ai Nexus.xcodeproj"
```

Xcode will automatically resolve Swift Package Manager dependencies on first open.

### 4. Add API Keys at Runtime

Launch the app → Settings → API Settings, and paste your keys for whichever providers you want to use. Keys are stored securely in the iOS Keychain.

---

## Supported Providers & Models

| Provider | Example Models |
|----------|---------------|
| OpenAI | gpt-4.1, gpt-4.1-mini, gpt-4o-mini |
| Anthropic | claude-3.7-sonnet, claude-3.5-haiku |
| Google | gemini-2.5-pro, gemini-2.5-flash |
| Groq | llama-3.3-70b-versatile, mixtral-8x7b |
| Mistral | mistral-large, pixtral-large |
| OpenRouter | deepseek/deepseek-chat, qwen/qwen-2.5-coder |
| Ollama | llama3, mistral, phi3 (local) |

---

## Architecture

```
Ai Nexus/
├── Ai_NexusApp.swift        # App entry point
├── AppRoot.swift            # Root navigation / auth state
├── Models.swift             # Data models (ChatThread, ChatMessage, …)
├── ViewModels.swift         # ObservableObject view-models
├── Services.swift           # All AI provider networking
├── Providers.swift          # Provider enum, model lists
├── Storage.swift            # UserDefaults persistence helpers
├── KeychainService.swift    # Keychain read/write wrapper
├── ThemeSettings.swift      # Appearance settings
├── VoiceManager.swift       # Speech recognition
├── Views/
│   ├── ChatWorkspaceView.swift
│   ├── MessageAreaView.swift
│   ├── ComposerBarView.swift
│   ├── ThreadPickerView.swift
│   ├── SettingsViews.swift
│   ├── LoginView.swift
│   └── …
```

---

## Contributing

Pull requests are welcome! Please open an issue first for major changes.

1. Fork the repo
2. Create a feature branch (`git checkout -b feature/my-feature`)
3. Commit your changes (`git commit -m 'Add my feature'`)
4. Push and open a PR

---

## License

MIT © Jatin Pandey

Developed by **Satirical Guru** , **Claude** , **Xcode** & **Antigravity** .
