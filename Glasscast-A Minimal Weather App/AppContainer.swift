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

    init(
        session: AppSession? = nil,
        favoritesStore: FavoritesStore? = nil,
        weatherService: WeatherService? = nil,
        favoritingService: SupabaseFavoriting? = nil
    ) {
        // Construct defaults inside the @MainActor initializer body
        let resolvedSession = session ?? AppSession()
        let resolvedFavoritingService = favoritingService ?? SupabaseService()
        let resolvedWeatherService = weatherService ?? MockWeatherService()
        let resolvedFavoritesStore = favoritesStore ?? FavoritesStore(service: resolvedFavoritingService, session: resolvedSession)

        self.session = resolvedSession
        self.favoritesStore = resolvedFavoritesStore
        self.weatherService = resolvedWeatherService
        self.favoritingService = resolvedFavoritingService

        // Wire the favorites store to use the same session and service if needed
        self.favoritesStore.mockMode = true // keep mock by default
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
