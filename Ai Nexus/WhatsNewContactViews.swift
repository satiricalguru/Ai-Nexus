import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - What's New

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showFullNotes = false

    var body: some View {
        let accent = Color.accentColor
        let headerIconColor = Color.orange.opacity(0.9)

        VStack(spacing: 0) {
            // Close button row
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .padding(20)
                }
                .buttonStyle(.plain)
            }

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 44, weight: .bold))
                            .foregroundStyle(headerIconColor)
                        Text("What's New")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(.primary)
                        Text("Version 1.5")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 6)

                    // Features list
                    VStack(spacing: 20) {
                        FeatureRow(
                            icon: "paintpalette.fill",
                            color: headerIconColor,
                            title: "Premium Branding",
                            description: "All-new monochromatic visual identity with high-quality app icons and refined accent options."
                        )
                        FeatureRow(
                            icon: "cpu.fill",
                            color: headerIconColor,
                            title: "Enhanced Provider Support",
                            description: "Deep integration with OpenAI, Anthropic, Google Gemini, Groq, and local Ollama instances."
                        )
                        FeatureRow(
                            icon: "bolt.fill",
                            color: headerIconColor,
                            title: "Real-time Streaming",
                            description: "Optimized chat engine for instant, token-by-token response streaming across all models."
                        )
                    }
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 720)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }

            // Footer buttons
            VStack(spacing: 14) {
                Button { showFullNotes = true } label: {
                    Text("Full release notes")
                        .font(.headline)
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    Text("Continue")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 520)
                        .padding(.vertical, 14)
                        .background(accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity)
            .background(
                Group {
                    #if os(macOS)
                    Rectangle().fill(.ultraThinMaterial)
                    #else
                    Color.clear
                    #endif
                }
            )
        }
        .background(
            // Respect system light/dark backgrounds for readability
            Group {
                #if os(macOS)
                Color(nsColor: NSColor.windowBackgroundColor)
                #else
                Color(uiColor: UIColor.systemBackground)
                #endif
            }
        )
        .sheet(isPresented: $showFullNotes) { FullReleaseNotesView() }
    }
}

struct FeatureRow: View {
    let icon: String; let color: Color; let title: String; let description: String
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FullReleaseNotesView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ReleaseNoteSection(version: "1.5", notes: [
                        "New monochromatic premium branding and application icons.",
                        "Enhanced support for multi-provider streaming (OpenAI, Anthropic, Google, Groq, Ollama).",
                        "Redesigned Nexus Plus upgrade UI for a more compact and informative experience.",
                        "Improved loading states with a minimalist rotating 'N' animation.",
                        "Fixed an issue where a default welcome message appeared on first launch.",
                        "Fixed variable shadowing errors in SwiftUI views.",
                        "Optimized asset catalog for smaller application bundle size.",
                        "Improved reliability of image and file attachments during chat sessions."
                    ])

                    ReleaseNoteSection(version: "1.2", notes: [
                        "Added Responses API support for OpenAI.",
                        "Added reasoning effort settings for OpenAI and Anthropic.",
                        "Improved UI layout for settings.",
                        "Fixed minor bugs in theme selection."
                    ])

                    ReleaseNoteSection(version: "1.1", notes: [
                        "Multi-modal support (Images & Files).",
                        "Custom accent colors.",
                        "Haptic feedback settings."
                    ])

                    ReleaseNoteSection(version: "1.0", notes: [
                        "Initial release with Multi-provider support.",
                        "Syntax highlighting and code themes.",
                        "iCloud sync for prompts."
                    ])
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Release Notes")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(minWidth: 400, minHeight: 450)
    }
}

struct ReleaseNoteSection: View {
    let version: String
    let notes: [String]
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Version \(version)")
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(notes, id: \.self) { note in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•").foregroundStyle(.secondary)
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.leading, 4)
        }
    }
}

// MARK: - Contact

struct ContactLinkRow: View {
    @Environment(\.openURL) private var openURL
    let title: String; let icon: String; let subtitle: String; let url: String
    var body: some View {
        Button {
            guard let destination = URL(string: url) else { return }
            openURL(destination)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 22).foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right").font(.caption).foregroundStyle(.tertiary)
            }.padding(.vertical, 4).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

struct ContactView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        Form {
            Section("Contact") {
                ContactLinkRow(title: "Email Feedback", icon: "envelope.fill", subtitle: "feedback@ainexus.app", url: "mailto:feedback@ainexus.app")
                ContactLinkRow(title: "Bluesky", icon: "cloud.fill", subtitle: "@ainexus", url: "https://bsky.app/profile/ainexus")
                ContactLinkRow(title: "Threads", icon: "at.circle.fill", subtitle: "@ainexus", url: "https://www.threads.net/@ainexus")
                ContactLinkRow(title: "X (Twitter)", icon: "x.circle.fill", subtitle: "@ainexus", url: "https://x.com/ainexus")
            }
            Section("Footer") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version \(AppMeta.versionString)").font(.subheadline).foregroundStyle(.secondary)
                        Text("AI Nexus").font(.headline)
                    }
                    Spacer()
                    Image(systemName: "brain.head.profile").font(.system(size: 30)).foregroundStyle(.secondary)
                }
            }
        }
        .settingsListStyle()
        .navigationTitle("Contact")
        .settingsBackButton(dismiss: dismiss)
    }
}

