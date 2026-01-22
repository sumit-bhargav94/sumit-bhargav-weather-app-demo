//
//  WeatherAPIModels.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 22/01/26.
//

import Foundation

// MARK: - WeatherAPI current.json full model

struct WeatherAPIResponse: Codable, Sendable {
    let location: WeatherAPILocation
    let current: WeatherAPICurrent
}

struct WeatherAPILocation: Codable, Sendable {
    let name: String
    let region: String
    let country: String
    let lat: Double
    let lon: Double
    let tz_id: String
    let localtime_epoch: Int
    let localtime: String
}

struct WeatherAPICurrent: Codable, Sendable {
    let last_updated_epoch: Int
    let last_updated: String
    let temp_c: Double
    let temp_f: Double
    let is_day: Int
    let condition: WeatherAPICondition
    let wind_mph: Double
    let wind_kph: Double
    let wind_degree: Int
    let wind_dir: String
    let pressure_mb: Double
    let pressure_in: Double
    let precip_mm: Double
    let precip_in: Double
    let humidity: Int
    let cloud: Int
    let feelslike_c: Double
    let feelslike_f: Double
    let windchill_c: Double
    let windchill_f: Double
    let heatindex_c: Double
    let heatindex_f: Double
    let dewpoint_c: Double
    let dewpoint_f: Double
    let vis_km: Double
    let vis_miles: Double
    let uv: Double
    let gust_mph: Double
    let gust_kph: Double
    let air_quality: WeatherAPIAirQuality?
    // Optional solar fields present in your sample
    let short_rad: Double?
    let diff_rad: Double?
    let dni: Double?
    let gti: Double?
}

struct WeatherAPICondition: Codable, Sendable {
    let text: String
    let icon: String
    let code: Int
}

struct WeatherAPIAirQuality: Codable, Sendable {
    let co: Double?
    let no2: Double?
    let o3: Double?
    let so2: Double?
    let pm2_5: Double?
    let pm10: Double?
    let us_epa_index: Int?
    let gb_defra_index: Int?

    // Map hyphenated keys to underscores
    private enum CodingKeys: String, CodingKey {
        case co, no2, o3, so2, pm2_5 = "pm2_5", pm10
        case us_epa_index = "us-epa-index"
        case gb_defra_index = "gb-defra-index"
    }
}

// MARK: - WeatherAPI forecast.json minimal models (for days, astro, precip chance)

struct WeatherAPIForecastResponse: Codable, Sendable {
    let location: WeatherAPILocation
    let forecast: WeatherAPIForecast
}

struct WeatherAPIForecast: Codable, Sendable {
    let forecastday: [WeatherAPIForecastDay]
}

struct WeatherAPIForecastDay: Codable, Sendable {
    let date: String
    let day: WeatherAPIDay
    let astro: WeatherAPIAstro
}

struct WeatherAPIDay: Codable, Sendable {
    let maxtemp_c: Double
    let maxtemp_f: Double
    let mintemp_c: Double
    let mintemp_f: Double
    let avgtemp_c: Double?
    let avgtemp_f: Double?
    let maxwind_mph: Double?
    let maxwind_kph: Double?
    let totalprecip_mm: Double?
    let totalprecip_in: Double?
    let daily_chance_of_rain: Int?
    let daily_chance_of_snow: Int?
    let condition: WeatherAPICondition
    let avghumidity: Double?
    let uv: Double?
}

struct WeatherAPIAstro: Codable, Sendable {
    let sunrise: String
    let sunset: String
}

