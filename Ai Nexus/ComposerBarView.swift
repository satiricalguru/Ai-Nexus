import SwiftUI

struct ComposerBarView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var voiceManager: VoiceManager
    @Binding var selectedFileURLs: [URL]
    @FocusState.Binding var isFocused: Bool
    let defaultProvider: Provider
    let settingsViewModel: SettingsViewModel
    
    @State private var localText: String = ""

    var body: some View {
        VStack(spacing: 8) {
            // Attachment preview bar
            if !selectedFileURLs.isEmpty {
                attachmentPreview
            }

            HStack(spacing: 12) {
                attachmentButton

                inputField

                voiceButton

                sendButton
            }
        }
        .padding(.top, 10)
        .onAppear {
            localText = chatViewModel.composerText
        }
        .onChange(of: chatViewModel.composerText) { _, newValue in
            if newValue != localText {
                localText = newValue
            }
        }
    }

    private var attachmentPreview: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedFileURLs, id: \.self) { url in
                    HStack(spacing: 6) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.blue)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .lineLimit(1)
                        Button {
                            selectedFileURLs.removeAll(where: { $0 == url })
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 4)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var attachmentButton: some View {
        Button {
            // This will need to trigger the parent's file importer
            // For now we assume the parent handles it via a state change
            NotificationCenter.default.post(name: NSNotification.Name("TriggerFilePicker"), object: nil)
        } label: {
            Image(systemName: "plus")
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
    }

    private var inputField: some View {
        HStack(spacing: 0) {
            TextField(voiceManager.isRecording ? "Listening..." : "Message", text: $localText)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }
                .onChange(of: localText) { _, newValue in
                    chatViewModel.composerText = newValue
                }
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            
            if voiceManager.isRecording {
                RecordingIndicatorDot()
                    .padding(.trailing, 10)
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(voiceManager.isRecording ? Color.red.opacity(0.5) : Color.clear, lineWidth: 2)
        )
    }

    private var voiceButton: some View {
        Button {
            handleVoiceButton()
        } label: {
            Image(systemName: voiceManager.isRecording ? "stop.fill" : "mic.fill")
                .font(.title3)
                .frame(width: 40, height: 40)
                .background(voiceManager.isRecording ? AnyShapeStyle(Color.red.opacity(0.1)) : AnyShapeStyle(.regularMaterial), in: Circle())
                .foregroundStyle(voiceManager.isRecording ? .red : .accentColor)
        }
        .buttonStyle(.plain)
    }

    private var sendButton: some View {
        Button {
            if chatViewModel.isSending {
                chatViewModel.stopGenerating()
            } else {
                sendMessage()
            }
        } label: {
            Image(systemName: chatViewModel.isSending ? "stop.circle.fill" : "paperplane.fill")
                .font(.headline)
                .frame(width: 40, height: 40)
                .background(localText.isEmpty && selectedFileURLs.isEmpty && !chatViewModel.isSending ? AnyShapeStyle(Color.secondary.opacity(0.1)) : AnyShapeStyle(Color.accentColor), in: Circle())
                .foregroundStyle(localText.isEmpty && selectedFileURLs.isEmpty && !chatViewModel.isSending ? Color.secondary : Color.white)
        }
        .buttonStyle(.plain)
    }

    private func handleVoiceButton() {
        if voiceManager.isRecording {
            voiceManager.stopRecording()
        } else {
            Task {
                let authorized = await voiceManager.requestPermissions()
                if authorized {
                    voiceManager.startRecording()
                }
            }
        }
    }

    private func sendMessage() {
        let urls = selectedFileURLs
        selectedFileURLs.removeAll()
        isFocused = false
        
        Task {
            await chatViewModel.sendCurrentMessage(
                defaultProvider: defaultProvider,
                defaultModel: settingsViewModel.model(for: defaultProvider),
                attachmentURLs: urls
            )
            localText = ""
        }
    }
}
