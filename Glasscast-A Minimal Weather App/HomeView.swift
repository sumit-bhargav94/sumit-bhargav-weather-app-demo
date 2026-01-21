//
//  HomeView.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 22/01/26.
//

import Foundation
import SwiftUI


struct HomeView: View {
    @StateObject private var model: HomeViewModel
    
    // Keep wind/pressure here; temperature unit now comes from TemperatureUnit.
    @AppStorage("windUnitIsKmh") private var windUnitIsKmh: Bool = true
    @AppStorage("pressureUnitIsHpa") private var pressureUnitIsHpa: Bool = true
    // Read notification prefs set in SettingsView
    @AppStorage("notificationsSevereAlerts") private var severeAlerts: Bool = true
    @AppStorage("notificationsDailySummary") private var dailySummary: Bool = false
    
    // If no data yet, pick a pleasant default theme for background
    private var theme: WeatherTheme {
        model.current?.theme ?? .sunny
    }
    
    init() {
        // Initialize once; HomeViewModel defaults to MockWeatherService
        _model = StateObject(wrappedValue: HomeViewModel())
    }
    
    var body: some View {
        ZStack {
            WeatherBackground(theme: theme)
                .ignoresSafeArea()
            
            GeometryReader { proxy in
                let safeTop = proxy.safeAreaInsets.top
                let safeBottom = proxy.safeAreaInsets.bottom
                let contentTopPadding = max(24, safeTop + 8)
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        header
                        // Notifications banner reflects SettingsView toggles
                        notificationsBanner
                        currentCard
                        forecastStrip
                        sunriseSunsetCard
                        todayHighlightsGrid
                        precipitationCard
                        
                        // Standardized error message rendering
                        if case let .failed(message) = model.loadingState {
                            Text(message)
                                .font(.footnote)
                                .foregroundColor(.red.opacity(0.9))
                                .padding(.top, 8)
                        }
                        
                        Spacer(minLength: 16)
                    }
                    .padding(.top, contentTopPadding)
                    .padding(.bottom, max(24, safeBottom + 8))
                    .frame(maxWidth: 700) // keeps it elegant on larger devices
                }
                .refreshable {
                    await model.refresh()
                }
            }
            
            // Optional overlay spinner for .loading
            if case .loading = model.loadingState {
                ProgressView()
                    .tint(.cyan)
                    .scaleEffect(1.2)
            }
        }
        .task {
            await model.load()
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private var header: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "cloud.sun.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                }
                .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Glasscast")
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundColor(.white)
                Text("A Minimal Weather App")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
            }
            
        }
    }
    
    // Reflect notifications preferences from SettingsView
    private var notificationsBanner: some View {
        Group {
            if severeAlerts || dailySummary {
                HStack(spacing: 12) {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: severeAlerts ? "exclamationmark.triangle.fill" : "bell.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(severeAlerts ? .red.opacity(0.95) : .white.opacity(0.95))
                        }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if severeAlerts && dailySummary {
                            Text("Severe Alerts + Daily Summary")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("You’ll receive severe weather alerts and a daily digest.")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        } else if severeAlerts {
                            Text("Severe Weather Alerts")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("Enabled in Settings")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text("Daily Summary")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text("Enabled in Settings")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .liquidGlass(cornerRadius: 16, intensity: 0.30)
                .padding(.horizontal, 16)
            }
        }
    }
    
    private var currentCard: some View {
        VStack(spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.current?.city ?? "Loading...")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        if let condition = model.current?.condition {
                            Text(condition)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                        if let high = model.current?.high, let low = model.current?.low {
                            let (h, l) = TemperatureUnit.convert(high: high, low: low)
                            Text("H \(h)°  L \(l)°")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
                
                if let symbol = model.current?.symbolName {
                    Image(systemName: symbol)
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
                }
            }
            
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                let temp = TemperatureUnit.convert(model.current?.temperature ?? 0)
                Text("\(temp)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                Text("°")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .offset(y: -6)
                    .foregroundColor(.white.opacity(0.9))
                
                Text(TemperatureUnit.unitLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .padding(.leading, 2)
                
                Spacer()
                
                if case .loading = model.loadingState {
                    ProgressView()
                        .tint(.cyan)
                } else {
                    Button {
                        Task { await model.refresh() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(20)
        .liquidGlass(cornerRadius: 28, intensity: 0.45)
        .padding(.horizontal, 16)
    }
    
    private var forecastStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("5-Day Forecast")
                .font(.headline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(model.forecast) { day in
                        VStack(spacing: 10) {
                            Text(day.weekday.uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.white.opacity(0.8))
                            
                            Image(systemName: day.symbolName)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(.white)
                            
                            HStack(spacing: 6) {
                                let (h, l) = TemperatureUnit.convert(high: day.high, low: day.low)
                                Text("\(h)°")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Text("\(l)°")
                                    .font(.footnote)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 16)
                        .padding(.horizontal, 14)
                        .frame(width: 120)
                        .liquidGlass(cornerRadius: 20, intensity: 0.35)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 4)
            }
        }
    }
    
    // Sunrise / Sunset card with simple progress
    private var sunriseSunsetCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Sunrise & Sunset", systemImage: "sunrise.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "sunrise.fill").foregroundColor(.yellow)
                        Text(demoSunriseString)
                            .foregroundColor(.white)
                            .font(.headline.bold())
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "sunset.fill").foregroundColor(.orange)
                        Text(demoSunsetString)
                            .foregroundColor(.white)
                            .font(.headline.bold())
                    }
                }
                
                Spacer()
                
                SunriseArc(progress: demoSunProgress)
                    .frame(width: 96, height: 56)
            }
        }
        .padding(16)
        .liquidGlass(cornerRadius: 22, intensity: 0.35)
        .padding(.horizontal, 16)
    }
    
    // Today Highlights grid
    private var todayHighlightsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today’s Highlights")
                .font(.headline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 16)
            
            let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
            
            LazyVGrid(columns: columns, spacing: 12) {
                highlightTile(icon: "thermometer.sun.fill",
                              title: "Feels Like",
                              value: "\(TemperatureUnit.convert(demoFeelsLike))°\(TemperatureUnit.unitLabel)")
                highlightTile(icon: "wind",
                              title: "Wind",
                              value: formattedWind(demoWind))
                highlightTile(icon: "humidity.fill",
                              title: "Humidity",
                              value: "\(demoHumidity)%")
                highlightTile(icon: "gauge.with.dots.needle.bottom.50percent",
                              title: "Pressure",
                              value: formattedPressure(demoPressure))
                highlightTile(icon: "eye.fill",
                              title: "Visibility",
                              value: formattedVisibility(demoVisibility))
                highlightTile(icon: "sun.max.trianglebadge.exclamationmark",
                              title: "UV Index",
                              value: "\(demoUV)")
            }
            .padding(.horizontal, 16)
        }
    }
    
    // Small precipitation card
    private var precipitationCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "cloud.rain.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 2) {
                Text("Precipitation")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                Text("Chance today")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            Text("\(demoPrecipChance)%")
                .font(.headline.bold())
                .foregroundColor(.white)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .liquidGlass(cornerRadius: 18, intensity: 0.30)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helpers: tiles and formatting
    
    private func highlightTile(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.95))
                }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundColor(.white.opacity(0.8))
                    .font(.caption)
                Text(value)
                    .foregroundColor(.white)
                    .font(.subheadline.bold())
            }
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .liquidGlass(cornerRadius: 16, intensity: 0.30)
    }
    
    private func formattedWind(_ speedKmh: Double) -> String {
        if windUnitIsKmh {
            return String(format: "%.0f km/h", speedKmh)
        } else {
            let mph = speedKmh * 0.621371
            return String(format: "%.0f mph", mph)
        }
    }
    
    private func formattedPressure(_ hPa: Double) -> String {
        if pressureUnitIsHpa {
            return String(format: "%.0f hPa", hPa)
        } else {
            // 1 inHg ≈ 33.8639 hPa
            let inHg = hPa / 33.8639
            return String(format: "%.2f inHg", inHg)
        }
    }
    
    private func formattedVisibility(_ km: Double) -> String {
        if windUnitIsKmh {
            return String(format: "%.1f km", km)
        } else {
            let miles = km * 0.621371
            return String(format: "%.1f mi", miles)
        }
    }
    
    // MARK: - Demo/Placeholder metrics (replace with real model fields later)
    private var lastUpdatedString: String {
        // In real data, bind to a timestamp from the model
        let df = DateFormatter()
        df.dateFormat = "h:mm a"
        return df.string(from: Date())
    }
    private var demoFeelsLike: Int {
        // Approximation using current +/- small delta
        let base = model.current?.temperature ?? 68
        return max(0, base + Int.random(in: -2...2))
    }
    private var demoWind: Double {
        // km/h
        switch theme {
        case .windy: return 28
        case .stormy: return 32
        default: return 14
        }
    }
    private var demoHumidity: Int {
        switch theme {
        case .hotHumid: return 78
        case .rainy, .foggy: return 82
        default: return 55
        }
    }
    private var demoPressure: Double {
        switch theme {
        case .stormy, .rainy: return 1006
        default: return 1016
        }
    }
    private var demoVisibility: Double {
        switch theme {
        case .foggy: return 3.2
        default: return 10.0
        }
    }
    private var demoUV: Int {
        switch theme {
        case .sunny, .hotHumid: return 7
        default: return 3
        }
    }
    private var demoPrecipChance: Int {
        switch theme {
        case .rainy, .stormy: return 80
        default: return 10
        }
    }
    private var demoSunriseString: String {
        "6:42 AM"
    }
    private var demoSunsetString: String {
        "7:58 PM"
    }
    private var demoSunProgress: Double {
        // 0...1 across the day; demo value
        0.55
    }
}

// MARK: - Sunrise Arc view (compact)
private struct SunriseArc: View {
    var progress: Double // 0...1
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let radius = min(w, h) * 0.9
            
            ZStack {
                // Base arc
                Arc(startAngle: .degrees(180), endAngle: .degrees(0))
                    .stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: radius, height: radius/1.6)
                
                // Progress arc
                Arc(startAngle: .degrees(180), endAngle: .degrees(180 + 180 * progress))
                    .stroke(LinearGradient(colors: [.yellow, .orange], startPoint: .leading, endPoint: .trailing),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: radius, height: radius/1.6)
                
                // Sun knob
                let angle = Angle.degrees(180 + 180 * progress)
                let r = radius/2.0
                let cx = w/2
                let cy = h/2 + radius/4.0
                let sunX = cx + CGFloat(cos(angle.radians)) * r
                let sunY = cy + CGFloat(sin(angle.radians)) * r
                Circle()
                    .fill(LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 12, height: 12)
                    .shadow(color: .yellow.opacity(0.6), radius: 6)
                    .position(x: sunX, y: sunY)
            }
        }
    }
}

private struct Arc: Shape {
    var startAngle: Angle
    var endAngle: Angle
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.maxY)
        let radius = min(rect.width, rect.height)
        p.addArc(center: center, radius: radius/2,
                 startAngle: startAngle,
                 endAngle: endAngle,
                 clockwise: false)
        return p
    }
}

#Preview {
    HomeView()
}
