import SwiftUI

struct MessageAreaView: View {
    @ObservedObject var chatViewModel: ChatViewModel
    let thread: ChatThread
    @FocusState.Binding var isComposerFocused: Bool
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(groupedMessages, id: \.day) { group in
                        VStack(alignment: .leading, spacing: 10) {
                            Text(group.title)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)

                            ForEach(group.messages) { message in
                                MessageBubbleView(message: message, chatViewModel: chatViewModel)
                                    .id(message.id)
                            }
                        }
                    }
                }
                .padding(.vertical, 14)
            }
            #if !os(macOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .onChange(of: thread.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isComposerFocused = false
        }
        .simultaneousGesture(
            DragGesture().onChanged { _ in
                isComposerFocused = false
            }
        )
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastID = thread.messages.last?.id {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo(lastID, anchor: .bottom)
            }
        }
    }

    private var groupedMessages: [DayGroup] {
        let groups = Dictionary(grouping: thread.messages) { Calendar.current.startOfDay(for: $0.createdAt) }
        return groups
            .map { day, messages in
                DayGroup(
                    day: day,
                    title: Calendar.current.isDateInToday(day) ? "Today" : day.formatted(date: .abbreviated, time: .omitted),
                    messages: messages.sorted(by: { $0.createdAt < $1.createdAt })
                )
            }
            .sorted(by: { $0.day < $1.day })
    }

    struct DayGroup {
        let day: Date
        let title: String
        let messages: [ChatMessage]
    }
}
