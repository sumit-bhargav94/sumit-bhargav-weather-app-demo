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
    }
    
    private func attemptSignIn() {
        guard !isSigningIn, isFormValid else { return }
        isSigningIn = true
        Task {
            // Replace this delay with real auth logic
            try? await Task.sleep(nanoseconds: 400_000_000)
            isSigningIn = false
            navigateToHome = true
        }
    }
}

#Preview {
    NavigationStack {
        LoginView()
    }
}
