import SwiftUI

struct RecordingIndicatorDot: View {
    @State private var isVisible = true

    var body: some View {
        Circle()
            .fill(.red)
            .frame(width: 8, height: 8)
            .opacity(isVisible ? 1 : 0.2)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isVisible = false
                }
            }
    }
}
