import Foundation
import SwiftUI
import Combine               // <-- provides ObservableObject
import AuthenticationServices
import CryptoKit
import Security
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

// -----------------------------------------------------------------------------
// MARK: - ChatViewModel
// -----------------------------------------------------------------------------
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var selectedThreadID: UUID?
    @Published var composerText: String = ""
    @Published var isSending: Bool = false

    private var currentTask: Task<Void, Never>?

    // MARK: - Persistence
    private func threadsFileURL(for userID: String?) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let suffix = userID ?? "anonymous"
        return docs.appendingPathComponent("ai_nexus_threads_\(suffix).json")
    }

    private var cancellables = Set<AnyCancellable>()

    init() {
        AuthManager.shared.$userID
            .sink { [weak self] newID in
                self?.loadThreads(for: newID)
            }
            .store(in: &cancellables)
    }

    private func loadThreads(for userID: String?) {
        let url = threadsFileURL(for: userID)
        
        // Clear current threads before loading new ones
        self.threads = []
        self.selectedThreadID = nil
        
        // First Launch Safety: Purge any residual or mock data from previous versions
        // to ensure a clean "empty state" on the first run of version 1.5.
        let firstLaunchKey = "v1.5.firstLaunchClean"
        if !UserDefaults.standard.bool(forKey: firstLaunchKey) {
            try? FileManager.default.removeItem(at: url)
            UserDefaults.standard.set(true, forKey: firstLaunchKey)
        }

        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            threads = try JSONDecoder().decode([ChatThread].self, from: data)
            // Restore last selected thread - Removed to start with home screen as requested
            // if let last = threads.last { selectedThreadID = last.id }
        } catch {
            print("[Persistence] Failed to load threads: \(error.localizedDescription)")
        }
    }

    private func saveThreads() {
        do {
            let data = try JSONEncoder().encode(threads)
            try data.write(to: threadsFileURL(for: AuthManager.shared.userID), options: .atomic)
        } catch {
            print("[Persistence] Failed to save threads: \(error.localizedDescription)")
        }
    }

    var selectedThread: ChatThread? {
        guard let id = selectedThreadID else { return nil }
        return threads.first(where: { $0.id == id })
    }

    func newChat(defaultProvider: Provider, defaultModel: String) {
        let thread = ChatThread(title: "New Chat", provider: defaultProvider, modelID: defaultModel, messages: [])
        threads.append(thread)
        selectedThreadID = thread.id
        saveThreads()
    }

    func deleteThreads(at offsets: IndexSet) {
        let idsToDelete = offsets.map { threads[$0].id }
        threads.remove(atOffsets: offsets)
        if let selected = selectedThreadID, idsToDelete.contains(selected) {
            selectedThreadID = threads.last?.id
        }
        saveThreads()
    }

    func updateModel(provider: Provider, model: String) {
        guard let id = selectedThreadID,
              let index = threads.firstIndex(where: { $0.id == id }) else { return }
        threads[index].provider = provider
        threads[index].modelID = model
    }

    func deleteMessage(at index: Int) {
        guard let id = selectedThreadID,
              let threadIndex = threads.firstIndex(where: { $0.id == id }) else { return }
        
        threads[threadIndex].messages.remove(at: index)
        saveThreads()
    }

    func stopGenerating() {
        currentTask?.cancel()
        currentTask = nil
        isSending = false
    }

    func sendCurrentMessage(defaultProvider: Provider, defaultModel: String, attachmentURLs: [URL] = []) async {
        let trimmed = composerText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachmentURLs.isEmpty else { return }

        if selectedThread == nil {
            newChat(defaultProvider: defaultProvider, defaultModel: defaultModel)
        }

        guard let id = selectedThreadID else { return }

        isSending = true
        
        currentTask = Task {
            defer { 
                isSending = false
                currentTask = nil
            }
            let attachments = await processAttachments(urls: attachmentURLs)
            
            if Task.isCancelled { return }
            
            guard let index = threads.firstIndex(where: { $0.id == id }) else { return }
            
            let userMessage = ChatMessage(role: .user, text: trimmed, attachments: attachments)
            threads[index].messages.append(userMessage)

            composerText = ""

            // Show a "Thinking…" bubble while the network call is in flight.
            let thinkingMessage = ChatMessage(role: .assistant, text: "Thinking…")
            threads[index].messages.append(thinkingMessage)
            let thinkingID = thinkingMessage.id
            
            defer {
                if Task.isCancelled {
                    if let threadIndex = threads.firstIndex(where: { $0.id == id }),
                       let idx = threads[threadIndex].messages.firstIndex(where: { $0.id == thinkingID }) {
                        if threads[threadIndex].messages[idx].text == "Thinking…" {
                            threads[threadIndex].messages.remove(at: idx)
                        } else {
                            threads[threadIndex].messages[idx].text += " 🛑 (Cancelled)"
                        }
                        saveThreads()
                    }
                }
            }

            do {
                if Task.isCancelled { return }
                let provider = threads[index].provider
                let service  = AIServiceFactory.service(for: provider)
                let stream   = service.sendStream(message: trimmed, in: threads[index], attachments: attachments)

                var isFirstToken = true
                for try await token in stream {
                    if Task.isCancelled { break }
                    guard let threadIndex = threads.firstIndex(where: { $0.id == id }) else { break }
                    if isFirstToken {
                        if let idx = threads[threadIndex].messages.firstIndex(where: { $0.id == thinkingID }) {
                            threads[threadIndex].messages[idx] = ChatMessage(id: thinkingID, role: .assistant, text: token)
                        }
                        isFirstToken = false
                    } else {
                        if let idx = threads[threadIndex].messages.firstIndex(where: { $0.id == thinkingID }) {
                            let old = threads[threadIndex].messages[idx]
                            threads[threadIndex].messages[idx] = ChatMessage(
                                id: old.id,
                                role: old.role,
                                text: old.text + token,
                                createdAt: old.createdAt,
                                attachments: old.attachments,
                                isLiked: old.isLiked,
                                isDisliked: old.isDisliked
                            )
                        }
                    }
                }

                // Auto-rename thread from first user message
                if let threadIndex = threads.firstIndex(where: { $0.id == id }), threads[threadIndex].title == "New Chat", let firstUserMsg = threads[threadIndex].messages.first(where: { $0.role == .user }) {
                    let preview = String(firstUserMsg.text.prefix(40))
                    threads[threadIndex].title = preview.count < firstUserMsg.text.count ? preview + "…" : preview
                }
            } catch {
                if Task.isCancelled { return }
                guard let threadIndex = threads.firstIndex(where: { $0.id == id }) else { return }
                // Surface the error as a readable assistant message.
                let errText: String
                if let svcError = error as? AIServiceError {
                    errText = svcError.errorDescription ?? error.localizedDescription
                } else {
                    errText = error.localizedDescription
                }
                let errMessage = ChatMessage(role: .assistant, text: "⚠️ \(errText)")
                if let idx = threads[threadIndex].messages.firstIndex(where: { $0.id == thinkingID }) {
                    threads[threadIndex].messages[idx] = errMessage
                } else {
                    threads[threadIndex].messages.append(errMessage)
                }
            }

            saveThreads()
        }
    }

    func regenerateResponse(for messageID: UUID) async {
        guard let id = selectedThreadID,
              let index = threads.firstIndex(where: { $0.id == id }) else { return }
        
        guard let msgIndex = threads[index].messages.firstIndex(where: { $0.id == messageID }) else { return }
        
        // Remove this message and everything after it
        threads[index].messages.removeSubrange(msgIndex...)
        
        // Find the last user message to use as the prompt
        guard let lastUserMsg = threads[index].messages.last(where: { $0.role == .user }) else { return }
        
        isSending = true
        
        currentTask = Task {
            defer { 
                isSending = false
                currentTask = nil
            }
            
            guard let threadIndex = threads.firstIndex(where: { $0.id == id }) else { return }
            
            // Show a "Thinking…" bubble
            let thinkingMessage = ChatMessage(role: .assistant, text: "Thinking…")
            threads[threadIndex].messages.append(thinkingMessage)
            let thinkingID = thinkingMessage.id
            
            defer {
                if Task.isCancelled {
                    if let tIdx = threads.firstIndex(where: { $0.id == id }),
                       let mIdx = threads[tIdx].messages.firstIndex(where: { $0.id == thinkingID }) {
                        if threads[tIdx].messages[mIdx].text == "Thinking…" {
                            threads[tIdx].messages.remove(at: mIdx)
                        } else {
                            threads[tIdx].messages[mIdx].text += " 🛑 (Cancelled)"
                        }
                        saveThreads()
                    }
                }
            }

            do {
                if Task.isCancelled { return }
                let provider = threads[threadIndex].provider
                let service  = AIServiceFactory.service(for: provider)
                let stream   = service.sendStream(message: lastUserMsg.text, in: threads[threadIndex], attachments: lastUserMsg.attachments ?? [])
                
                var isFirstToken = true
                for try await token in stream {
                    if Task.isCancelled { break }
                    guard let tIdx = threads.firstIndex(where: { $0.id == id }) else { break }
                    if isFirstToken {
                        if let idx = threads[tIdx].messages.firstIndex(where: { $0.id == thinkingID }) {
                            threads[tIdx].messages[idx] = ChatMessage(id: thinkingID, role: .assistant, text: token)
                        }
                        isFirstToken = false
                    } else {
                        if let idx = threads[tIdx].messages.firstIndex(where: { $0.id == thinkingID }) {
                            let old = threads[tIdx].messages[idx]
                            threads[tIdx].messages[idx] = ChatMessage(
                                id: old.id,
                                role: old.role,
                                text: old.text + token,
                                createdAt: old.createdAt,
                                attachments: old.attachments,
                                isLiked: old.isLiked,
                                isDisliked: old.isDisliked
                            )
                        }
                    }
                }
            } catch {
                if Task.isCancelled { return }
                guard let tIdx = threads.firstIndex(where: { $0.id == id }) else { return }
                let errText = (error as? AIServiceError)?.errorDescription ?? error.localizedDescription
                let errMessage = ChatMessage(role: .assistant, text: "⚠️ \(errText)")
                if let idx = threads[tIdx].messages.firstIndex(where: { $0.id == thinkingID }) {
                    threads[tIdx].messages[idx] = errMessage
                } else {
                    threads[tIdx].messages.append(errMessage)
                }
            }
            saveThreads()
        }
    }

    func toggleLike(messageID: UUID) {
        guard let id = selectedThreadID,
              let threadIndex = threads.firstIndex(where: { $0.id == id }),
              let msgIndex = threads[threadIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        
        let current = threads[threadIndex].messages[msgIndex].isLiked ?? false
        threads[threadIndex].messages[msgIndex].isLiked = !current
        if !current {
            threads[threadIndex].messages[msgIndex].isDisliked = false
        }
    }

    func toggleDislike(messageID: UUID) {
        guard let id = selectedThreadID,
              let threadIndex = threads.firstIndex(where: { $0.id == id }),
              let msgIndex = threads[threadIndex].messages.firstIndex(where: { $0.id == messageID }) else { return }
        
        let current = threads[threadIndex].messages[msgIndex].isDisliked ?? false
        threads[threadIndex].messages[msgIndex].isDisliked = !current
        if !current {
            threads[threadIndex].messages[msgIndex].isLiked = false
        }
    }



    private func processAttachments(urls: [URL]) async -> [FileAttachment] {
        var results: [FileAttachment] = []
        
        for url in urls {
            // For macOS security-scoped resources
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            
            do {
                let data = try Data(contentsOf: url)
                let base64 = data.base64EncodedString()
                let fileName = url.lastPathComponent
                
                // Simple mime type detection based on extension
                let ext = url.pathExtension.lowercased()
                let mimeType: String
                switch ext {
                case "jpg", "jpeg": mimeType = "image/jpeg"
                case "png": mimeType = "image/png"
                case "gif": mimeType = "image/gif"
                case "webp": mimeType = "image/webp"
                case "pdf": mimeType = "application/pdf"
                case "txt": mimeType = "text/plain"
                default: mimeType = "application/octet-stream"
                }
                
                results.append(FileAttachment(fileName: fileName, mimeType: mimeType, base64Data: base64))
            } catch {
                print("Failed to read file at \(url): \(error.localizedDescription)")
            }
        }
        
        return results
    }


    func deleteAllChats() {
        threads.removeAll()
        selectedThreadID = nil
        composerText = ""
        isSending = false
        saveThreads()
    }
}

// -----------------------------------------------------------------------------
// MARK: - SettingsViewModel
// -----------------------------------------------------------------------------
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var prompts: [PromptItem] = PromptItem.mock
    @Published var customModels: [Provider: [String]] = [:]
    private var providerModels: [Provider: String] = [:]
    private let modelStore = ProviderModelStore()

    // MARK: Provider‑model selection
    func model(for provider: Provider) -> String {
        providerModels[provider] ?? models(for: provider).first ?? ""
    }

    func models(for provider: Provider) -> [String] {
        let allModels = customModels[provider] ?? provider.models
        
        let freeOnly = UserDefaults.standard.bool(forKey: StorageKeys.providerFreeOnlyKey(for: provider.rawValue))
        if freeOnly {
            return provider.filterFreeModels(allModels)
        }
        return allModels
    }

    func setModel(_ modelID: String, for provider: Provider) {
        providerModels[provider] = modelID
        modelStore.save(providerModels)
    }

    func setCustomModels(_ models: [String], for provider: Provider) {
        customModels[provider] = models
        // Persist custom models list
        let key = "settings.customModels.\(provider.rawValue)"
        UserDefaults.standard.set(models, forKey: key)
    }

    func resetProviderModels() {
        providerModels.removeAll()
        customModels.removeAll()
        modelStore.save([:])
        for provider in Provider.allCases {
            UserDefaults.standard.removeObject(forKey: "settings.customModels.\(provider.rawValue)")
        }
    }

    // MARK: Prompt library
    func addPrompt(title: String, text: String) {
        prompts.append(PromptItem(title: title, text: text))
    }
    
    func updatePrompt(id: UUID, title: String, text: String) {
        if let index = prompts.firstIndex(where: { $0.id == id }) {
            prompts[index].title = title
            prompts[index].text = text
            prompts[index].updatedAt = .now
        }
    }
    
    func deletePrompt(id: UUID) {
        prompts.removeAll { $0.id == id }
    }

    func clearPrompts() {
        prompts.removeAll()
    }

    // MARK: API‑key handling (Keychain based)
    /// Save an API key – returns *true* on success.
    func saveAPIKey(_ key: String, for provider: Provider) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            deleteAPIKey(for: provider)
            return true
        }
        do {
            try KeychainService.save(trimmed, for: provider.keychainKey)
            return true
        } catch {
            print("[Keychain] Save error for \(provider): \(error)")
            return false
        }
    }

    /// Load an API key – empty string if none stored.
    func loadAPIKey(for provider: Provider) -> String {
        return KeychainService.load(key: provider.keychainKey) ?? ""
    }

    /// Delete a single provider's key.
    func deleteAPIKey(for provider: Provider) {
        do {
            try KeychainService.delete(key: provider.keychainKey)
        } catch {
            print("[Keychain] Delete error for \(provider): \(error)")
        }
    }

    /// Delete **all** stored keys.
    func deleteAllAPIKeys() {
        for provider in Provider.allCases {
            try? KeychainService.delete(key: provider.keychainKey)
        }
    }

    // MARK: Legacy UserDefaults cleanup (optional)
    /// First launch cleanup – removes any stray values left by the old implementation.
    init() {
        // Load persisted selections
        self.providerModels = modelStore.load()
        
        // Load persisted custom models lists
        for provider in Provider.allCases {
            let key = "settings.customModels.\(provider.rawValue)"
            if let saved = UserDefaults.standard.stringArray(forKey: key) {
                self.customModels[provider] = saved
            }
        }

        for provider in Provider.allCases {
            UserDefaults.standard.removeObject(forKey: Self.keyFor(provider))
        }
    }

    // MARK: Helper – stable UserDefaults key (kept for backwards‑compatibility)
    private static func keyFor(_ provider: Provider) -> String {
        "apiKey.\(String(describing: provider))"
    }
}

// -----------------------------------------------------------------------------
// MARK: - AuthManager
// -----------------------------------------------------------------------------
@MainActor
final class AuthManager: ObservableObject {

    // MARK: - Singleton
    static let shared = AuthManager()

    // MARK: - Published State
    @Published var isSignedIn = false
    @Published var userName: String?
    @Published var userEmail: String?
    @Published var userID: String?
    @Published var errorMessage: String?

    // MARK: - ContentView-compatible computed properties
    var isLoggedIn: Bool { isSignedIn }
    var currentUserName: String? { userName }
    var currentUserEmail: String? { userEmail }
    var authErrorMessage: String? { errorMessage }

    // MARK: - Apple Sign In
    /// Configures the Apple sign-in request (called by ContentView).
    func prepareAppleSignInRequest(_ request: ASAuthorizationAppleIDRequest) {
        request.requestedScopes = [.fullName, .email]
    }

    /// Handles the Apple sign-in result (called by ContentView).
    func handleAppleSignIn(result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else { return }
            do {
                try KeychainService.save(credential.user, for: "appleUserIdentifier")
                if let authCode = credential.authorizationCode,
                   let authCodeString = String(data: authCode, encoding: .utf8) {
                    try KeychainService.save(authCodeString, for: "appleAuthCode")
                }
                if let identityToken = credential.identityToken,
                   let tokenString = String(data: identityToken, encoding: .utf8) {
                    try KeychainService.save(tokenString, for: "appleIdentityToken")
                }
                if let email = credential.email {
                    userEmail = email
                    try? KeychainService.save(email, for: "userEmail")
                } else {
                    userEmail = KeychainService.load(key: "userEmail")
                }
                
                if let fullName = credential.fullName {
                    let name = [fullName.givenName, fullName.familyName]
                        .compactMap { $0 }.joined(separator: " ")
                    if !name.isEmpty {
                        userName = name
                        try? KeychainService.save(name, for: "userName")
                    }
                } else {
                    userName = KeychainService.load(key: "userName")
                }

                userID = credential.user
                isSignedIn = true
                errorMessage = nil
            } catch {
                errorMessage = "Failed to save user data: \(error.localizedDescription)"
                isSignedIn = false
            }
        case .failure(let error):
            errorMessage = "Apple Sign In failed: \(error.localizedDescription)"
            isSignedIn = false
        }
    }

    // MARK: - Google Sign In
    func signInWithGoogle() async throws {
        #if canImport(GoogleSignIn) && canImport(UIKit)
        guard let rootVC = await MainActor.run(body: {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: { $0.isKeyWindow })?
                .rootViewController
        }) else {
            throw AuthError.noPresentingViewController
        }
        #if canImport(FirebaseCore)
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: FirebaseApp.app()?.options.clientID ?? "")
        #endif
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootVC)
        let user = result.user
        guard let idToken = user.idToken?.tokenString else { throw AuthError.missingToken }
        try KeychainService.save(idToken, for: "googleIDToken")
        try KeychainService.save(user.accessToken.tokenString, for: "googleAccessToken")
        self.userName = user.profile?.name
        self.userEmail = user.profile?.email
        self.userID = user.userID
        self.isSignedIn = true
        self.errorMessage = nil
        #else
        throw AuthError.googleSignInNotAvailable
        #endif
    }

    // MARK: - Email / Password Sign In
    func signInWithEmail(email: String, password: String) async throws {
        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            try await finishFirebaseAuth(user: result.user, email: email)
        } catch {
            errorMessage = error.localizedDescription
            isSignedIn = false
            throw error
        }
        #else
        throw AuthError.firebaseNotAvailable
        #endif
    }

    // MARK: - Email / Password Sign Up
    func signUpWithEmail(email: String, password: String) async throws {
        #if canImport(FirebaseAuth)
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            try await finishFirebaseAuth(user: result.user, email: email)
        } catch {
            errorMessage = error.localizedDescription
            isSignedIn = false
            throw error
        }
        #else
        throw AuthError.firebaseNotAvailable
        #endif
    }

    // MARK: - Sign Out
    func signOut() throws {
        try? KeychainService.delete(key: "appleUserIdentifier")
        try? KeychainService.delete(key: "appleAuthCode")
        try? KeychainService.delete(key: "appleIdentityToken")
        try? KeychainService.delete(key: "googleIDToken")
        try? KeychainService.delete(key: "googleAccessToken")
        try? KeychainService.delete(key: "firebaseUID")
        try? KeychainService.delete(key: "firebaseIDToken")
        try? KeychainService.delete(key: "userName")
        try? KeychainService.delete(key: "userEmail")
        #if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
        #endif
        #if canImport(FirebaseAuth)
        try Auth.auth().signOut()
        #endif
        isSignedIn = false
        userName = nil
        userEmail = nil
        userID = nil
        errorMessage = nil
    }

    // MARK: - Human-readable error messages
    func userFacingMessage(for error: Error) -> String {
        let nsError = error as NSError
        // Firebase Auth Keychain error on macOS (often code 17006 or internal error with -34018)
        if nsError.domain == "FIRAuthErrorDomain" || nsError.localizedDescription.contains("keychain") {
            return "🔐 Keychain Access Required: Please enable 'Keychain Sharing' in Xcode (Signing & Capabilities) to stay signed in on macOS."
        }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    // MARK: - Forgot Password / OTP Reset

    /// Step 1 – Sends a Firebase password-reset email that contains the oobCode
    /// users enter as their "OTP".
    func sendPasswordResetOTP(email: String) async throws {
        #if canImport(FirebaseAuth)
        try await Auth.auth().sendPasswordReset(withEmail: email)
        #else
        throw AuthError.firebaseNotAvailable
        #endif
    }

    /// Step 2 – Validates the oobCode (the reset code from the Firebase email link).
    /// Throws if the code is invalid or expired.
    func verifyPasswordResetCode(_ code: String) async throws {
        #if canImport(FirebaseAuth)
        _ = try await Auth.auth().verifyPasswordResetCode(code)
        #else
        throw AuthError.firebaseNotAvailable
        #endif
    }

    /// Step 3 – Applies the new password using the verified oobCode.
    func confirmPasswordReset(code: String, newPassword: String) async throws {
        #if canImport(FirebaseAuth)
        try await Auth.auth().confirmPasswordReset(withCode: code, newPassword: newPassword)
        #else
        throw AuthError.firebaseNotAvailable
        #endif
    }

    // MARK: - Session Restore (called on every app launch)
    /// Silently restores the previous sign-in session so the user stays logged in.
    func restoreSession() async {
        // Already signed in – nothing to do.
        if isSignedIn { return }

        // 1. Try to restore a Google session silently (iOS only).
        #if canImport(GoogleSignIn) && canImport(UIKit)
        if let user = try? await GIDSignIn.sharedInstance.restorePreviousSignIn() {
            // Refresh the keychain token so it doesn't go stale.
            if let idToken = user.idToken?.tokenString {
                try? KeychainService.save(idToken, for: "googleIDToken")
                try? KeychainService.save(user.accessToken.tokenString, for: "googleAccessToken")
            }
            self.userName = user.profile?.name
            self.userEmail = user.profile?.email
            self.userID = user.userID
            self.isSignedIn = true
            return
        }
        #endif

        // 2. Fall back to keychain presence checks for Apple / Firebase.
        checkAuthState()
    }

    // MARK: - Check Auth State (keychain-only, synchronous)
    func checkAuthState() {
        let hasAppleID   = KeychainService.load(key: "appleUserIdentifier") != nil
        let hasGoogleID  = KeychainService.load(key: "googleIDToken") != nil
        let hasFirebaseUID = KeychainService.load(key: "firebaseUID") != nil
        
        self.isSignedIn = hasAppleID || hasGoogleID || hasFirebaseUID
        
        if self.isSignedIn {
            self.userName = KeychainService.load(key: "userName")
            self.userEmail = KeychainService.load(key: "userEmail")
            self.userID = KeychainService.load(key: "firebaseUID") ?? KeychainService.load(key: "appleUserIdentifier") ?? KeychainService.load(key: "googleIDToken")
            
            #if canImport(FirebaseAuth)
            if let user = Auth.auth().currentUser {
                if self.userName == nil { self.userName = user.displayName }
                if self.userEmail == nil { self.userEmail = user.email }
            }
            #endif
        }
    }

    // MARK: - Private helpers
    #if canImport(FirebaseAuth)
    private func finishFirebaseAuth(user: User, email: String) async throws {
        try KeychainService.save(user.uid, for: "firebaseUID")
        let token = try await user.getIDToken()
        try KeychainService.save(token, for: "firebaseIDToken")
        self.userName = user.displayName ?? email.components(separatedBy: "@").first
        self.userEmail = user.email
        self.userID = user.uid
        self.isSignedIn = true
        self.errorMessage = nil
    }
    #endif
}

// MARK: - Auth Errors
enum AuthError: LocalizedError {
    case noPresentingViewController
    case missingToken
    case googleSignInNotAvailable
    case firebaseNotAvailable

    var errorDescription: String? {
        switch self {
        case .noPresentingViewController: return "No presenting view controller available for sign in."
        case .missingToken:               return "Missing authentication token from provider."
        case .googleSignInNotAvailable:   return "Google Sign In is not available on this platform."
        case .firebaseNotAvailable:       return "Firebase Authentication is not available on this platform."
        }
    }
}

