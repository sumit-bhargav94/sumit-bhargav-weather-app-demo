//
//  WeatherTheming.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import SwiftUI

// MARK: - Theme Model

enum WeatherTheme: CaseIterable, Equatable {
    case sunny
    case rainy
    case stormy
    case coldSnowy
    case windy
    case foggy
    case hotHumid
}

// MARK: - Background Renderer

struct WeatherBackground: View {
    let theme: WeatherTheme
    
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let d = min(w, h)
            
            ZStack {
                // Base graphite gradient
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.05, blue: 0.06),
                        Color(red: 0.07, green: 0.08, blue: 0.10),
                        Color(red: 0.08, green: 0.09, blue: 0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                switch theme {
                case .sunny:
                    SunnyLayer(d: d)
                case .rainy:
                    RainLayer(w: w, h: h, d: d)
                case .stormy:
                    StormLayer(d: d)
                case .coldSnowy:
                    SnowLayer(w: w, h: h, d: d)
                case .windy:
                    WindLayer(d: d)
                case .foggy:
                    FogLayer(d: d)
                case .hotHumid:
                    HotHumidLayer(d: d)
                }
            }
            .ignoresSafeArea()
        }
    }
}

// MARK: - Layers

// Sunny: soft warm glow and subtle aurora sweep
private struct SunnyLayer: View {
    let d: CGFloat
    @State private var phase: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.yellow.opacity(0.28), .clear],
                                     startPoint: .top,
                                     endPoint: .bottom))
                .frame(width: d * 1.2, height: d * 1.0)
                .blur(radius: d * 0.25)
                .offset(y: -d * 0.55)
                .blendMode(.plusLighter)
            
            RoundedRectangle(cornerRadius: d)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.orange.opacity(0.18),
                            Color.yellow.opacity(0.12),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: d * 1.6, height: d * 0.35)
                .rotationEffect(.degrees(Double(-10 + sin(phase) * 5)))
                .offset(x: -d * 0.2, y: -d * 0.1)
                .blur(radius: d * 0.18)
                .blendMode(.plusLighter)
        }
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

// Rain: realistic raindrops with depth, highlights, and ripples
private struct RainLayer: View {
    let w: CGFloat
    let h: CGFloat
    let d: CGFloat
    
    @State private var time: CGFloat = 0
    
    private struct Drop {
        var x: CGFloat
        var y: CGFloat
        var length: CGFloat
        var radius: CGFloat
        var speed: CGFloat
        var blur: CGFloat
        var thickness: CGFloat
        var rotation: CGFloat
        var layer: Int // 0 background, 1 mid, 2 foreground
        var ripplePhase: CGFloat
    }
    
    private func makeDrops(size: CGSize, count: Int, seed: Int) -> [Drop] {
        var rng = SeededRandom(seed: UInt64(seed))
        var drops: [Drop] = []
        drops.reserveCapacity(count)
        for i in 0..<count {
            let layer: Int = rng.nextFloat() < 0.2 ? 2 : (rng.nextFloat() < 0.55 ? 1 : 0)
            let base = CGFloat(layer + 1)
            let length = CGFloat(lerp(10, 26, rng.nextFloat())) * (0.7 + 0.15 * base)
            let radius = length * 0.22
            let speed = CGFloat(lerp(220, 520, rng.nextFloat())) * (0.7 + 0.2 * base)
            let blur = CGFloat(lerp(0.6, 2.6, rng.nextFloat())) * (0.6 + 0.4 * base)
            let thickness = CGFloat(lerp(0.8, 1.8, rng.nextFloat())) * (0.8 + 0.2 * base)
            let rotation = CGFloat(lerp(-10, -16, rng.nextFloat()))
            let x = CGFloat(rng.nextFloat()) * size.width
            // Start slightly above so drops spawn offscreen
            let y = -CGFloat(rng.nextFloat()) * size.height
            let ripplePhase = CGFloat(rng.nextFloat()) * .pi * 2
            drops.append(Drop(x: x,
                              y: y,
                              length: length,
                              radius: radius,
                              speed: speed,
                              blur: blur,
                              thickness: thickness,
                              rotation: rotation,
                              layer: layer,
                              ripplePhase: ripplePhase))
            // Slight horizontal clustering for natural bands
            if i % 9 == 0 && rng.nextFloat() < 0.5 {
                let clusterCount = 2 + Int(rng.nextFloat() * 3)
                for _ in 0..<clusterCount {
                    let dx = CGFloat(lerp(-14, 14, rng.nextFloat()))
                    let x2 = (x + dx).truncatingRemainder(dividingBy: size.width)
                    drops.append(Drop(x: x2,
                                      y: y - CGFloat(rng.nextFloat()) * 80,
                                      length: length * CGFloat(lerp(0.85, 1.15, rng.nextFloat())),
                                      radius: radius * CGFloat(lerp(0.85, 1.15, rng.nextFloat())),
                                      speed: speed * CGFloat(lerp(0.9, 1.1, rng.nextFloat())),
                                      blur: blur * CGFloat(lerp(0.8, 1.2, rng.nextFloat())),
                                      thickness: thickness * CGFloat(lerp(0.85, 1.15, rng.nextFloat())),
                                      rotation: rotation + CGFloat(lerp(-1.5, 1.5, rng.nextFloat())),
                                      layer: layer,
                                      ripplePhase: ripplePhase + CGFloat(rng.nextFloat()) * .pi / 2))
                }
            }
        }
        return drops
    }
    
    var body: some View {
        ZStack {
            // Moist air tint
            LinearGradient(
                colors: [Color.blue.opacity(0.08), Color.clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)
            
            TimelineView(.animation) { timeline in
                Canvas(opaque: false, colorMode: .extendedLinear) { context, size in
                    // Seed stable across frames
                    let baseCount = Int(max(90, d * 0.9))
                    let drops = makeDrops(size: size, count: baseCount, seed: 1337)
                    
                    // Current time factor
                    let t = time
                    
                    // Layered drawing for depth ordering
                    for layer in 0...2 {
                        var layerContext = context
                        if layer == 0 {
                            layerContext.opacity = 0.55
                        } else if layer == 1 {
                            layerContext.opacity = 0.75
                        } else {
                            layerContext.opacity = 0.95
                        }
                        
                        for drop in drops where drop.layer == layer {
                            // Position with wrap
                            let fallY = (drop.y + drop.speed * t)
                                .truncatingRemainder(dividingBy: size.height + drop.length + 20) - drop.length
                            // Slight wind drift
                            let driftX = t * 30
                            let x = (drop.x + driftX).truncatingRemainder(dividingBy: size.width)
                            
                            // Draw the raindrop (teardrop shape with highlight)
                            var path = Path()
                            let L = drop.length
                            let R = drop.radius
                            
                            // Build a teardrop aligned vertically, then rotate
                            let rect = CGRect(x: x - R, y: fallY - L * 0.1, width: R * 2, height: L)
                            let center = CGPoint(x: rect.midX, y: rect.midY)
                            
                            // Teardrop path using two quadratic curves
                            path.move(to: CGPoint(x: center.x, y: rect.minY))
                            path.addQuadCurve(
                                to: CGPoint(x: rect.maxX, y: rect.minY + L * 0.55),
                                control: CGPoint(x: rect.maxX, y: rect.minY + L * 0.2)
                            )
                            path.addQuadCurve(
                                to: CGPoint(x: center.x, y: rect.maxY),
                                control: CGPoint(x: rect.maxX - R * 0.2, y: rect.maxY - L * 0.18)
                            )
                            path.addQuadCurve(
                                to: CGPoint(x: rect.minX, y: rect.minY + L * 0.55),
                                control: CGPoint(x: rect.minX + R * 0.2, y: rect.maxY - L * 0.18)
                            )
                            path.addQuadCurve(
                                to: CGPoint(x: center.x, y: rect.minY),
                                control: CGPoint(x: rect.minX, y: rect.minY + L * 0.2)
                            )
                            
                            // Rotate the path by drop.rotation (degrees)
                            let radians = drop.rotation * .pi / 180
                            let transform = CGAffineTransform(translationX: -center.x, y: -center.y)
                                .rotated(by: radians)
                                .translatedBy(x: center.x, y: center.y)
                            path = path.applying(transform)
                            
                            // Inner gradient to emulate refraction using Canvas linearGradient
                            let gradient = Gradient(colors: [
                                Color.white.opacity(0.28),
                                Color.white.opacity(0.10),
                                Color.clear
                            ])
                            
                            layerContext.fill(
                                path,
                                with: .linearGradient(
                                    gradient,
                                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                                    endPoint: CGPoint(x: rect.maxX, y: rect.maxY)
                                )
                            )
                            
                            // Subtle stroke
                            layerContext.stroke(path,
                                                with: .color(Color.white.opacity(0.25)),
                                                lineWidth: drop.thickness * 0.6)
                            
                            // Specular highlight streak
                            var highlight = Path()
                            let hx1 = center.x - R * 0.35
                            let hy1 = fallY + L * 0.1
                            highlight.move(to: CGPoint(x: hx1, y: hy1))
                            highlight.addQuadCurve(to: CGPoint(x: hx1 + R * 0.3, y: hy1 + L * 0.35),
                                                   control: CGPoint(x: hx1 - R * 0.2, y: hy1 + L * 0.2))
                            let hTransform = CGAffineTransform(translationX: -center.x, y: -center.y)
                                .rotated(by: radians)
                                .translatedBy(x: center.x, y: center.y)
                            highlight = highlight.applying(hTransform)
                            layerContext.stroke(highlight,
                                                with: .color(Color.white.opacity(0.35)),
                                                lineWidth: max(0.6, drop.thickness * 0.5))
                            
                            // Motion blur proportional to layer depth
                            if drop.blur > 0.1 {
                                layerContext.addFilter(.blur(radius: drop.blur))
                            }
                            
                            // Splash ripple near bottom
                            if fallY + L > size.height - 6 {
                                let progress = min(1, (fallY + L - (size.height - 6)) / 14)
                                let rippleAlpha = (1 - progress) * 0.35 * (0.4 + 0.3 * CGFloat(layer))
                                let rippleRadius = 4 + 16 * progress
                                let rippleWidth: CGFloat = 1.0
                                let rippleCenter = CGPoint(x: x, y: size.height - 3)
                                
                                var ripple = Path()
                                ripple.addEllipse(in: CGRect(x: rippleCenter.x - rippleRadius,
                                                             y: rippleCenter.y - rippleRadius * 0.35,
                                                             width: rippleRadius * 2,
                                                             height: rippleRadius * 0.7))
                                layerContext.stroke(ripple,
                                                    with: .color(Color.white.opacity(rippleAlpha)),
                                                    lineWidth: rippleWidth)
                            }
                        }
                    }
                }
            }
            .rotationEffect(.degrees(12))
        }
        .onAppear {
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                time = d // acts as a continually increasing value due to animation engine sampling
            }
        }
    }
    
    // MARK: - Utilities
    
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: Float) -> CGFloat {
        a + (b - a) * CGFloat(t)
    }
    
    private struct SeededRandom {
        private var state: UInt64
        init(seed: UInt64) { self.state = seed &* 0x9E3779B97F4A7C15 }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func nextFloat() -> Float {
            let v = next() >> 40
            return Float(v) / Float(1 << 24)
        }
    }
}

// Storm: darker base + faint lightning glow pulses
private struct StormLayer: View {
    let d: CGFloat
    @State private var pulse: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.white.opacity(0.06), .clear],
                                     startPoint: .topTrailing,
                                     endPoint: .bottomLeading))
                .frame(width: d * 1.0, height: d * 1.0)
                .blur(radius: d * 0.28)
                .offset(x: d * 0.25, y: -d * 0.4)
                .opacity(0.4 + 0.3 * CGFloat(sin(Double(pulse))))
                .blendMode(.plusLighter)
            
            Circle()
                .fill(LinearGradient(colors: [Color.blue.opacity(0.12), .clear],
                                     startPoint: .bottomLeading,
                                     endPoint: .topTrailing))
                .frame(width: d * 1.1, height: d * 1.1)
                .blur(radius: d * 0.25)
                .offset(x: -d * 0.3, y: d * 0.5)
                .blendMode(.plusLighter)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                pulse = .pi * 2
            }
        }
    }
}

// Cold/Snowy: drifting snow particles
private struct SnowLayer: View {
    let w: CGFloat
    let h: CGFloat
    let d: CGFloat
    @State private var fall: CGFloat = 0
    
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.white.opacity(0.06), .clear],
                           startPoint: .top,
                           endPoint: .bottom)
                .blendMode(.plusLighter)
            
            TimelineView(.animation) { _ in
                Canvas { context, size in
                    let count = Int(max(80, d * 0.5))
                    for i in 0..<count {
                        let x = CGFloat.random(in: 0...size.width)
                        let r = CGFloat.random(in: 0.8...2.2)
                        let speed = CGFloat.random(in: 0.15...0.35)
                        let y = (fall * speed + CGFloat(i) * 8).truncatingRemainder(dividingBy: size.height + 10) - 10
                        let rect = CGRect(x: x, y: y, width: r, height: r)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(0.7)))
                    }
                }
            }
            .blur(radius: 0.6)
        }
        .onAppear {
            withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
                fall = d
            }
        }
    }
}

// Windy: sweeping bands to imply motion
private struct WindLayer: View {
    let d: CGFloat
    @State private var shift: CGFloat = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                RoundedRectangle(cornerRadius: d)
                    .fill(LinearGradient(colors: [Color.white.opacity(0.08), .clear],
                                         startPoint: .leading,
                                         endPoint: .trailing))
                    .frame(width: d * 1.6, height: d * 0.12)
                    .offset(x: -d * 0.8 + shift + CGFloat(i) * d * 0.35,
                            y: -d * 0.3 + CGFloat(i) * d * 0.18)
                    .blur(radius: d * 0.08)
            }
        }
        .blendMode(.plusLighter)
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                shift = d * 1.2
            }
        }
    }
}

// Foggy: layered translucent sheets
private struct FogLayer: View {
    let d: CGFloat
    @State private var drift: CGFloat = 0
    
    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: d)
                    .fill(Color.white.opacity(0.06 + 0.03 * Double(i)))
                    .frame(width: d * 1.6, height: d * 0.4)
                    .offset(x: -d * 0.8 + drift + CGFloat(i) * d * 0.3,
                            y: -d * 0.1 + CGFloat(i) * d * 0.18)
                    .blur(radius: d * 0.18)
            }
        }
        .blendMode(.plusLighter)
        .onAppear {
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                drift = d * 0.8
            }
        }
    }
}

// Hot/Humid: warm glow bands
private struct HotHumidLayer: View {
    let d: CGFloat
    @State private var phase: CGFloat = 0
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color.red.opacity(0.18), .clear],
                                     startPoint: .topLeading,
                                     endPoint: .bottomTrailing))
                .frame(width: d * 1.2, height: d * 1.0)
                .blur(radius: d * 0.28)
                .offset(x: -d * 0.2, y: -d * 0.5)
                .blendMode(.plusLighter)
            
            RoundedRectangle(cornerRadius: d)
                .fill(
                    LinearGradient(colors: [Color.orange.opacity(0.18),
                                            Color.pink.opacity(0.12),
                                            .clear],
                                   startPoint: .leading,
                                   endPoint: .trailing)
                )
                .frame(width: d * 1.5, height: d * 0.32)
                .rotationEffect(.degrees(Double(-8 + sin(phase) * 6)))
                .offset(x: d * 0.1, y: d * 0.05)
                .blur(radius: d * 0.2)
                .blendMode(.plusLighter)
        }
        .onAppear {
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: true)) {
                phase = .pi * 2
            }
        }
    }
}

