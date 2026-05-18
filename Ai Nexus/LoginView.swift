import SwiftUI
import AuthenticationServices
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - LoginView ---------------------------------------------------------

struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage: String?
    @State private var isBusy = false
    @State private var isLoading = false
    @State private var showForgotPassword = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color(red: 0.06, green: 0.06, blue: 0.12), Color.black]
                    : [Color.white.opacity(0.95), Color(red: 0.94, green: 0.96, blue: 1.0)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image("AppLogo")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                        .shadow(radius: 10)
                    Text("Ai Nexus")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                .padding(.top, 20)

                VStack(spacing: 14) {
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        #endif

                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        Task {
                            await handlePrimaryAuthAction()
                        }
                    } label: {
                        Group {
                            if isLoading {
                                ProgressView()
                            } else {
                                Text(isSignUp ? "Sign Up" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                    }
                    .disabled(isLoading || isBusy || email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty)

                    Button {
                        isSignUp.toggle()
                        errorMessage = nil
                    } label: {
                        Text(isSignUp ? "Already have an account? Sign In" : "Create Account")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading || isBusy)

                    // Forgot password — only shown on sign-in screen
                    if !isSignUp {
                        Button("Forgot Password?") {
                            showForgotPassword = true
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 1)
                    Text("OR")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Rectangle()
                        .fill(Color.secondary.opacity(0.25))
                        .frame(height: 1)
                }

                SignInWithAppleButton(.signIn) { request in
                    authManager.prepareAppleSignInRequest(request)
                } onCompletion: { result in
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        await authManager.handleAppleSignIn(result: result)
                        errorMessage = authManager.authErrorMessage
                    }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .disabled(isLoading || isBusy)

                Button {
                    Task {
                        isLoading = true
                        defer { isLoading = false }
                        await signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("G")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color(red: 0.26, green: 0.52, blue: 0.96))
                        Text("Sign in with Google")
                            .foregroundStyle(.primary)
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        colorScheme == .dark ? Color.white.opacity(0.12) : Color.white,
                        in: RoundedRectangle(cornerRadius: 12)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading || isBusy)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: 420)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(24)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordView(authManager: authManager)
        }
    }

    // MARK: - Auth Actions (fixed: no duplicate isLoading)

    private func handlePrimaryAuthAction() async {
        isLoading = true
        isBusy = true
        defer {
            isLoading = false
            isBusy = false
        }

        do {
            if isSignUp {
                try await authManager.signUpWithEmail(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
            } else {
                try await authManager.signInWithEmail(
                    email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                    password: password
                )
            }
            errorMessage = nil
        } catch {
            errorMessage = authManager.userFacingMessage(for: error)
        }
    }

    private func signInWithGoogle() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await authManager.signInWithGoogle()
            errorMessage = nil
        } catch {
            errorMessage = authManager.userFacingMessage(for: error)
        }
    }
}

// MARK: - Forgot Password Flow ---------------------------------------------

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var authManager: AuthManager

    // Step: 0 = email entry, 1 = OTP entry, 2 = new password, 3 = success
    @State private var step: Int = 0
    @State private var email  = ""
    @State private var resetCode = ""
    @State private var newPassword  = ""
    @State private var confirmPassword = ""
    @State private var isBusy = false
    @State private var errorText: String?
    @FocusState private var codeFocus: Bool
    @FocusState private var newPwFocus: Bool

    private var passwordsMatch: Bool { newPassword == confirmPassword && !newPassword.isEmpty }
    private var passwordStrength: Int {          // 0-3
        var s = 0
        if newPassword.count >= 8 { s += 1 }
        if newPassword.range(of: "[A-Z]", options: .regularExpression) != nil { s += 1 }
        if newPassword.range(of: "[0-9!@#$%]", options: .regularExpression) != nil { s += 1 }
        return s
    }
    private var strengthColor: Color {
        [.red, .orange, .yellow, .green][passwordStrength]
    }
    private var strengthLabel: String {
        ["Weak", "Fair", "Good", "Strong"][passwordStrength]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(red:0.06,green:0.06,blue:0.12), Color.black]
                        : [Color(red:0.96,green:0.97,blue:1.0), Color.white],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Progress dots
                    HStack(spacing: 8) {
                        ForEach(0..<3) { i in
                            Capsule()
                                .fill(step > i ? Color.accentColor : Color.secondary.opacity(0.25))
                                .frame(width: step == i ? 24 : 8, height: 8)
                                .animation(.spring(response: 0.35), value: step)
                        }
                    }
                    .padding(.top, 20)

                    Spacer()

                    Group {
                        switch step {
                        case 0:  stepEmail
                        case 1:  stepOTP
                        case 2:  stepNewPassword
                        default: stepSuccess
                        }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal:   .move(edge: .leading).combined(with: .opacity)
                    ))

                    Spacer()
                }
                .padding(.horizontal, 28)
            }
            .navigationTitle("Reset Password")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // ── Step 0: Email ──────────────────────────────────────────────────────
    private var stepEmail: some View {
        VStack(spacing: 24) {
            stepIcon("envelope.circle.fill", color: .blue)
            VStack(spacing: 6) {
                Text("Forgot Password?")
                    .font(.title2).bold()
                Text("Enter the email linked to your account and we'll send a one-time reset code.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            TextField("Email address", text: $email)
                .textFieldStyle(.roundedBorder)
                #if !os(macOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
                #endif
                .autocorrectionDisabled()

            actionButton("Send OTP", icon: "paperplane.fill", busy: isBusy,
                         disabled: email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                await sendOTP()
            }

            if let e = errorText { errorLabel(e) }
        }
    }

    // ── Step 1: OTP ────────────────────────────────────────────────────────
    private var stepOTP: some View {
        VStack(spacing: 24) {
            stepIcon("lock.open.rotation", color: .orange)
            VStack(spacing: 6) {
                Text("Check Your Email")
                    .font(.title2).bold()
                Text("We sent a password reset link to\n\(email)")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("Copy the 'Code' from the reset link in your email and paste it below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                TextField("Enter Reset Code", text: $resetCode)
                    .textFieldStyle(.roundedBorder)
                    .focused($codeFocus)
                    .autocorrectionDisabled()
                    #if !os(macOS)
                    .textInputAutocapitalization(.never)
                    #endif
            }

            actionButton("Verify Code", icon: "checkmark.shield.fill", busy: isBusy,
                         disabled: resetCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
                await verifyOTP()
            }

            Button("Resend Email") {
                Task { await sendOTP(silently: true) }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)

            if let e = errorText { errorLabel(e) }
        }
    }


    // ── Step 2: New password ───────────────────────────────────────────────
    private var stepNewPassword: some View {
        VStack(spacing: 20) {
            stepIcon("key.fill", color: .green)
            VStack(spacing: 6) {
                Text("Set New Password")
                    .font(.title2).bold()
                Text("Choose a strong password for your account.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 6) {
                SecureField("New Password", text: $newPassword)
                    .textFieldStyle(.roundedBorder)
                    .focused($newPwFocus)

                // Strength bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.15))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(strengthColor)
                            .frame(width: geo.size.width * CGFloat(passwordStrength) / 3.0)
                            .animation(.easeInOut(duration: 0.3), value: passwordStrength)
                    }
                }
                .frame(height: 6)

                if !newPassword.isEmpty {
                    Text(strengthLabel)
                        .font(.caption)
                        .foregroundStyle(strengthColor)
                        .animation(.easeInOut, value: passwordStrength)
                }
            }

            SecureField("Confirm Password", text: $confirmPassword)
                .textFieldStyle(.roundedBorder)

            if !confirmPassword.isEmpty && !passwordsMatch {
                Text("Passwords do not match")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            actionButton("Reset Password", icon: "arrow.triangle.2.circlepath", busy: isBusy,
                         disabled: !passwordsMatch || passwordStrength == 0) {
                await resetPassword()
            }

            if let e = errorText { errorLabel(e) }
        }
    }

    // ── Step 3: Success ────────────────────────────────────────────────────
    private var stepSuccess: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.green, .teal],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 88, height: 88)
                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(.white)
            }
            Text("Password Reset!")
                .font(.title2).bold()
            Text("Your password has been updated.\nSign in with your new password.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Back to Sign In") { dismiss() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
    }

    // ── Helpers ────────────────────────────────────────────────────────────
    private func stepIcon(_ name: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.15))
                .frame(width: 80, height: 80)
            Image(systemName: name)
                .font(.system(size: 34))
                .foregroundStyle(color)
        }
    }

    private func errorLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private func actionButton(
        _ label: String, icon: String, busy: Bool, disabled: Bool,
        action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Group {
                if busy {
                    ProgressView().tint(.white)
                } else {
                    Label(label, systemImage: icon).fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(disabled || busy
                ? AnyShapeStyle(Color.secondary.opacity(0.3))
                : AnyShapeStyle(Color.accentColor),
                in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(disabled || busy)
    }

    // ── Actions ────────────────────────────────────────────────────────────
    private func sendOTP(silently: Bool = false) async {
        if !silently { isBusy = true }
        errorText = nil
        do {
            try await authManager.sendPasswordResetOTP(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
            withAnimation(.spring(response: 0.4)) { step = 1 }
            codeFocus = true
        } catch {
            errorText = authManager.userFacingMessage(for: error)
        }
        isBusy = false
    }

    private func verifyOTP() async {
        isBusy = true; defer { isBusy = false }
        errorText = nil
        do {
            try await authManager.verifyPasswordResetCode(resetCode.trimmingCharacters(in: .whitespacesAndNewlines))
            withAnimation(.spring(response: 0.4)) { step = 2 }
            newPwFocus = true
        } catch {
            errorText = "Invalid or expired code. Please copy it exactly from the link in your email."
        }
    }

    private func resetPassword() async {
        isBusy = true; defer { isBusy = false }
        errorText = nil
        do {
            try await authManager.confirmPasswordReset(code: resetCode.trimmingCharacters(in: .whitespacesAndNewlines), newPassword: newPassword)
            withAnimation(.spring(response: 0.4)) { step = 3 }
        } catch {
            errorText = authManager.userFacingMessage(for: error)
        }
    }
}
