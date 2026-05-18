import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Shared Helper Views

struct SettingsRow<Trailing: View>: View {
    let title: String
    let icon: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 28, height: 28)
                .foregroundStyle(.primary)
            Text(title).font(.body)
            Spacer()
            trailing
        }
        .padding(.vertical, 4)
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(title: String, icon: String) {
        self.init(title: title, icon: icon) { EmptyView() }
    }
}

struct CardRow<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}

struct NavigationRow: View {
    let title: String
    let icon: String
    var trailingText: String = ""

    var body: some View {
        SettingsRow(title: title, icon: icon) {
            HStack(spacing: 8) {
                if !trailingText.isEmpty {
                    Text(trailingText).foregroundStyle(.secondary).lineLimit(1)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}

struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(.secondary)
            Toggle(title, isOn: $isOn)
        }
        .padding(.vertical, 2)
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content
    var body: some View {
        Section(header: Text(title)) {
            VStack(spacing: 12) { content }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}

struct ColorSwatch: View {
    @Binding var hexValue: String
    var body: some View {
        Menu {
            Button("Blue") { hexValue = "#4F8CFF" }
            Button("Green") { hexValue = "#4CD964" }
            Button("Orange") { hexValue = "#FF9F0A" }
            Button("Pink") { hexValue = "#FF5C93" }
        } label: {
            Circle().fill(Color(hex: hexValue) ?? .blue).frame(width: 26, height: 26)
                .overlay(Circle().stroke(LinearGradient(colors: [.white.opacity(0.5), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5))
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
        }
    }
}

struct SettingsToggleRow: View {
    let title: String; let icon: String; let description: String
    @Binding var isOn: Bool
    var isLocked: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .medium)).frame(width: 28, height: 28).foregroundStyle(.primary)
                Text(title).font(.body.weight(.medium))
                Spacer()
                if isLocked { Image(systemName: "lock.fill").font(.caption).foregroundStyle(.secondary).padding(.trailing, 4) }
                Toggle("", isOn: $isOn).labelsHidden().disabled(isLocked).tint(.green)
            }
            Text(description).font(.system(size: 13)).foregroundStyle(.secondary).padding(.leading, 40).fixedSize(horizontal: false, vertical: true)
        }.padding(.vertical, 8)
    }
}

struct SettingsActionRow: View {
    let title: String; let icon: String; let description: String; let actionTitle: String; let action: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: icon).font(.system(size: 16, weight: .medium)).frame(width: 28, height: 28).foregroundStyle(.primary)
                Text(title).font(.body.weight(.medium))
                Spacer()
                Button(actionTitle) { action() }.font(.body).foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                Text(description).font(.system(size: 13)).foregroundStyle(.secondary)
                Image(systemName: "info.circle").font(.caption2).foregroundStyle(.cyan)
            }.padding(.leading, 40)
        }.padding(.vertical, 8)
    }
}

struct SettingsPickerRow<Label: View, MenuContent: View>: View {
    let title: String; let icon: String
    @ViewBuilder var menuContent: MenuContent
    @ViewBuilder var labelContent: Label

    var body: some View {
        Menu {
            menuContent
        } label: {
            SettingsRow(title: title, icon: icon) {
                HStack(spacing: 4) {
                    labelContent.foregroundStyle(.secondary)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2).foregroundStyle(.tertiary)
                }.contentShape(Rectangle())
            }.contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct FontSizeStepper: View {
    @Binding var fontSize: Double
    var body: some View {
        HStack(spacing: 0) {
            Button { if fontSize > 12 { fontSize -= 1 } } label: {
                Image(systemName: "minus").font(.system(size: 14, weight: .bold)).frame(width: 36, height: 32).contentShape(Rectangle())
            }
            Divider().frame(height: 20)
            Button { if fontSize < 24 { fontSize += 1 } } label: {
                Image(systemName: "plus").font(.system(size: 14, weight: .bold)).frame(width: 36, height: 32).contentShape(Rectangle())
            }
        }.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10)).buttonStyle(.plain)
    }
}

struct CodePreview: View {
    let fontSize: Double; let syntaxStyle: SyntaxHighlightingStyle; let codeScheme: CodeColourScheme

    private enum Token { case keyword, variable, function, string, punctuation }

    private func color(for token: Token) -> Color {
        if syntaxStyle == .none { return .primary }
        switch codeScheme {
        case .dracula:
            switch token {
            case .keyword: return Color(red: 1.00, green: 0.48, blue: 0.77)
            case .variable: return Color(red: 0.55, green: 1.00, blue: 0.55)
            case .function: return Color(red: 0.33, green: 0.91, blue: 0.98)
            case .string: return Color(red: 0.95, green: 0.98, blue: 0.58)
            case .punctuation: return .white
            }
        case .nord:
            switch token {
            case .keyword: return Color(red: 0.51, green: 0.63, blue: 0.76)
            case .variable: return Color(red: 0.56, green: 0.74, blue: 0.73)
            case .function: return Color(red: 0.53, green: 0.75, blue: 0.82)
            case .string: return Color(red: 0.64, green: 0.75, blue: 0.55)
            case .punctuation: return Color(red: 0.85, green: 0.87, blue: 0.91)
            }
        case .solarizedDark:
            switch token {
            case .keyword: return Color(red: 0.52, green: 0.60, blue: 0.00)
            case .variable: return Color(red: 0.15, green: 0.55, blue: 0.82)
            case .function: return Color(red: 0.71, green: 0.20, blue: 0.11)
            case .string: return Color(red: 0.16, green: 0.63, blue: 0.60)
            case .punctuation: return Color(red: 0.51, green: 0.58, blue: 0.59)
            }
        case .system:
            switch token {
            case .keyword: return .blue; case .variable: return .cyan; case .function: return .orange
            case .string: return .green; case .punctuation: return .primary
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("javascript").font(.system(size: 12, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "doc.on.doc").font(.system(size: 12)).foregroundStyle(.secondary)
            }.padding(.horizontal, 12).padding(.vertical, 8).background(Color.white.opacity(0.05))
            Divider().opacity(0.2)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 0) {
                    Text("const ").foregroundStyle(color(for: .keyword))
                    Text("foo").foregroundStyle(color(for: .variable))
                    Text(" = () => {").foregroundStyle(color(for: .punctuation))
                }
                HStack(spacing: 0) {
                    Text("  console").foregroundStyle(color(for: .function))
                    Text(".").foregroundStyle(color(for: .punctuation))
                    Text("log").foregroundStyle(color(for: .variable))
                    Text("(").foregroundStyle(color(for: .punctuation))
                    Text("'Bar'").foregroundStyle(color(for: .string))
                    Text(")").foregroundStyle(color(for: .punctuation))
                }
                Text("}").foregroundStyle(color(for: .punctuation))
            }.font(.system(size: fontSize - 3, design: .monospaced)).padding(12).frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(.top, 12)
    }
}

// MARK: - Thinking Animation

struct NexusThinkingAnimation: View {
    @State private var rotation: Double = 0
    var body: some View {
        ZStack {
            Circle().stroke(
                AngularGradient(gradient: Gradient(colors: [Color.accentColor, Color.accentColor.opacity(0.1), Color.accentColor]), center: .center),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            ).frame(width: 20, height: 20).rotationEffect(.degrees(rotation))
            Text("N").font(.system(size: 11, weight: .black, design: .rounded)).foregroundStyle(Color.accentColor)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { rotation = 360 }
        }
    }
}

// MARK: - AppMeta

enum AppMeta {
    static var versionString: String { "1.5" }
}

// MARK: - Color(hex:) Extension

extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        let red = Double((value >> 16) & 0xFF) / 255.0
        let green = Double((value >> 8) & 0xFF) / 255.0
        let blue = Double(value & 0xFF) / 255.0
        self = Color(red: red, green: green, blue: blue)
    }
}

// MARK: - View Extensions

extension View {
    @ViewBuilder
    func settingsListStyle() -> some View {
        #if os(macOS)
        self.formStyle(.grouped)
        #else
        self.listStyle(.insetGrouped)
        #endif
    }

    @ViewBuilder
    func settingsBackButton(dismiss: DismissAction) -> some View {
        self.toolbar {
            ToolbarItem {
                Button { dismiss() } label: { Label("Back", systemImage: "chevron.left") }
            }
        }
    }
}

// MARK: - Clipboard Utility

func copyToClipboard(_ text: String) {
    #if os(macOS)
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(text, forType: .string)
    #else
    UIPasteboard.general.string = text
    #endif
}
