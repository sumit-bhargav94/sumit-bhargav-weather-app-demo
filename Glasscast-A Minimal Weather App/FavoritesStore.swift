//
//  FavoritesStore.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class FavoritesStore: ObservableObject {
    @Published private(set) var favorites: [FavoriteCity] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service: SupabaseFavoriting
    private let session: AppSession

    var mockMode: Bool = true

    init(service: SupabaseFavoriting = SupabaseService(), session: AppSession = AppSession()) {
        self.service = service
        self.session = session
    }

    var userID: UUID { session.currentUserID }

    func load() async {
        errorMessage = nil
        if mockMode {
            isLoading = true
            defer { isLoading = false }
            do {
                try await Task.sleep(nanoseconds: 200_000_000)
                if favorites.isEmpty {
                    favorites = [
                        FavoriteCity(id: UUID(), user_id: userID, city: "Cupertino", created_at: Date()),
                        FavoriteCity(id: UUID(), user_id: userID, city: "London", created_at: Date())
                    ]
                }
            } catch {
                // ignore
            }
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            favorites = try await service.fetchFavorites(for: userID)
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    func isFavorite(_ city: String) -> FavoriteCity? {
        favorites.first { $0.city.caseInsensitiveCompare(city) == .orderedSame }
    }

    func toggle(city: String) async {
        if let existing = isFavorite(city) {
            await remove(id: existing.id)
        } else {
            await add(city: city)
        }
    }

    func clearAll() async {
        errorMessage = nil
        if mockMode {
            favorites.removeAll()
            return
        }
        let ids = favorites.map { $0.id }
        for id in ids {
            do {
                try await service.removeFavorite(id: id)
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
        favorites.removeAll()
    }

    private func add(city: String) async {
        if mockMode {
            let mock = FavoriteCity(id: UUID(), user_id: userID, city: city, created_at: Date())
            favorites.insert(mock, at: 0)
            return
        }
        do {
            let new = try await service.addFavorite(for: userID, city: city)
            favorites.insert(new, at: 0)
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }

    private func remove(id: UUID) async {
        if mockMode {
            favorites.removeAll { $0.id == id }
            return
        }
        do {
            try await service.removeFavorite(id: id)
            favorites.removeAll { $0.id == id }
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
    }
}
