//
//  HomeViewModel.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import Foundation
import SwiftUI
import WeatherKit
import Combine

struct CurrentWeather: Equatable, Sendable {
    let city: String
    let temperature: Int
    let condition: String
    let high: Int
    let low: Int
    let symbolName: String
    let theme: WeatherTheme
}

struct ForecastDay: Identifiable, Equatable, Sendable {
    let id = UUID()
    let weekday: String
    let high: Int
    let low: Int
    let symbolName: String
}

protocol WeatherService {
    func fetchCurrentWeather(for city: String) async throws -> CurrentWeather
    func fetch5DayForecast(for city: String) async throws -> [ForecastDay]
}

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var city: String = "Cupertino"
    @Published var current: CurrentWeather?
    @Published var forecast: [ForecastDay] = []

    // New standardized loading state
    @Published var loadingState: LoadingState = .idle

    // Backwards-compat (kept in sync)
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let service: WeatherService
    private var refreshTaskID = UUID()

    // Expose a safe, read-only way to tell if this model is using the default/mock service.
    // This avoids leaking the service instance while allowing the view to decide whether to swap in the injected one.
    var isUsingDefaultService: Bool {
        service is MockWeatherService
    }

    init(service: WeatherService = MockWeatherService()) {
        self.service = service
    }

    func load() async {
        await refresh()
    }

    func refresh() async {
        // Coalesce multiple refresh triggers: only latest task should win.
        let taskID = UUID()
        refreshTaskID = taskID

        // If a refresh is already running, ignore new ones until finished.
        guard !isLoading else { return }

        setLoading(true)

        do {
            async let c = service.fetchCurrentWeather(for: city)
            async let f = service.fetch5DayForecast(for: city)
            let (current, forecast) = try await (c, f)

            // Only apply results if this is still the latest refresh
            guard taskID == refreshTaskID else { return }
            self.current = current
            self.forecast = forecast

            setLoaded()
        } catch is CancellationError {
            // Benign: ignore cancellations from SwiftUI/refresh control lifecycle
            setIdle()
        } catch {
            // Only show error if still the latest refresh
            guard taskID == refreshTaskID else { return }
            setFailed((error as NSError).localizedDescription)
        }
    }

    // MARK: - Loading state helpers

    private func setLoading(_ loading: Bool) {
        isLoading = loading
        errorMessage = nil
        loadingState = loading ? .loading : .idle
    }

    private func setLoaded() {
        isLoading = false
        errorMessage = nil
        loadingState = .loaded
    }

    private func setFailed(_ message: String) {
        isLoading = false
        errorMessage = message
        loadingState = .failed(message)
    }

    private func setIdle() {
        isLoading = false
        loadingState = .idle
    }
}

struct MockWeatherService: WeatherService {
    func fetchCurrentWeather(for city: String) async throws -> CurrentWeather {
        try await Task.sleep(nanoseconds: 450_000_000)
        let options: [CurrentWeather] = [
            .init(city: city, temperature: 72, condition: "Sunny", high: 76, low: 58, symbolName: "sun.max.fill", theme: .sunny),
            .init(city: city, temperature: 61, condition: "Rain", high: 64, low: 55, symbolName: "cloud.rain.fill", theme: .rainy),
            .init(city: city, temperature: 66, condition: "Windy", high: 69, low: 57, symbolName: "wind", theme: .windy),
            .init(city: city, temperature: 34, condition: "Snow", high: 36, low: 28, symbolName: "snow", theme: .coldSnowy),
            .init(city: city, temperature: 84, condition: "Humid", high: 90, low: 73, symbolName: "humidity.fill", theme: .hotHumid),
            .init(city: city, temperature: 68, condition: "Fog", high: 70, low: 60, symbolName: "cloud.fog.fill", theme: .foggy),
            .init(city: city, temperature: 59, condition: "Storm", high: 62, low: 52, symbolName: "cloud.bolt.rain.fill", theme: .stormy)
        ]
        return options.randomElement()!
    }

    func fetch5DayForecast(for city: String) async throws -> [ForecastDay] {
        try await Task.sleep(nanoseconds: 300_000_000)
        let weekdays = Calendar.current.shortWeekdaySymbols
        let start = Int.random(in: 0..<weekdays.count)
        let ordered = (0..<5).map { i in
            weekdays[(start + i) % weekdays.count]
        }
        let symbols = ["sun.max.fill", "cloud.sun.fill", "cloud.rain.fill", "cloud.bolt.fill", "cloud.fog.fill", "wind", "snow"]
        return ordered.map { day in
            let low = Int.random(in: 40...70)
            let high = low + Int.random(in: 4...18)
            return ForecastDay(weekday: day, high: high, low: low, symbolName: symbols.randomElement()!)
        }
    }
}

