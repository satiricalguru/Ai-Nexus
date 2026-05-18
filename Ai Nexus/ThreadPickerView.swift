import SwiftUI

// MARK: - ThreadPickerView --------------------------------------------------

struct ThreadPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var chatViewModel: ChatViewModel

    @AppStorage(StorageKeys.defaultProvider) private var defaultProviderRaw = Provider.openrouter.rawValue

    @State private var showDeleteAllConfirmation = false

    var body: some View {
        NavigationStack {
            List {
                if chatViewModel.threads.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 36))
                            .foregroundStyle(.secondary)
                        Text("No chats yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("Start a new conversation")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(chatViewModel.threads) { thread in
                        Button {
                            chatViewModel.selectedThreadID = thread.id
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(thread.title)
                                Text(thread.modelID)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        chatViewModel.deleteThreads(at: indexSet)
                    }
                }
            }
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem {
                    Button {
                        let provider = Provider(rawValue: defaultProviderRaw) ?? .openrouter
                        chatViewModel.newChat(defaultProvider: provider, defaultModel: provider.models.first ?? "openrouter/auto")
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}
