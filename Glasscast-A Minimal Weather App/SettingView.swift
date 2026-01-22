//
//  SettingView.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import Foundation
import SwiftUI
import Combine
import Supabase
import Auth

struct SettingsView: View {
    // Keep a consistent background
    private let theme: WeatherTheme = .windy
    
    // Persist temperature unit preference
    @AppStorage("useCelsius") private var useCelsius: Bool = true
    
    // New persisted preferences
    @AppStorage("windUnitIsKmh") private var windUnitIsKmh: Bool = true // true: km/h, false: mph
    @AppStorage("pressureUnitIsHpa") private var pressureUnitIsHpa: Bool = true // true: hPa, false: inHg
    @AppStorage("notificationsSevereAlerts") private var severeAlerts: Bool = true
    @AppStorage("notificationsDailySummary") private var dailySummary: Bool = false
    
    // Local sign-out navigation
    @State private var isSigningOut = false
    @State private var navigateToLogin = false
    @State private var showConfirmSignOut = false
    
    // Observe Supabase auth
    @StateObject private var auth = SupabaseManager.shared
    
    // Cached profile values populated asynchronously
    @State private var profileDisplayName: String = "User"
    @State private var profileEmail: String = "(no email)"
    @State private var profileIsPremium: Bool = false
    
    var body: some View {
        ZStack {
            WeatherBackground(theme: theme).ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 18) {
                    // Invisible NavigationLink to LoginView, triggered by navigateToLogin
                    NavigationLink(isActive: $navigateToLogin) {
                        LoginView()
                            .navigationBarBackButtonHidden(true)
                    } label: {
                        EmptyView()
                    }
                    .hidden()
                    
                    header
                    
                    // Profile card
                    profileCard
                    
                    // Weather Units section
                    sectionHeader(title: "Weather Units")
                    VStack(spacing: 12) {
                        settingsRow(
                            icon: "thermometer.medium",
                            title: "Temperature",
                            subtitle: "Choose between Celsius and Fahrenheit",
                            trailing: AnyView(
                                unitToggle(
                                    isOn: $useCelsius,
                                    onLabel: "°C",
                                    offLabel: "°F"
                                )
                            )
                        )
                        
                        settingsRow(
                            icon: "wind",
                            title: "Wind Speed",
                            subtitle: "Display in km/h or mph",
                            trailing: AnyView(
                                unitToggle(
                                    isOn: $windUnitIsKmh,
                                    onLabel: "km/h",
                                    offLabel: "mph"
                                )
                            )
                        )
                        
                        settingsRow(
                            icon: "gauge.with.dots.needle.bottom.50percent",
                            title: "Pressure",
                            subtitle: "Display in hPa or inHg",
                            trailing: AnyView(
                                unitToggle(
                                    isOn: $pressureUnitIsHpa,
                                    onLabel: "hPa",
                                    offLabel: "inHg"
                                )
                            )
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    // Notifications section
                    sectionHeader(title: "Notifications")
                    VStack(spacing: 12) {
                        toggleRow(
                            icon: "exclamationmark.triangle.fill",
                            title: "Severe Alerts",
                            subtitle: "Get notified for severe weather",
                            isOn: $severeAlerts
                        )
                        
                        toggleRow(
                            icon: "sun.max.trianglebadge.exclamationmark",
                            title: "Daily Summary",
                            subtitle: "Receive a daily weather digest",
                            isOn: $dailySummary
                        )
                    }
                    .padding(.horizontal, 16)
                    
                    
                    // Sign out button with glassy gradient (kept from your current code)
                    VStack(spacing: 12) {
                        Button {
                            showConfirmSignOut = true
                        } label: {
                            HStack(spacing: 10) {
                                if isSigningOut {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "rectangle.portrait.and.arrow.right")
                                        .font(.headline)
                                }
                                Text(isSigningOut ? "Signing Out..." : "Sign Out")
                                    .font(.headline.bold())
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.red.opacity(0.95),
                                        Color.pink.opacity(0.85)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .shadow(color: .red.opacity(0.45), radius: 20, y: 8)
                        }
                        .disabled(isSigningOut)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    
                    // Footer
                    footer
                }
                .padding(.top, 24)
                .padding(.bottom, 24)
            }
            // Option A: Use an alert so it appears centered on all devices
            .alert("Are you sure you want to sign out?", isPresented: $showConfirmSignOut) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    performSignOut()
                }
            } message: {
                Text("You will need to sign in again to access your account.")
            }
        }
        .navigationBarBackButtonHidden(true)
        .task {
            await refreshProfileFromSession()
        }
        .onChange(of: auth.isAuthenticated) { _ in
            Task { await refreshProfileFromSession() }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Settings")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                Text("Basic preferences")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Profile Card
    
    private var profileCard: some View {
        HStack(alignment: .center, spacing: 16) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(LinearGradient(
                        colors: [.cyan, .blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .opacity(0.9)
                
                // Small verified badge
                if auth.isAuthenticated {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 18, height: 18)
                        .overlay {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: 22, y: 22)
                        .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(profileDisplayName)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                
                Text(profileEmail)
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.75))
                
                if profileIsPremium {
                    Text("PREMIUM GLASS ACCOUNT")
                        .font(.caption2.weight(.semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.35), Color.blue.opacity(0.25)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.white.opacity(0.25), lineWidth: 1)
                        )
                }
            }
            
            Spacer()
        }
        .padding(16)
        .liquidGlass(cornerRadius: 20, intensity: 0.40)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Section Header
    
    private func sectionHeader(title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.75))
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Reusable Rows
    
    private func settingsRow(icon: String, title: String, subtitle: String, trailing: AnyView) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.white)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            trailing
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .liquidGlass(cornerRadius: 16, intensity: 0.30)
    }
    
    private func unitToggle(isOn: Binding<Bool>, onLabel: String, offLabel: String) -> some View {
        VStack(spacing: 6) {
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.cyan)
            Text(isOn.wrappedValue ? onLabel : offLabel)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white.opacity(0.85))
                .frame(minWidth: 40)
        }
    }
    
    private func toggleRow(icon: String, title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.white)
                    .font(.subheadline.bold())
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(.cyan)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .liquidGlass(cornerRadius: 16, intensity: 0.30)
    }
    
    private func navigationRow(icon: String, title: String, subtitle: String, trailingBadge: AnyView, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundColor(.white)
                        .font(.subheadline.bold())
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))
                }
                
                Spacer()
                
                trailingBadge
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .liquidGlass(cornerRadius: 16, intensity: 0.30)
    }
    
    private func statusBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundColor(.white)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(color.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(.white.opacity(0.25), lineWidth: 1)
            )
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        VStack(spacing: 4) {
            Text("Demo by Sumit bhargav")
                .font(.caption2.weight(.semibold))
                .foregroundColor(.white.opacity(0.55))
            Text("sumitbhargav2994@gmail.com")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(.top, 8)
    }
    
    // MARK: - Sign Out
    
    private func performSignOut() {
        isSigningOut = true
        Task {
            do {
                try await SupabaseManager.shared.signOut()
            } catch {
                // If sign-out fails, we’ll still try to move on after brief delay
            }
            // Brief delay for visual feedback
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                isSigningOut = false
                navigateToLogin = true
            }
        }
    }
    
    // MARK: - Profile loading
    
    private func refreshProfileFromSession() async {
        // Try to read session; if unavailable, reset to defaults.
        guard let session = try? await auth.client.auth.session else {
            await MainActor.run {
                profileDisplayName = "User"
                profileEmail = "(no email)"
                profileIsPremium = false
            }
            return
        }
        
        let user = session.user
        let email = user.email ?? "(no email)"
        var display = "User"
        
        // Safely parse metadata using AnyJSON helpers
        var isPremium = false
        
        // user.userMetadata is [String: AnyJSON]
        let meta = user.userMetadata
        
        if let fullName = meta["full_name"]?.stringValue,
           !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            display = fullName
        } else if let name = meta["name"]?.stringValue,
                  !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            display = name
        }
        
        if let premiumBool = meta["premium"]?.boolValue {
            isPremium = premiumBool
        } else if let premiumInt = meta["premium"]?.intValue {
            isPremium = premiumInt != 0
        } else if let premiumDouble = meta["premium"]?.doubleValue {
            isPremium = premiumDouble != 0
        } else if let premiumString = meta["premium"]?.stringValue {
            isPremium = (premiumString as NSString).boolValue
        }
        
        if display == "User", let e = user.email {
            let local = e.split(separator: "@").first.map(String.init) ?? e
            if !local.isEmpty {
                display = local
            }
        }
        
        await MainActor.run {
            profileDisplayName = display
            profileEmail = email
            profileIsPremium = isPremium
        }
    }
}

#Preview {
    SettingsView()
}
