//
//  LoginView.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 20/01/26.
//

import SwiftUI
import Combine
 
struct LoginView: View {
    
    @State private var email = ""
    @State private var password = ""
    @State private var isSigningIn = false
    @State private var navigateToHome = false
    @FocusState private var focusedField: Field?
    @State private var showPassword: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    
    // Debug probe output
    @State private var probeOutput: String? = nil
    @State private var showProbeAlert: Bool = false
    
    // Pick the theme for this screen
    private let screenTheme: WeatherTheme = .coldSnowy
    
    private enum Field {
        case email
        case password
    }
    
    // Basic validation
    private var isEmailValid: Bool {
        email.contains("@") && email.contains(".")
    }
    private var isFormValid: Bool {
        isEmailValid && !password.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        ZStack {
            // Weather-aware background
            WeatherBackground(theme: screenTheme)
                .ignoresSafeArea()
                .onTapGesture {
                    focusedField = nil
                }
            
            GeometryReader { proxy in
                let safeTop = proxy.safeAreaInsets.top
                let safeBottom = proxy.safeAreaInsets.bottom
                let contentTopPadding = max(24, safeTop + 8)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // Invisible NavigationLink to HomeView, triggered by navigateToHome
                        NavigationLink(isActive: $navigateToHome) {
                            TabContainerView()
                                .navigationBarBackButtonHidden(true)
                        } label: {
                            EmptyView()
                        }
                        .hidden()
                        
                        // Logo / Title
                        VStack(spacing: 10) {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 64, height: 64)
                                .overlay {
                                    Image(systemName: "cloud.sun.rain.fill")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(LinearGradient(
                                            colors: [.cyan, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                }
                                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                            
                            Text("Glasscast")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.35), radius: 10)
                            
                            Text("SIGN IN TO YOUR WEATHER PORTAL")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.65))
                                .tracking(1.1)
                        }
                        
                        // Liquid Glass Card
                        VStack(alignment: .leading, spacing: 18) {
                            
                            Text("Welcome back")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            
                            Text("Securely sign in to continue")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.65))
                            
                            // Email
                            VStack(alignment: .leading, spacing: 6) {
                                Text("EMAIL ADDRESS")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                HStack(spacing: 10) {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    TextField("name@weather.com", text: $email)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.emailAddress)
                                        .disableAutocorrection(true)
                                        .foregroundColor(.white)
                                        .tint(.cyan)
                                        .focused($focusedField, equals: .email)
                                        .submitLabel(.next)
                                        .onSubmit {
                                            focusedField = .password
                                        }
                                }
                                .padding(12)
                                .liquidGlass(cornerRadius: 16, intensity: 0.25)
                            }
                            
                            // Password
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("PASSWORD")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Spacer()
                                    
                                    Button {
                                        // TODO: forgot password flow
                                    } label: {
                                        Text("FORGOT?")
                                            .font(.caption.bold())
                                            .foregroundColor(.cyan)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                HStack(spacing: 10) {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    if showPassword {
                                        TextField("Your password", text: $password)
                                            .foregroundColor(.white)
                                            .tint(.cyan)
                                            .focused($focusedField, equals: .password)
                                            .submitLabel(.go)
                                            .onSubmit {
                                                attemptSignIn()
                                            }
                                    } else {
                                        SecureField("Your password", text: $password)
                                            .foregroundColor(.white)
                                            .tint(.cyan)
                                            .focused($focusedField, equals: .password)
                                            .submitLabel(.go)
                                            .onSubmit {
                                                attemptSignIn()
                                            }
                                    }
                                    
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            showPassword.toggle()
                                        }
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                            .foregroundColor(.white.opacity(0.75))
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(12)
                                .liquidGlass(cornerRadius: 16, intensity: 0.25)
                            }
                            
                            // Sign In Button
                            Button {
                                attemptSignIn()
                            } label: {
                                HStack(spacing: 10) {
                                    if isSigningIn {
                                        ProgressView()
                                            .tint(.white)
                                    }
                                    Text(isSigningIn ? "Signing In..." : "Sign In").bold()
                                    if !isSigningIn {
                                        Image(systemName: "arrow.right")
                                    }
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color.cyan.opacity(0.95),
                                            Color.blue
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 20))
                                .shadow(color: .cyan.opacity(0.45), radius: 20, y: 8)
                            }
                            .disabled(isSigningIn || !isFormValid)
                            .opacity((isSigningIn || !isFormValid) ? 0.55 : 1.0)
                            
                            // Navigate to Signup
                            HStack(spacing: 6) {
                                Text("Don’t have an account?")
                                    .foregroundColor(.white.opacity(0.7))
                                NavigationLink {
                                    SignupView()
                                } label: {
                                    Text("Create Account")
                                        .foregroundColor(.cyan)
                                        .bold()
                                }
                            }
                            .font(.footnote)
                            .frame(maxWidth: .infinity)
                            
                            #if DEBUG
                            // Debug: Raw REST probe button
                            Button {
                                Task {
                                    await runProbe()
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "wrench.and.screwdriver.fill")
                                    Text("Debug Sign-In Probe")
                                }
                                .font(.footnote.bold())
                                .foregroundColor(.white)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.25))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.top, 4)
                            #endif
                        }
                        .padding(18)
                        .liquidGlass(cornerRadius: 28, intensity: 0.45)
                        .padding(.horizontal, 16)
                        .frame(maxWidth: 600) // keep it elegant on larger devices
                        
                        // Footer
                        HStack(spacing: 6) {
                            Image(systemName: "shield.fill")
                            Text("SECURE BY SUPABASE")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.white.opacity(0.55))
                        
                        Spacer(minLength: 16)
                    }
                    .padding(.top, contentTopPadding)
                    .padding(.bottom, max(24, safeBottom + 8))
                    .frame(minHeight: proxy.size.height) // centers content when plenty of space
                }
                .scrollDismissesKeyboard(.interactively)
            }
        }
        .navigationBarBackButtonHidden(true)
        .alert("Sign In Failed", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {
                showErrorAlert = false
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred. Please try again.")
        }
        #if DEBUG
        .alert("Probe Output", isPresented: $showProbeAlert) {
            Button("OK", role: .cancel) { showProbeAlert = false }
        } message: {
            Text(probeOutput ?? "No output")
        }
        #endif
    }
    
    private func attemptSignIn() {
        guard !isSigningIn else { return }
        // Trim inputs to avoid common mistakes
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        password = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isFormValid else {
            presentError("Please enter a valid email and password.")
            return
        }
        
        errorMessage = nil
        showErrorAlert = false
        isSigningIn = true
        focusedField = nil
        
        Task {
            do {
                try await SupabaseManager.shared.signIn(email: email, password: password)
                // On success, navigate to the main app
                await MainActor.run {
                    isSigningIn = false
                    navigateToHome = true
                }
            } catch {
                // Try fallback path
                do {
                    try await SupabaseManager.shared.signInFallback(email: email, password: password)
                    await MainActor.run {
                        isSigningIn = false
                        navigateToHome = true
                    }
                } catch {
                    let friendly = friendlyAuthError(from: error)
                    await MainActor.run {
                        isSigningIn = false
                        presentError(friendly)
                    }
                }
            }
        }
    }
    
    #if DEBUG
    private func runProbe() async {
        let e = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let p = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !e.isEmpty, !p.isEmpty else {
            probeOutput = "Enter email and password first."
            showProbeAlert = true
            return
        }
        do {
            let output = try await SupabaseManager.shared.rawSignInProbe(email: e, password: p)
            probeOutput = output
        } catch {
            let ns = error as NSError
            probeOutput = "Probe failed: \(ns.localizedDescription)\n(domain=\(ns.domain) code=\(ns.code))"
        }
        showProbeAlert = true
    }
    #endif
    
    // MARK: - Error presentation helpers
    
    private func presentError(_ message: String) {
        errorMessage = message
        showErrorAlert = true
    }
    
    // Map opaque/technical errors to friendly messages for users.
    private func friendlyAuthError(from error: Error) -> String {
        let ns = error as NSError
        let raw = ns.localizedDescription
        
        // Common opaque decoding error from SDK when response is unexpected
        if raw == "The data couldn’t be read because it is missing." ||
            raw == "The data couldn’t be read because it isn’t in the correct format." {
            return "Sign in didn’t complete. Please check your email and password, then try again. If the issue persists, try again later."
        }
        
        // Network offline / connectivity
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet:
                return "You appear to be offline. Please check your internet connection."
            case NSURLErrorTimedOut:
                return "The request timed out. Please try again."
            default:
                break
            }
        }
        
        // Supabase / auth typical messages we can clarify a bit
        let lowered = raw.lowercased()
        if lowered.contains("invalid login") || lowered.contains("invalid email or password") {
            return "Invalid email or password. Please try again."
        }
        if lowered.contains("email not confirmed") || lowered.contains("confirm") {
            return "Please confirm your email before signing in. Check your inbox for the verification link."
        }
        
        // Fallback to the original message
        return raw
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
