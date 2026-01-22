//
//  Glasscast_A_Minimal_Weather_AppApp.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 20/01/26.
//

import SwiftUI

@main
struct Glasscast_A_Minimal_Weather_AppApp: App {
    // Create one shared container for the whole app
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            AuthContainer()
                // Inject DI container into environment
                .environment(\.container, container)
                // Expose the single FavoritesStore instance app-wide
                .environmentObject(container.favoritesStore)
        }
    }
}
