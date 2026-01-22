//
//  AppContainer.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import Foundation
import SwiftUI
import Combine

// Simple DI container to hold shared services, session, and factories.
@MainActor
final class AppContainer: ObservableObject {
    let session: AppSession
    let favoritesStore: FavoritesStore

    // Services
    let weatherService: WeatherService
    let favoritingService: SupabaseFavoriting

    private var authObserverTask: Task<Void, Never>?

    init(
        session: AppSession? = nil,
        favoritesStore: FavoritesStore? = nil,
        weatherService: WeatherService? = nil,
        favoritingService: SupabaseFavoriting? = nil
    ) {
        let resolvedSession = session ?? AppSession()
        let resolvedFavoritingService = favoritingService ?? SupabaseService()
        // Inject real WeatherAPI service by default. Replace key with your real key or load from config.
        let defaultWeather = WeatherAPIService(apiKey: WeatherAPIService.defaultAPIKey)
        
        let resolvedWeatherService = weatherService ?? defaultWeather
        let resolvedFavoritesStore = favoritesStore ?? FavoritesStore(service: resolvedFavoritingService, session: resolvedSession)

        self.session = resolvedSession
        self.favoritesStore = resolvedFavoritesStore
        self.weatherService = resolvedWeatherService
        self.favoritingService = resolvedFavoritingService

        // Start in mock until we know auth state
        self.favoritesStore.mockMode = true

        // Observe Supabase auth changes and reflect into AppSession + FavoritesStore
        authObserverTask = Task { [weak self] in
            guard let self else { return }
            let mgr = SupabaseManager.shared
            for await _ in mgr.$isAuthenticated.values {
                let authed = mgr.isAuthenticated
                let userID = mgr.currentUserID
                // Update AppSession user id if available
                if let uid = userID {
                    self.session.currentUserID = uid
                }
                // Toggle mock mode
                self.favoritesStore.mockMode = !authed
                // Reload favorites when we become authenticated
                if authed {
                    await self.favoritesStore.load()
                } else {
                    // Clear favorites on sign-out via store API
                    await self.favoritesStore.clearAll()
                }
            }
        }
    }

    deinit {
        authObserverTask?.cancel()
    }

    // ViewModel factories
    func makeHomeViewModel() -> HomeViewModel {
        HomeViewModel(service: weatherService)
    }
}

// EnvironmentKey to access the container in SwiftUI views.
private struct AppContainerKey: EnvironmentKey {
    static let defaultValue: AppContainer = AppContainer()
}

extension EnvironmentValues {
    var container: AppContainer {
        get { self[AppContainerKey.self] }
        set { self[AppContainerKey.self] = newValue }
    }
}

