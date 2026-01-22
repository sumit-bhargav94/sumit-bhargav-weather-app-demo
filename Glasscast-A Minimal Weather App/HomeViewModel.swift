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

    // Enriched fields from WeatherAPI current + today forecast
    let feelsLikeF: Double
    let windKph: Double
    let humidity: Int
    let pressureMb: Double
    let visibilityKm: Double
    let uvIndex: Double
    let gustKph: Double
    let windDirection: String
    let windDegrees: Int
    let dewpointF: Double
    let heatIndexF: Double
    let aqiEPA: Int?
    let aqiDEFRA: Int?
    let pm25: Double?
    let pm10: Double?
    let sunrise: String
    let sunset: String
    let precipChance: Int
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

    // Simple toggle to silence logs if desired
    private let loggingEnabled = true

    // Expose a safe, read-only way to tell if this model is using the default/mock service.
    // This avoids leaking the service instance while allowing the view to decide whether to swap in the injected one.
    var isUsingDefaultService: Bool {
        service is MockWeatherService
    }

    init(service: WeatherService = MockWeatherService()) {
        self.service = service
        if loggingEnabled {
            print("[HomeVM] init(service: \(type(of: service)))")
        }
    }

    func load() async {
        if loggingEnabled {
            print("[HomeVM] load() begin for city=\(city)")
        }
        await refresh()
        if loggingEnabled {
            print("[HomeVM] load() end")
        }
    }

    func refresh() async {
        let taskID = UUID()
        refreshTaskID = taskID

        // If a refresh is already running, ignore new ones until finished.
        guard !isLoading else {
            if loggingEnabled {
                print("[HomeVM] refresh() ignored; already loading")
            }
            return
        }

        if loggingEnabled {
            print("[HomeVM] refresh() begin id=\(taskID) city=\(city)")
        }
        setLoading(true)

        do {
            let start = Date()
            if loggingEnabled {
                print("[HomeVM] -> fetching current + 5-day forecast (real)")
            }

            async let c = service.fetchCurrentWeather(for: city)
            async let f = service.fetch5DayForecast(for: city)
            let (current, forecast) = try await (c, f)

            let elapsed = Date().timeIntervalSince(start)
            if loggingEnabled {
                print("[HomeVM] <- fetched in \(String(format: "%.2f", elapsed))s")
                print("[HomeVM] current: city=\(current.city) temp=\(current.temperature)F cond=\(current.condition) hi=\(current.high) lo=\(current.low) symbol=\(current.symbolName) uv=\(current.uvIndex)")
                let summary = forecast.map { "\($0.weekday): H\($0.high)L\($0.low)" }.joined(separator: ", ")
                print("[HomeVM] forecast(5): \(summary)")
            }

            // Only apply results if this is still the latest refresh
            guard taskID == refreshTaskID else {
                if loggingEnabled {
                    print("[HomeVM] refresh() discard results; newer task exists id=\(refreshTaskID)")
                }
                return
            }
            self.current = current
            self.forecast = forecast

            setLoaded()
            if loggingEnabled {
                print("[HomeVM] refresh() success id=\(taskID)")
            }
        } catch is CancellationError {
            setIdle()
            if loggingEnabled {
                print("[HomeVM] refresh() cancelled")
            }
        } catch {
            // Only show error if still the latest refresh
            guard taskID == refreshTaskID else {
                if loggingEnabled {
                    print("[HomeVM] refresh() error discarded; newer task exists id=\(refreshTaskID) err=\(error)")
                }
                return
            }
            setFailed((error as NSError).localizedDescription)
            if loggingEnabled {
                print("[HomeVM] refresh() failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Loading state helpers

    private func setLoading(_ loading: Bool) {
        isLoading = loading
        errorMessage = nil
        loadingState = loading ? .loading : .idle
        if loggingEnabled {
            print("[HomeVM] state -> \(loading ? "loading" : "idle")")
        }
    }

    private func setLoaded() {
        isLoading = false
        errorMessage = nil
        loadingState = .loaded
        if loggingEnabled {
            print("[HomeVM] state -> loaded")
        }
    }

    private func setFailed(_ message: String) {
        isLoading = false
        errorMessage = message
        loadingState = .failed(message)
        if loggingEnabled {
            print("[HomeVM] state -> failed '\(message)'")
        }
    }

    private func setIdle() {
        isLoading = false
        loadingState = .idle
        if loggingEnabled {
            print("[HomeVM] state -> idle")
        }
    }
}

// Keep a mock for previews/dev if needed; production will inject WeatherAPIService via AppContainer.
struct MockWeatherService: WeatherService {
    func fetchCurrentWeather(for city: String) async throws -> CurrentWeather {
        // This mock is no longer used in production Home, but kept for previews.
        return CurrentWeather(
            city: city,
            temperature: 72,
            condition: "Sunny",
            high: 76,
            low: 58,
            symbolName: "sun.max.fill",
            theme: .sunny,
            feelsLikeF: 74,
            windKph: 12,
            humidity: 50,
            pressureMb: 1016,
            visibilityKm: 10,
            uvIndex: 5,
            gustKph: 20,
            windDirection: "W",
            windDegrees: 270,
            dewpointF: 50,
            heatIndexF: 75,
            aqiEPA: 2,
            aqiDEFRA: 3,
            pm25: 12,
            pm10: 18,
            sunrise: "6:42 AM",
            sunset: "7:58 PM",
            precipChance: 10
        )
    }

    func fetch5DayForecast(for city: String) async throws -> [ForecastDay] {
        let weekdays = Calendar.current.shortWeekdaySymbols
        return (0..<5).map { i in
            ForecastDay(weekday: weekdays[(i + 1) % weekdays.count], high: 75 + i, low: 60 - i, symbolName: "sun.max.fill")
        }
    }
}

