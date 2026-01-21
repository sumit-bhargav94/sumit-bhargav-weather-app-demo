//
//  Glasscast_A_Minimal_Weather_AppApp.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 20/01/26.
//

import SwiftUI

@main
struct Glasscast_A_Minimal_Weather_AppApp: App {
    // Create one shared container and store for the whole app
    @StateObject private var container = AppContainer()
    @StateObject private var favorites = FavoritesStore()

    var body: some Scene {
        WindowGroup {
            AuthContainer()
                // Inject DI container into environment
                .environment(\.container, container)
                // Keep FavoritesStore available to views that expect it
                .environmentObject(favorites)
        }
    }
}
