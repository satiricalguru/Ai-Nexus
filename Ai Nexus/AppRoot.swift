import SwiftUI
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@main
struct AiNexusApp: App {
    init() {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    #if canImport(GoogleSignIn)
                    _ = GIDSignIn.sharedInstance.handle(url)
                    #endif
                }
        }
        #if os(macOS)
        .defaultSize(width: 1200, height: 760)
        #endif
    }
}
