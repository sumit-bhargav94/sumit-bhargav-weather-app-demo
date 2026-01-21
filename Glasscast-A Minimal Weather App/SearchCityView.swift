//
//  SearchCityView.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import Foundation
import SwiftUI

struct SearchCityView: View {
    @State private var query: String = ""
    @State private var results: [String] = []
    
    // Use the shared FavoritesStore provided by the app
    @EnvironmentObject private var favorites: FavoritesStore
    
    // Keep a consistent background with app
    private let theme: WeatherTheme = .foggy
    
    // Mock data source for search
    private let allCities = [
        "Cupertino", "San Francisco", "New York", "London", "Tokyo",
        "Paris", "Sydney", "Berlin", "Toronto", "Singapore",
        "Seoul", "Mumbai", "Cape Town", "São Paulo", "Mexico City"
    ]
    
    // Debounce task
    @State private var searchTask: Task<Void, Never>?
    // Clear all confirmation
    @State private var showClearAllConfirm = false
    // Demo seeding control
    @State private var seededDemo = false
    
    var body: some View {
        ZStack {
            WeatherBackground(theme: theme).ignoresSafeArea()
            
            GeometryReader { proxy in
                let safeTop = proxy.safeAreaInsets.top
                let safeBottom = proxy.safeAreaInsets.bottom
                let contentTopPadding = max(24, safeTop + 8)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 22) {
                        topBar
                        searchField
                        favoritesSection
                        resultsSection
                        
                        if let error = favorites.errorMessage {
                            Text(error)
                                .font(.footnote)
                                .foregroundColor(.red.opacity(0.9))
                                .padding(.top, 8)
                        }
                        
                        Spacer(minLength: 16)
                    }
                    .padding(.top, contentTopPadding)
                    .padding(.bottom, max(24, safeBottom + 8))
                    .frame(maxWidth: 700)
                }
            }
        }
        .task {
            // Enable mock mode so no backend calls are attempted for now
            favorites.mockMode = true
            await favorites.load()
        }
        .task {
            // Seed some demo results so you can see full design immediately
            if !seededDemo && results.isEmpty && query.isEmpty {
                seededDemo = true
                results = Array(allCities.prefix(6))
            }
        }
        .onChange(of: query) { _, newValue in
            debounceSearch(for: newValue)
        }
        .navigationBarBackButtonHidden(true)
        .alert("Clear all favorites?", isPresented: $showClearAllConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                Task { await favorites.clearAll() }
            }
        } message: {
            Text("This will remove all your saved cities.")
        }
    }
    
    // MARK: - Header Top Bar (Chevron + Title)
    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                // Parent navigation can handle dismiss if needed
            } label: {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .shadow(color: .black.opacity(0.3), radius: 12, y: 6)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Search for a City")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                Text("Find and save locations")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Search Field
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.8))
                .font(.system(size: 18, weight: .semibold))
            
            TextField("Find a city…", text: $query)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundColor(.white)
                .tint(.cyan)
                .font(.system(.body, design: .rounded))
            
            if !query.isEmpty {
                Button {
                    query = ""
                    results = Array(allCities.prefix(6))
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.75))
                        .font(.system(size: 18, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        // Use a dedicated, neutral glass style so this matches the original design
        .glassSearchFieldStyle(cornerRadius: 22)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Favorites Section with CLEAR ALL
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("FAVORITES")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.75))
                
                Spacer()
                
                if favorites.isLoading {
                    ProgressView().tint(.cyan)
                } else if !favorites.favorites.isEmpty {
                    Button {
                        showClearAllConfirm = true
                    } label: {
                        Text("CLEAR ALL")
                            .font(.caption.weight(.bold))
                            .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            
            if favorites.favorites.isEmpty {
                Text("No favorites yet. Search and add cities you care about.")
                    .font(.footnote)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 16) {
                    ForEach(favorites.favorites) { fav in
                        favoriteRow(city: fav.city, id: fav.id)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func favoriteRow(city: String, id: UUID) -> some View {
        let mood = moodForCity(city).title
        let icon = moodForCity(city).icon
        
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(width: 46, height: 46)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(city)
                    .foregroundColor(.white)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundColor(.white.opacity(0.9))
                        .font(.system(size: 14, weight: .semibold))
                    Text(mood)
                        .font(.system(.caption, design: .rounded))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            
            Spacer(minLength: 12)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("—°")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Celsius")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Button {
                Task { await favorites.toggle(city: city) }
            } label: {
                Image(systemName: "trash.fill")
                    .foregroundColor(.red.opacity(0.9))
                    .font(.system(size: 16, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 64)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .glassCardTinted(cornerRadius: 24, city: city)
        // No onTapGesture here; only the button should toggle
    }
    
    // MARK: - Results Section (My Location removed)
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("RECENT EXPLORATIONS")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
            }
            .padding(.horizontal, 16)
            
            VStack(spacing: 16) {
                if query.isEmpty && results.isEmpty {
                    Text("Start typing to search cities or add from your favorites above.")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.65))
                        .padding(.horizontal, 16)
                } else if !results.isEmpty {
                    ForEach(results, id: \.self) { city in
                        resultRow(city: city)
                            .padding(.horizontal, 16)
                    }
                } else if !query.isEmpty && results.isEmpty {
                    Text("No results for “\(query)”")
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 16)
                }
            }
        }
    }
    
    private func resultRow(city: String) -> some View {
        let mood = moodForCity(city).title
        let icon = moodForCity(city).icon
        let isFav = favorites.isFavorite(city) != nil
        
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.95))
                    .font(.system(size: 20, weight: .semibold))
            }
            .frame(width: 46, height: 46)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(city)
                    .foregroundColor(.white)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Text(mood)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }
            
            Spacer(minLength: 12)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("—°")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Celsius")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Button {
                Task { await favorites.toggle(city: city) }
            } label: {
                Image(systemName: isFav ? "star.fill" : "star")
                    .foregroundColor(.yellow)
                    .font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 68)
        .padding(.vertical, 12)
        .padding(.horizontal, 20)
        .glassCardTinted(cornerRadius: 26, city: city)
        // No onTapGesture here; only the star button should toggle
    }
    
    // MARK: - Debounced search using Swift Concurrency
    private func debounceSearch(for text: String) {
        searchTask?.cancel()
        searchTask = Task { [allCities] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if text.isEmpty {
                    self.results = Array(allCities.prefix(6))
                } else {
                    self.results = allCities.filter { $0.localizedCaseInsensitiveContains(text) }
                }
            }
        }
    }
    
    // MARK: - Mood/Icon mapping (placeholder)
    private func moodForCity(_ city: String) -> (title: String, icon: String) {
        let moods: [(String, String)] = [
            ("Sunny Skies", "sun.max.fill"),
            ("Partly Cloudy", "cloud.sun.fill"),
            ("Light Showers", "cloud.drizzle.fill"),
            ("Rain", "cloud.rain.fill"),
            ("Stormy", "cloud.bolt.rain.fill"),
            ("Fog", "cloud.fog.fill"),
            ("Windy", "wind"),
            ("Snow", "snow")
        ]
        let idx = abs(city.hashValue) % moods.count
        return moods[idx]
    }
    
    // MARK: - Day/Night demo logic
    private func isDaytime(for city: String) -> Bool {
        // Demo-only: stable pseudo-random day/night by hash
        // Replace with real sunrise/sunset checks for the city’s coordinates.
        (abs(city.hashValue) % 2) == 0
    }
    
    private func isSunny(for city: String) -> Bool {
        let mood = moodForCity(city).title
        return mood.contains("Sunny")
    }
}

// MARK: - Blur + Stroke + Liquid + Day/Night tint helper
private extension View {
    func glassCardTinted(cornerRadius: CGFloat, city: String) -> some View {
        modifier(GlassCardTinted(cornerRadius: cornerRadius, city: city))
    }
    
    // Neutral glass style specifically for the search field, matching the earlier look
    func glassSearchFieldStyle(cornerRadius: CGFloat) -> some View {
        modifier(GlassSearchFieldStyle(cornerRadius: cornerRadius))
    }
}

private struct GlassCardTinted: ViewModifier {
    var cornerRadius: CGFloat
    var city: String
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(weatherGradient(for: city))
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(0.35))
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(specularHighlight(for: city))
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.28),
                                .white.opacity(0.12)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            // Move shadow to a separate, non-interactive overlay to avoid hit-test work
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
                    .allowsHitTesting(false)
            )
            .liquidGlass(cornerRadius: cornerRadius, intensity: 0.22)
    }
    
    private func weatherGradient(for city: String) -> LinearGradient {
        let day = isDaytime(city)
        let sunny = isSunny(city)
        
        let colors: [Color]
        if day && sunny {
            colors = [
                Color(red: 0.35, green: 0.72, blue: 1.00),
                Color(red: 0.14, green: 0.52, blue: 0.96)
            ]
        } else if day {
            colors = [
                Color(red: 0.44, green: 0.60, blue: 0.82),
                Color(red: 0.26, green: 0.39, blue: 0.60)
            ]
        } else if sunny {
            colors = [
                Color(red: 0.20, green: 0.26, blue: 0.42),
                Color(red: 0.09, green: 0.12, blue: 0.24)
            ]
        } else {
            colors = [
                Color(red: 0.10, green: 0.12, blue: 0.20),
                Color(red: 0.04, green: 0.05, blue: 0.12)
            ]
        }
        
        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func specularHighlight(for city: String) -> LinearGradient {
        let day = isDaytime(city)
        let topOpacity = day ? 0.28 : 0.20
        
        return LinearGradient(
            colors: [
                Color.white.opacity(topOpacity),
                Color.white.opacity(0.06),
                .clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func isDaytime(_ city: String) -> Bool {
        (abs(city.hashValue) % 2) == 0
    }
    private func isSunny(_ city: String) -> Bool {
        let moods: [(String, String)] = [
            ("Sunny Skies", "sun.max.fill"),
            ("Partly Cloudy", "cloud.sun.fill"),
            ("Light Showers", "cloud.drizzle.fill"),
            ("Rain", "cloud.rain.fill"),
            ("Stormy", "cloud.bolt.rain.fill"),
            ("Fog", "cloud.fog.fill"),
            ("Windy", "wind"),
            ("Snow", "snow")
        ]
        let idx = abs(city.hashValue) % moods.count
        return moods[idx].0.contains("Sunny")
    }
}

// MARK: - Original-style neutral glass for the search field
private struct GlassSearchFieldStyle: ViewModifier {
    var cornerRadius: CGFloat
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .allowsHitTesting(false)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.30),
                                .white.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .allowsHitTesting(false)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color.clear)
                    .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
                    .allowsHitTesting(false)
            )
            .liquidGlass(cornerRadius: cornerRadius, intensity: 0.20)
    }
}

#Preview {
    NavigationStack {
        SearchCityView()
            .environmentObject(FavoritesStore())
    }
}
