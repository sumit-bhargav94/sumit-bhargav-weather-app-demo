//
//  WeatherAPIService.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 22/01/26.
//

import Foundation

struct WeatherAPIService: WeatherService, Sendable {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    // Exposed default API key for use across the app (replace/secure as needed)
    static var defaultAPIKey: String {
        // TODO: Move to a secure config (e.g., Info.plist or injected at launch)
        return "e576ecaf37344b5da74135851262201"
    }

    // MARK: - WeatherService

    func fetchCurrentWeather(for city: String) async throws -> CurrentWeather {
        let current = try await fetchCurrentRaw(query: city)
        // Also fetch today’s astro/precip so Home can show sunrise/sunset/precip chance
        let today = try await fetchForecastRaw(query: city, days: 1).forecast.forecastday.first
        return mapCurrent(api: current, today: today)
    }

    func fetch5DayForecast(for city: String) async throws -> [ForecastDay] {
        let resp = try await fetchForecastRaw(query: city, days: 5)
        return mapForecast5(resp: resp)
    }

    // MARK: - Networking

    private func fetchCurrentRaw(query: String) async throws -> WeatherAPIResponse {
        var comps = URLComponents(string: "https://api.weatherapi.com/v1/current.json")!
        comps.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "aqi", value: "yes")
        ]
        guard let url = comps.url else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            throw NSError(domain: "WeatherAPIService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
        }

        let decoder = JSONDecoder()
        return try decoder.decode(WeatherAPIResponse.self, from: data)
    }

    private func fetchForecastRaw(query: String, days: Int) async throws -> WeatherAPIForecastResponse {
        var comps = URLComponents(string: "https://api.weatherapi.com/v1/forecast.json")!
        comps.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "days", value: String(days)),
            URLQueryItem(name: "aqi", value: "yes"),
            URLQueryItem(name: "alerts", value: "no")
        ]
        guard let url = comps.url else { throw URLError(.badURL) }

        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            let body = String(data: data, encoding: .utf8) ?? "<non-UTF8 body>"
            throw NSError(domain: "WeatherAPIService", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode): \(body)"])
        }

        let decoder = JSONDecoder()
        return try decoder.decode(WeatherAPIForecastResponse.self, from: data)
    }

    // MARK: - Mapping

    private func mapCurrent(api: WeatherAPIResponse, today: WeatherAPIForecastDay?) -> CurrentWeather {
        let c = api.current
        let city = api.location.name
        let isDay = c.is_day == 1
        let condition = c.condition.text
        let symbol = symbolName(for: condition, isDay: isDay)
        let theme = themeFor(condition: condition, isDay: isDay)

        let tempF = c.temp_f
        let approxHigh = today?.day.maxtemp_f ?? max(c.temp_f, c.feelslike_f) + 2
        let approxLow = today?.day.mintemp_f ?? min(c.temp_f, c.windchill_f) - 2

        let precipChance = today?.day.daily_chance_of_rain ?? 0
        let sunrise = today?.astro.sunrise ?? "--:--"
        let sunset = today?.astro.sunset ?? "--:--"

        return CurrentWeather(
            city: city,
            temperature: Int(round(tempF)),
            condition: condition,
            high: Int(round(approxHigh)),
            low: Int(round(approxLow)),
            symbolName: symbol,
            theme: theme,
            // Enriched fields
            feelsLikeF: c.feelslike_f,
            windKph: c.wind_kph,
            humidity: c.humidity,
            pressureMb: c.pressure_mb,
            visibilityKm: c.vis_km,
            uvIndex: c.uv,
            gustKph: c.gust_kph,
            windDirection: c.wind_dir,
            windDegrees: c.wind_degree,
            dewpointF: c.dewpoint_f,
            heatIndexF: c.heatindex_f,
            aqiEPA: c.air_quality?.us_epa_index,
            aqiDEFRA: c.air_quality?.gb_defra_index,
            pm25: c.air_quality?.pm2_5,
            pm10: c.air_quality?.pm10,
            sunrise: sunrise,
            sunset: sunset,
            precipChance: precipChance
        )
    }

    private func mapForecast5(resp: WeatherAPIForecastResponse) -> [ForecastDay] {
        let cal = Calendar.current
        return resp.forecast.forecastday.map { fday in
            // Parse date string to weekday
            let weekday: String = {
                if let date = ISO8601DateFormatter().date(from: fday.date) {
                    let wd = cal.component(.weekday, from: date)
                    return cal.shortWeekdaySymbols[wd - 1]
                } else {
                    // WeatherAPI date is "YYYY-MM-DD"; parse manually
                    let comps = fday.date.split(separator: "-").compactMap { Int($0) }
                    if comps.count == 3 {
                        var dc = DateComponents()
                        dc.year = comps[0]; dc.month = comps[1]; dc.day = comps[2]
                        if let date = cal.date(from: dc) {
                            let wd = cal.component(.weekday, from: date)
                            return cal.shortWeekdaySymbols[wd - 1]
                        }
                    }
                    return fday.date
                }
            }()
            let isDay = true
            let symbol = symbolName(for: fday.day.condition.text, isDay: isDay)
            return ForecastDay(
                weekday: weekday,
                high: Int(round(fday.day.maxtemp_f)),
                low: Int(round(fday.day.mintemp_f)),
                symbolName: symbol
            )
        }
    }

    // MARK: - Helpers

    private func symbolName(for condition: String, isDay: Bool) -> String {
        let t = condition.lowercased()
        if t.contains("sunny") || t.contains("clear") {
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        }
        if t.contains("partly") || t.contains("cloud") {
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        }
        if t.contains("rain") || t.contains("drizzle") || t.contains("shower") {
            return "cloud.rain.fill"
        }
        if t.contains("thunder") || t.contains("storm") || t.contains("lightning") {
            return "cloud.bolt.rain.fill"
        }
        if t.contains("snow") || t.contains("sleet") || t.contains("blizzard") {
            return "snow"
        }
        if t.contains("fog") || t.contains("mist") || t.contains("haze") || t.contains("smoke") {
            return "cloud.fog.fill"
        }
        if t.contains("wind") || t.contains("breeze") || t.contains("gust") {
            return "wind"
        }
        return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
    }

    private func themeFor(condition: String, isDay: Bool) -> WeatherTheme {
        let t = condition.lowercased()
        if t.contains("thunder") || t.contains("storm") { return .stormy }
        if t.contains("rain") || t.contains("drizzle") || t.contains("shower") { return .rainy }
        if t.contains("snow") || t.contains("sleet") { return .coldSnowy }
        if t.contains("fog") || t.contains("mist") || t.contains("haze") || t.contains("smoke") { return .foggy }
        if t.contains("wind") || t.contains("breeze") || t.contains("gust") { return .windy }
        if t.contains("hot") || t.contains("humid") { return .hotHumid }
        // Default: sunny for day, foggy-ish at night clear
        return isDay ? .sunny : .foggy
    }
}

