import Foundation
import SwiftUI

enum TemperatureUnit {
    // Single source of truth for the unit preference across the app
    @AppStorage("useCelsius") private static var useCelsius: Bool = true

    // Convert a Fahrenheit integer to preferred unit
    static func convert(_ f: Int) -> Int {
        guard useCelsius else { return f }
        let c = (Double(f) - 32.0) * 5.0 / 9.0
        return Int(round(c))
    }

    // Convert high/low pair
    static func convert(high: Int, low: Int) -> (Int, Int) {
        (convert(high), convert(low))
    }

    // Convert temp/high/low triple
    static func convert(temp: Int, high: Int, low: Int) -> (Int, Int, Int) {
        (convert(temp), convert(high), convert(low))
    }

    // Unit label for display
    static var unitLabel: String {
//        useCelsius ? "°C" : "°F"
        useCelsius ? "C" : "F"

    }
}
