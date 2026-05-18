import SwiftUI

enum AppThemeMode: String, CaseIterable, Identifiable {
    case native
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .native: return "Native"
        case .custom: return "Custom"
        }
    }

    var icon: String { "paintpalette" }
}

enum AppColourScheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var icon: String { "circle.lefthalf.filled" }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum SyntaxHighlightingStyle: String, CaseIterable, Identifiable {
    case none
    case basic
    case chatgpt
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .basic: return "Basic"
        case .chatgpt: return "ChatGPT"
        case .advanced: return "Advanced"
        }
    }

    var icon: String { "brackets.square" }
}

enum CodeColourScheme: String, CaseIterable, Identifiable {
    case system
    case dracula
    case nord
    case solarizedDark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .dracula: return "Dracula"
        case .nord: return "Nord"
        case .solarizedDark: return "Solarized Dark"
        }
    }

    var icon: String { "circle.lefthalf.filled" }
}

extension Color {
    static let cardBackground = Color.white.opacity(0.08)
    static let bubbleUser = Color.blue.opacity(0.28)
    static let bubbleAssistant = Color.white.opacity(0.10)
}
