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
    @State private var results: [CitySearchResult] = []
    // Per-result weather cache by result id
    @State private var weatherCache: [Int: CurrentWeather] = [:]
    @State private var loadingSet: Set<Int> = []
    
    // Favorites per-row weather cache by favorite UUID
    @State private var favoritesWeather: [UUID: CurrentWeather] = [:]
    @State private var favoritesLoading: Set<UUID> = []
    
    // Use the shared FavoritesStore provided by the app
    @EnvironmentObject private var favorites: FavoritesStore
    @Environment(\.container) private var container
    
    // Keep a consistent background with app
    private let theme: WeatherTheme = .foggy
    
    // Debounce task
    @State private var searchTask: Task<Void, Never>?
    // Clear all confirmation
    @State private var showClearAllConfirm = false
    
    // Track focus for the search field
    @FocusState private var isSearchFocused: Bool
    
    // MARK: - WeatherAPI search endpoint model
    struct CitySearchResult: Identifiable, Equatable {
        let id: Int
        let name: String
        let region: String
        let country: String
        let lat: Double
        let lon: Double
        let url: String
    }
    
    private struct CitySearchDTO: Decodable {
        let id: Int
        let name: String
        let region: String
        let country: String
        let lat: Double
        let lon: Double
        let url: String
    }
    
    private enum SearchError: LocalizedError {
        case badURL
        case http(Int, String)
        var errorDescription: String? {
            switch self {
            case .badURL: return "Invalid search URL."
            case .http(let code, let body): return "HTTP \(code): \(body)"
            }
        }
    }
    
    // WeatherAPI key (align with your service default)
    private let apiKey: String = WeatherAPIService.defaultAPIKey
    
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
            // Load favorites from the active backend (Supabase when mockMode is false)
            await favorites.load()
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
                .focused($isSearchFocused)
                .onSubmit {
                    Task { await performSearch(query: query) }
                }
            
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                    weatherCache.removeAll()
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
        // Neutral glass style
        .glassSearchFieldStyle(cornerRadius: 22)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Favorites Section with CLEAR ALL + SYNC
    private var favoritesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("FAVORITES")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.75))
                
                Spacer()
                
                if favorites.isLoading {
                    ProgressView().tint(.cyan)
                } else {
                    Button {
                        Task { await favorites.load() }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                            Text("SYNC")
                        }
                        .font(.caption.weight(.bold))
                        .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)
                }
                
                if !favorites.favorites.isEmpty && !favorites.isLoading {
                    Divider()
                        .frame(height: 12)
                        .overlay(Color.white.opacity(0.25))
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
                        favoriteRow(city: fav.city, id: fav.id, country: fav.country)
                            .task(id: fav.id) {
                                await fetchFavoriteWeatherIfNeeded(fav)
                            }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
    
    private func favoriteRow(city: String, id: UUID, country: String) -> some View {
        let mood = moodForCity(city).title
        let icon = moodForCity(city).icon
        let cw = favoritesWeather[id]
        
        let tempText: String = {
            if let cw {
                let t = TemperatureUnit.convert(cw.temperature)
                return "\(t)°"
            } else if favoritesLoading.contains(id) {
                return "…"
            } else {
                return "—°"
            }
        }()
        
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
                Text(tempText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(TemperatureUnit.unitLabel)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Button {
                Task { await favorites.toggle(city: city, country: country) }
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
    }
    
    // MARK: - Results Section (real API search)
    private var resultsSection: some View {
        // Only show the Results section while user is actively searching:
        // - search field focused
        // - query non-empty
        Group {
            if isSearchFocused && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("SEARCH RESULTS")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.white.opacity(0.75))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    
                    VStack(spacing: 16) {
                        if !results.isEmpty {
                            ForEach(results) { city in
                                resultRow(city: city)
                                    .padding(.horizontal, 16)
                                    .task(id: city.id) {
                                        await fetchWeatherForResultIfNeeded(city)
                                    }
                            }
                        } else {
                            // While typing with focus but no results yet, we can either show nothing
                            // or a subtle hint. Requirement says to hide the previous prompt, so show nothing.
                            EmptyView()
                        }
                    }
                }
            } else {
                // When not focused or query empty, hide the whole section (including header and hint).
                EmptyView()
            }
        }
    }
    
    private func resultRow(city: CitySearchResult) -> some View {
        let mood = moodForCity(city.name).title
        let icon = moodForCity(city.name).icon
        let isFav = favorites.isFavorite(city.name) != nil
        let cw = weatherCache[city.id]
        
        let tempText: String = {
            if let cw {
                let t = TemperatureUnit.convert(cw.temperature)
                return "\(t)°"
            } else if loadingSet.contains(city.id) {
                return "…"
            } else {
                return "—°"
            }
        }()
        
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
                Text(city.name)
                    .foregroundColor(.white)
                    .font(.system(.headline, design: .rounded).weight(.bold))
                Text("\(city.region.isEmpty ? city.country : "\(city.region), \(city.country)")")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.white.opacity(0.75))
            }
            
            Spacer(minLength: 12)
            
            VStack(alignment: .trailing, spacing: 2) {
                Text(tempText)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(TemperatureUnit.unitLabel)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Button {
                Task {
                    await favorites.toggle(city: city.name, country: city.country, lat: city.lat, lon: city.lon)
                }
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
        .glassCardTinted(cornerRadius: 26, city: city.name)
    }
    
    // MARK: - Debounced search using WeatherAPI
    private func debounceSearch(for text: String) {
        searchTask?.cancel()
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            results = []
            weatherCache.removeAll()
            loadingSet.removeAll()
            return
        }
        searchTask = Task { [text] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(query: text)
        }
    }
    
    @MainActor
    private func performSearch(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            weatherCache.removeAll()
            loadingSet.removeAll()
            return
        }
        do {
            let found = try await searchCities(query: trimmed)
            results = found
            // Optionally prefetch first few results’ weather
            let prefetch = Array(found.prefix(6))
            for city in prefetch {
                Task { await fetchWeatherForResultIfNeeded(city) }
            }
        } catch {
#if DEBUG
            print("[SearchCity] search failed: \(error.localizedDescription)")
#endif
            results = []
            weatherCache.removeAll()
            loadingSet.removeAll()
        }
    }
    
    private func searchCities(query: String) async throws -> [CitySearchResult] {
        var comps = URLComponents(string: "https://api.weatherapi.com/v1/search.json")!
        comps.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = comps.url else { throw SearchError.badURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            throw SearchError.http(http.statusCode, body)
        }
        
        let decoded = try JSONDecoder().decode([CitySearchDTO].self, from: data)
        return decoded.map {
            CitySearchResult(id: $0.id, name: $0.name, region: $0.region, country: $0.country, lat: $0.lat, lon: $0.lon, url: $0.url)
        }
    }
    
    // MARK: - Weather fetch per search result
    
    private func fetchWeatherForResultIfNeeded(_ city: CitySearchResult) async {
        guard weatherCache[city.id] == nil, !loadingSet.contains(city.id) else { return }
        loadingSet.insert(city.id)
        defer { loadingSet.remove(city.id) }
        do {
            // Use shared WeatherService from container; query via "lat,lon" to be precise.
            let svc = container.weatherService
            let query = "\(city.lat),\(city.lon)"
            let current = try await svc.fetchCurrentWeather(for: query)
            await MainActor.run {
                weatherCache[city.id] = current
            }
        } catch {
            // Swallow per-row errors; row will keep placeholder
#if DEBUG
            print("[SearchCity] weather fetch failed for \(city.name): \(error.localizedDescription)")
#endif
        }
    }
    
    // MARK: - Weather fetch per favorite
    
    private func fetchFavoriteWeatherIfNeeded(_ fav: FavoriteCity) async {
        guard favoritesWeather[fav.id] == nil, !favoritesLoading.contains(fav.id) else { return }
        favoritesLoading.insert(fav.id)
        defer { favoritesLoading.remove(fav.id) }
        do {
            let svc = container.weatherService
            let query: String
            if let lat = fav.lat, let lon = fav.lon {
                query = "\(lat),\(lon)"
            } else {
                // Fallback to city string if no coordinates stored
                query = fav.city
            }
            let current = try await svc.fetchCurrentWeather(for: query)
            await MainActor.run {
                favoritesWeather[fav.id] = current
            }
        } catch {
#if DEBUG
            print("[SearchCity] favorite weather fetch failed for \(fav.city): \(error.localizedDescription)")
#endif
        }
    }
    
    // MARK: - Mood/Icon mapping (placeholder for row visuals)
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
}

#Preview {
    NavigationStack {
        SearchCityView()
            .environmentObject(FavoritesStore())
            .environment(\.container, AppContainer())
    }
}
