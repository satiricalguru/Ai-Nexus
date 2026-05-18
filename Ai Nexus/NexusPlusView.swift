import SwiftUI

// MARK: - NexusPlusView

struct NexusPlusView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var showPayment = false
    @AppStorage("nexusPlusActive") private var isPlus = false

    private let features: [(icon: String, color: Color, title: String, body: String)] = [
        ("bolt.fill",         .orange,  "Real-time Streaming",   "Instant, token-by-token responses from all providers."),
        ("eye.fill",          .blue,    "Vision & File Support", "Send images and documents to any vision-enabled model."),
        ("cpu.fill",          .purple,  "Advanced AI Access",    "Full access to GPT-4o, Claude 3.5, and Gemini Pro."),
        ("text.book.closed.fill", .indigo, "Prompt Library",     "Save and reuse complex system instructions and personalities."),
        ("gearshape.2.fill",  .teal,    "Custom Models",         "Integrate any model via OpenRouter or local Ollama."),
        ("paintpalette.fill", .pink,    "Premium Branding",      "Unlock exclusive accent colors and monochromatic themes.")
    ]

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: scheme == .dark
                    ? [Color(red:0.10, green:0.10, blue:0.12), Color.black]
                    : [Color(red:0.95, green:0.95, blue:0.97), Color.white],
                startPoint: .top, endPoint: .bottom
            ).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                            .padding(.top, 24)
                        Text("Nexus Plus").font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundStyle(LinearGradient(colors: [.primary, .primary.opacity(0.7)], startPoint: .leading, endPoint: .trailing))
                        Text(isPlus ? "You're already a Nexus Plus member ✦" : "Upgrade for the full AI experience")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }

                    VStack(spacing: 8) {
                        ForEach(features, id: \.title) { f in
                            HStack(spacing: 16) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10).fill(f.color.opacity(scheme == .dark ? 0.25 : 0.12)).frame(width: 40, height: 40)
                                    Image(systemName: f.icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(f.color)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(f.title).font(.headline)
                                    Text(f.body).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }.padding(12).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }.padding(.horizontal, 4)

                    if isPlus {
                        Label("Active", systemImage: "checkmark.seal.fill").font(.headline).foregroundStyle(.green)
                            .padding(.vertical, 14).frame(maxWidth: .infinity).background(.regularMaterial, in: Capsule())
                    } else {
                        VStack(spacing: 8) {
                            Text("$4.99 / month  ·  Cancel anytime").font(.footnote).foregroundStyle(.secondary)
                            Button { showPayment = true } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "sparkles"); Text("Subscribe to Nexus Plus").fontWeight(.bold)
                                }.frame(maxWidth: .infinity).padding(.vertical, 16)
                                    .background(LinearGradient(colors: [.primary, .primary.opacity(0.8)], startPoint: .leading, endPoint: .trailing), in: Capsule())
                                    .foregroundStyle(scheme == .dark ? .black : .white).shadow(color: .primary.opacity(0.2), radius: 12, y: 6)
                            }.buttonStyle(.plain)
                        }
                    }
                    Spacer(minLength: 16)
                }.padding(.horizontal, 20)
            }

            HStack { Spacer(); Button { dismiss() } label: { Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary).padding(16) } }
        }
        .frame(minWidth: 350, minHeight: 450)
        .sheet(isPresented: $showPayment) {
            NexusPaymentView(isPlus: $isPlus)
                #if !os(macOS)
                .presentationDetents([.medium])
                #endif
        }
    }
}

// MARK: - Test-mode payment sheet

struct NexusPaymentView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @Binding var isPlus: Bool
    @State private var isPaying = false
    @State private var didPay   = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if didPay {
                    VStack(spacing: 24) {
                        ZStack {
                            Circle().fill(LinearGradient(colors: [.green, .teal], startPoint: .topLeading, endPoint: .bottomTrailing)).frame(width: 80, height: 80)
                            Image(systemName: "checkmark").font(.system(size: 36, weight: .bold)).foregroundStyle(.white)
                        }
                        VStack(spacing: 8) {
                            Text("Payment Successful!").font(.title2).bold()
                            Text("Welcome to Nexus Plus.").multilineTextAlignment(.center).foregroundStyle(.secondary)
                        }
                        Button("Done") { isPlus = true; dismiss() }.buttonStyle(.borderedProminent).controlSize(.large)
                    }.padding()
                } else {
                    VStack(alignment: .center, spacing: 20) {
                        Image("AppLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Label("TEST MODE — No real charge", systemImage: "flask.fill").font(.caption).foregroundStyle(.orange)
                                .padding(10).background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                            
                            Button {
                                isPaying = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    isPaying = false
                                    withAnimation(.spring(response: 0.4)) { didPay = true }
                                }
                            } label: {
                                Group {
                                    if isPaying { ProgressView().tint(.white) } else { Text("Pay $4.99").fontWeight(.bold) }
                                }.frame(maxWidth: .infinity).padding(.vertical, 16)
                                    .background(LinearGradient(colors: [.primary, .primary.opacity(0.8)], startPoint: .leading, endPoint: .trailing), in: Capsule())
                                    .foregroundStyle(scheme == .dark ? .black : .white)
                            }.buttonStyle(.plain).disabled(isPaying)
                        }
                    }.padding()
                    Spacer()
                }
            }
            .navigationTitle("Nexus Plus — Checkout")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .frame(minWidth: 340, minHeight: 360)
        }
    }
}
