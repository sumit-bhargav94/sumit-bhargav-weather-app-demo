//
//  SignupView.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import SwiftUI
import Combine

struct SignupView: View {
    
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var agreeToTerms = false
    
    // Pick the theme for this screen
    private let screenTheme: WeatherTheme = .sunny
    
    // Simple validation helpers
    private var isEmailValid: Bool {
        // Basic check; you can replace with a more robust validator
        email.contains("@") && email.contains(".")
    }
    
    private var isPasswordMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }
    
    private var isFormValid: Bool {
        !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isEmailValid &&
        isPasswordMatch &&
        agreeToTerms
    }
    
    var body: some View {
        ZStack {
            // Weather-aware background
            WeatherBackground(theme: screenTheme)
                .ignoresSafeArea()
            
            GeometryReader { proxy in
                let safeTop = proxy.safeAreaInsets.top
                let safeBottom = proxy.safeAreaInsets.bottom
                let minVPadding: CGFloat = 16
                let contentTopPadding = max(24, safeTop + 8)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 22) {
                        // Logo / Title
                        VStack(spacing: 10) {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 64, height: 64)
                                .overlay {
                                    Image(systemName: "cloud.sun.fill")
                                        .font(.system(size: 26, weight: .semibold))
                                        .foregroundStyle(LinearGradient(
                                            colors: [.yellow, .orange],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                }
                                .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
                            
                            Text("Glasscast")
                                .font(.system(.title, design: .rounded).weight(.bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.35), radius: 10)
                            
                            Text("CREATE YOUR ACCOUNT")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.65))
                                .tracking(1.1)
                        }
                        
                        // Liquid Glass Card
                        VStack(alignment: .leading, spacing: 18) {
                            
                            Text("Join the portal")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                            
                            Text("Set up your account to start exploring the weather")
                                .font(.footnote)
                                .foregroundColor(.white.opacity(0.65))
                            
                            // Full Name
                            VStack(alignment: .leading, spacing: 6) {
                                Text("FULL NAME")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                HStack {
                                    Image(systemName: "person.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    TextField("Jane Doe", text: $fullName)
                                        .textInputAutocapitalization(.words)
                                        .disableAutocorrection(true)
                                        .foregroundColor(.white)
                                        .tint(.cyan)
                                }
                                .padding(12)
                                .liquidGlass(cornerRadius: 16, intensity: 0.25)
                            }
                            
                            // Email
                            VStack(alignment: .leading, spacing: 6) {
                                Text("EMAIL ADDRESS")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                HStack {
                                    Image(systemName: "envelope.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    TextField("name@weather.com", text: $email)
                                        .textInputAutocapitalization(.never)
                                        .keyboardType(.emailAddress)
                                        .foregroundColor(.white)
                                        .tint(.cyan)
                                }
                                .padding(12)
                                .liquidGlass(cornerRadius: 16, intensity: 0.25)
                            }
                            
                            // Password
                            VStack(alignment: .leading, spacing: 6) {
                                Text("PASSWORD")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    SecureField("Create a password", text: $password)
                                        .foregroundColor(.white)
                                        .tint(.cyan)
                                }
                                .padding(12)
                                .liquidGlass(cornerRadius: 16, intensity: 0.25)
                            }
                            
                            // Confirm Password
                            VStack(alignment: .leading, spacing: 6) {
                                Text("CONFIRM PASSWORD")
                                    .font(.caption.weight(.semibold))
                                    .foregroundColor(.white.opacity(0.7))
                                
                                HStack {
                                    Image(systemName: "lock.circle.fill")
                                        .foregroundColor(.white.opacity(0.6))
                                    
                                    SecureField("Re-enter your password", text: $confirmPassword)
                                        .foregroundColor(.white)
                                        .tint(.cyan)
                                }
                                .padding(12)
                                .liquidGlass(cornerRadius: 16, intensity: 0.25)
                            }
                            
                            // Terms and Conditions
                            Toggle(isOn: $agreeToTerms) {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("I agree to the")
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("Terms")
                                        .foregroundColor(.cyan)
                                        .bold()
                                    Text("and")
                                        .foregroundColor(.white.opacity(0.8))
                                    Text("Privacy Policy")
                                        .foregroundColor(.cyan)
                                        .bold()
                                }
                                .font(.footnote)
                            }
                            .toggleStyle(.switch)
                            .tint(.cyan)
                            .padding(.top, 2)
                            
                            // Create Account Button
                            Button {
                                // Handle sign up action
                            } label: {
                                HStack {
                                    Text("Create Account").bold()
                                    Image(systemName: "person.badge.plus")
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
                            .disabled(!isFormValid)
                            .opacity(isFormValid ? 1.0 : 0.5)
                            
                            // Link back to Sign In
                            HStack(spacing: 6) {
                                Text("Already have an account?")
                                    .foregroundColor(.white.opacity(0.7))
                                NavigationLink {
                                    LoginView()
                                        .navigationBarBackButtonHidden(true)
                                } label: {
                                    Text("Sign In")
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
                        .frame(maxWidth: 600) // keep it nice on larger devices
                        
                        // Footer
                        HStack(spacing: 6) {
                            Image(systemName: "shield.fill")
                            Text("SECURE BY SUPABASE")
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundColor(.white.opacity(0.55))
                        
                        Spacer(minLength: minVPadding)
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
}

#Preview {
    NavigationStack {
        SignupView()
    }
}
