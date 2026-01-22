//
//  RadarView.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 22/01/26.
//

import Foundation
import MapKit
import CoreLocation
import SwiftUI

struct RadarView: View {
    // Default region centered on Cupertino; adjust as desired
    @State private var position = MapCameraPosition.region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.3349, longitude: -122.0090),
            span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
        )
    )
    
    private let theme: WeatherTheme = .foggy
    private let cardCornerRadius: CGFloat = 20
    private let innerInset: CGFloat = 5
    
    // Reusable location provider
    @StateObject private var locator = LocationProvider()
    
    // Favorites: use the shared store from the environment (same instance as SearchCityView)
    @EnvironmentObject private var favoritesStore: FavoritesStore
    @State private var favoriteCoords: [String: CLLocationCoordinate2D] = [:] // city -> coord
    @State private var favoriteGeocodingInFlight: Set<String> = []
    
    // User coordinate and popup
    @State private var userCoordinate: CLLocationCoordinate2D?
    @State private var showUserPopup: Bool = false
    
    // Weather for current location
    @State private var currentCity: String?
    @State private var currentWeather: CurrentWeather?
    @State private var isLoadingWeather: Bool = false
    @State private var weatherError: String?
    
    // Popup state for favorite markers
    @State private var selectedFavoriteCity: String?
    @State private var selectedFavoriteWeather: CurrentWeather?
    @State private var isLoadingFavoriteWeather: Bool = false
    @State private var favoriteWeatherError: String?
    
    // Service to fetch weather (reuse existing protocol with the mock)
    private let weatherService: WeatherService = MockWeatherService()
    private let geocoder = CLGeocoder()
    
    var body: some View {
        ZStack {
            WeatherBackground(theme: theme).ignoresSafeArea()
            
            VStack(spacing: 16) {
                header
                
                // Glass container with internal 5pt padding so Map sits inside
                ZStack {
                    Map(position: $position) {
                        // Current location marker
                        if let coord = userCoordinate {
                            Annotation("Me", coordinate: coord) {
                                // Marker + anchored popup
                                VStack(spacing: 8) {
                                    if showUserPopup {
                                        markerPopup
                                            .transition(.scale.combined(with: .opacity))
                                            .zIndex(1)
                                    }
                                    
                                    GlassMarker(icon: "location.fill")
                                        .onTapGesture {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                                showUserPopup.toggle()
                                            }
                                            Task {
                                                if let coord = userCoordinate {
                                                    await fetchWeatherForCurrentLocation(coord)
                                                }
                                            }
                                        }
                                }
                                .padding(.bottom, showUserPopup ? 10 : 0)
                                .accessibilityLabel("Current Location")
                            }
                        }
                        
                        // Favorite city markers
                        ForEach(favoritesStore.favorites, id: \.id) { fav in
                            let coord = coordinateForFavorite(fav)
                            if let coord {
                                Annotation(fav.city, coordinate: coord) {
                                    VStack(spacing: 8) {
                                        if selectedFavoriteCity == fav.city {
                                            favoritePopup(for: fav.city)
                                                .transition(.scale.combined(with: .opacity))
                                                .zIndex(1)
                                        }
                                        GlassMarker(icon: "star.fill")
                                            .onTapGesture {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                                    if selectedFavoriteCity == fav.city {
                                                        selectedFavoriteCity = nil
                                                    } else {
                                                        selectedFavoriteCity = fav.city
                                                    }
                                                }
                                                Task {
                                                    await fetchWeatherForFavorite(city: fav.city)
                                                }
                                            }
                                    }
                                    .padding(.bottom, selectedFavoriteCity == fav.city ? 10 : 0)
                                    .accessibilityLabel("\(fav.city)")
                                }
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    // Mask the map so its corners follow the outer radius minus the inset
                    .mask(
                        RoundedRectangle(cornerRadius: cardCornerRadius - innerInset, style: .continuous)
                    )
                    .padding(innerInset)
                    // React to coordinate updates from the provider
                    .task(id: locator.coordinate?.latitude) {
                        if let coord = locator.coordinate {
                            userCoordinate = coord
                            withAnimation(.easeInOut) {
                                position = .region(
                                    MKCoordinateRegion(
                                        center: coord,
                                        span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                                    )
                                )
                            }
                        }
                    }
                    // Load favorites and resolve their coordinates (prefer stored lat/lon; fallback to geocoding)
                    .task {
                        if favoritesStore.favorites.isEmpty {
                            await favoritesStore.load()
                        }
                        await resolveFavoriteCoordinates()
                    }
                    // Re-resolve when favorites change (e.g., user adds/removes)
                    .onChange(of: favoritesStore.favorites) { _ in
                        Task { await resolveFavoriteCoordinates() }
                    }
                    
                    // Floating current-location glass button
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                Task {
                                    // Ensure permission flow starts if needed
                                    locator.requestWhenInUse()
                                    if let coord = userCoordinate {
                                        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                            position = .region(
                                                MKCoordinateRegion(
                                                    center: coord,
                                                    span: MKCoordinateSpan(latitudeDelta: 0.15, longitudeDelta: 0.15)
                                                )
                                            )
                                            showUserPopup = true
                                        }
                                        await fetchWeatherForCurrentLocation(coord)
                                    }
                                }
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .frame(width: 48, height: 48)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                                .stroke(
                                                    LinearGradient(
                                                        colors: [.white.opacity(0.30), .white.opacity(0.12)],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    ),
                                                    lineWidth: 1
                                                )
                                        )
                                        .liquidGlass(cornerRadius: 22, intensity: 0.24)
                                        .shadow(color: .black.opacity(0.30), radius: 12, y: 6)
                                    
                                    Image(systemName: "location.circle.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(LinearGradient(
                                            colors: [.cyan, .blue],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ))
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                        }
                    }
                    .allowsHitTesting(true)
                }
                .liquidGlass(cornerRadius: cardCornerRadius, intensity: 0.25)
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                .frame(maxWidth: 800)
                .frame(minHeight: 220) // ensure non-zero size for Metal-backed layers
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .padding(.top, 16)
        }
        .onAppear {
            // Start location updates
            locator.requestWhenInUse()
        }
        .navigationBarBackButtonHidden(true)
    }
    
    // Resolve a coordinate for a given favorite city.
    // Prefers cached geocoded coords, falls back to the favorite’s stored lat/lon.
    private func coordinateForFavorite(_ fav: FavoriteCity) -> CLLocationCoordinate2D? {
        if let cached = favoriteCoords[fav.city] {
            return cached
        }
        if let lat = fav.lat, let lon = fav.lon {
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        return nil
    }
    
    // Custom glass marker styled for this app
    private struct GlassMarker: View {
        var icon: String
        
        var body: some View {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 30, height: 30)
                        .overlay(
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [.white.opacity(0.35), .white.opacity(0.12)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                        .overlay(
                            Image(systemName: icon)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(LinearGradient(
                                    colors: [.cyan, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                        )
                }
                // small pointer
                RoundedRectangle(cornerRadius: 1)
                    .fill(LinearGradient(colors: [.cyan.opacity(0.9), .blue.opacity(0.9)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(width: 2, height: 10)
                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
            }
        }
    }
    
    // Anchored popup content directly above marker (current location)
    private var markerPopup: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(currentCity ?? "Current Location")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showUserPopup = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            
            if isLoadingWeather {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("Loading…")
                        .foregroundColor(.white)
                        .font(.footnote)
                }
            } else if let error = weatherError {
                Text(error)
                    .foregroundColor(.white)
                    .font(.footnote)
            } else if let cw = currentWeather {
                HStack(spacing: 10) {
                    Image(systemName: cw.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cw.condition)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white)
                        HStack(spacing: 8) {
                            let (t, h, l) = TemperatureUnit.convert(temp: cw.temperature, high: cw.high, low: cw.low)
                            Text("\(t)°")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(TemperatureUnit.unitLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white.opacity(0.85))
                            Text("H \(h)°  L \(l)°")
                                .font(.caption)
                                .foregroundColor(.white)
                            
                        }
                    }
                }
            } else {
                Text("Tap marker to load weather.")
                    .foregroundColor(.white)
                    .font(.footnote)
            }
        }
        .padding(12)
        // Add a subtle tinted background behind the glass to reduce full transparency
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.35),
                            Color.orange.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .liquidGlass(cornerRadius: 14, intensity: 0.30)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
        .frame(maxWidth: 260)
    }
    
    // Favorite popup
    private func favoritePopup(for city: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(city)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        selectedFavoriteCity = nil
                        favoriteWeatherError = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
            
            if isLoadingFavoriteWeather {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text("Loading…")
                        .foregroundColor(.white)
                        .font(.footnote)
                }
            } else if let error = favoriteWeatherError {
                Text(error)
                    .foregroundColor(.white)
                    .font(.footnote)
            } else if let cw = selectedFavoriteWeather, cw.city.caseInsensitiveCompare(city) == .orderedSame {
                HStack(spacing: 10) {
                    Image(systemName: cw.symbolName)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cw.condition)
                            .font(.footnote.weight(.semibold))
                            .foregroundColor(.white)
                        HStack(spacing: 8) {
                            let (t, h, l) = TemperatureUnit.convert(temp: cw.temperature, high: cw.high, low: cw.low)
                            Text("\(t)°")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("H \(h)°  L \(l)°")
                                .font(.caption)
                                .foregroundColor(.white)
                            Text(TemperatureUnit.unitLabel)
                                .font(.caption2.weight(.semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }
                }
            } else {
                Text("Tap marker to load weather.")
                    .foregroundColor(.white)
                    .font(.footnote)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.35),
                            Color.blue.opacity(0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .liquidGlass(cornerRadius: 14, intensity: 0.30)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.25), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
        .frame(maxWidth: 260)
    }
    
    private func fetchWeatherForCurrentLocation(_ coord: CLLocationCoordinate2D) async {
        if isLoadingWeather { return }
        isLoadingWeather = true
        weatherError = nil
        defer { isLoadingWeather = false }
        
        do {
            // Reverse geocode to get a city name
            let placemarks = try await geocoder.reverseGeocodeLocation(
                CLLocation(latitude: coord.latitude, longitude: coord.longitude)
            )
            let city = placemarks.first?.locality ?? "Current Location"
            await MainActor.run { self.currentCity = city }
            
            // Fetch using existing WeatherService API (by city name)
            let weather = try await weatherService.fetchCurrentWeather(for: city)
            await MainActor.run {
                self.currentWeather = weather
            }
        } catch is CancellationError {
            // ignore
        } catch {
            await MainActor.run {
                self.weatherError = (error as NSError).localizedDescription
            }
        }
    }
    
    private func fetchWeatherForFavorite(city: String) async {
        if isLoadingFavoriteWeather { return }
        isLoadingFavoriteWeather = true
        favoriteWeatherError = nil
        defer { isLoadingFavoriteWeather = false }
        
        do {
            let weather = try await weatherService.fetchCurrentWeather(for: city)
            await MainActor.run {
                self.selectedFavoriteWeather = weather
            }
        } catch is CancellationError {
            // ignore
        } catch {
            await MainActor.run {
                self.favoriteWeatherError = (error as NSError).localizedDescription
            }
        }
    }
    
    private func resolveFavoriteCoordinates() async {
        // First fill from stored lat/lon
        for fav in favoritesStore.favorites {
            if let lat = fav.lat, let lon = fav.lon {
                favoriteCoords[fav.city] = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
        }
        // Geocode any that still lack coords
        await geocodeFavoritesIfNeeded()
        // Optionally center map to include all markers when we first have them
        await centerIfNeeded()
    }
    
    private func geocodeFavoritesIfNeeded() async {
        let cities = favoritesStore.favorites.map { $0.city }
        for city in cities {
            guard favoriteCoords[city] == nil, !favoriteGeocodingInFlight.contains(city) else { continue }
            favoriteGeocodingInFlight.insert(city)
            do {
                let placemarks = try await geocoder.geocodeAddressString(city)
                if let loc = placemarks.first?.location?.coordinate {
                    await MainActor.run {
                        favoriteCoords[city] = loc
                    }
                }
            } catch {
                // You could log or surface an error per-city if desired
            }
            favoriteGeocodingInFlight.remove(city)
        }
    }
    
    private func centerIfNeeded() async {
        // If we have no user coordinate, but we do have favorites, fit them
        guard userCoordinate == nil else { return }
        let coords = Array(favoriteCoords.values)
        guard !coords.isEmpty else { return }
        let region = regionToFit(coordinates: coords)
        await MainActor.run {
            withAnimation(.easeInOut) {
                position = .region(region)
            }
        }
    }
    
    private func regionToFit(coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        var minLat = 90.0, maxLat = -90.0, minLon = 180.0, maxLon = -180.0
        for c in coordinates {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.2, (maxLat - minLat) * 1.6),
            longitudeDelta: max(0.2, (maxLon - minLon) * 1.6)
        )
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
        return MKCoordinateRegion(center: center, span: span)
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "map")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Radar")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                Text("Explore the map")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    RadarView()
        .environmentObject(FavoritesStore()) // for preview only; real app should inject AppContainer's shared store
}
