import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()

    @AppStorage(StorageKeys.appTheme) private var appThemeRaw = AppThemeMode.native.rawValue
    @AppStorage(StorageKeys.appColourScheme) private var appColourSchemeRaw = AppColourScheme.dark.rawValue
    @AppStorage(StorageKeys.lightAccentHex) private var lightAccentHex = "#4F8CFF"
    @AppStorage(StorageKeys.darkAccentHex) private var darkAccentHex = "#6FB7FF"

    #if os(macOS)
    @State private var sidebarSelection: SidebarDestination? = .chat
    #endif

    private var appTheme: AppThemeMode {
        AppThemeMode(rawValue: appThemeRaw) ?? .native
    }

    private var appColourScheme: AppColourScheme {
        AppColourScheme(rawValue: appColourSchemeRaw) ?? .dark
    }

    private var resolvedColorScheme: ColorScheme? {
        appTheme == .native ? nil : appColourScheme.colorScheme
    }

    private var accentColor: Color {
        if appColourScheme == .light {
            return Color(hex: lightAccentHex) ?? .blue
        }
        return Color(hex: darkAccentHex) ?? .blue
    }

    var body: some View {
        Group {
            if authManager.isLoggedIn {
                Group {
                    #if os(macOS)
                    macLayout
                    #else
                    iOSLayout
                    #endif
                }
                .preferredColorScheme(resolvedColorScheme)
                .tint(accentColor)
            } else {
                LoginView(authManager: authManager)
                    .preferredColorScheme(resolvedColorScheme)
                    .tint(accentColor)
            }
        }
        // Restore saved session on every launch so users aren't logged out.
        .task { await authManager.restoreSession() }
    }

    private var iOSLayout: some View {
        TabView {
            NavigationStack {
                ChatWorkspaceView(chatViewModel: chatViewModel, settingsViewModel: settingsViewModel)
            }
            .tabItem {
                Label("Chat", systemImage: "message.fill")
            }

            NavigationStack {
                SettingsHomeView(chatViewModel: chatViewModel, settingsViewModel: settingsViewModel)
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
    }

    #if os(macOS)
    private var macLayout: some View {
        NavigationSplitView {
            List(SidebarDestination.allCases) { destination in
                Button {
                    sidebarSelection = destination
                } label: {
                    Label(destination.title, systemImage: destination.icon)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .listRowBackground(
                    sidebarSelection == destination
                        ? Color.accentColor.opacity(0.22)
                        : Color.clear
                )
            }
            .navigationTitle("AI Nexus")
        } detail: {
            NavigationStack {
                Group {
                    switch sidebarSelection {
                    case .chat:
                        ChatWorkspaceView(chatViewModel: chatViewModel, settingsViewModel: settingsViewModel)
                    case .settings:
                        SettingsHomeView(chatViewModel: chatViewModel, settingsViewModel: settingsViewModel)
                    case .contact:
                        ContactView()
                    case .none:
                        Text("Select a section")
                            .foregroundStyle(.secondary)
                    }
                }
                .id(sidebarSelection)
            }
        }
    }
    #endif
}

enum SidebarDestination: String, CaseIterable, Identifiable {
    case chat, settings, contact

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chat: return "Chat"
        case .settings: return "Settings"
        case .contact: return "Contact"
        }
    }

    var icon: String {
        switch self {
        case .chat: return "message"
        case .settings: return "gearshape"
        case .contact: return "person.crop.circle"
        }
    }
}

#Preview {
    ContentView()
}
