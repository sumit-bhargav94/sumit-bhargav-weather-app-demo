//
//  LiquidGlass.swift
//  Glasscast-A Minimal Weather App
//
//  Created by Sam's Mac on 21/01/26.
//

import Foundation
import SwiftUI
 

struct LiquidGlass: ViewModifier {
    var cornerRadius: CGFloat
    var intensity: Float

    @State private var time: Float = 0

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .distortionEffect(
                        Shader(
                            function: ShaderFunction(
                                library: .default,
                                name: "liquidRefraction"
                            ),
                            arguments: [
                                .float(time),
                                .float(intensity)
                            ]
                        ),
                        maxSampleOffset: CGSize(width: 12, height: 12)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.35),
                                        .clear,
                                        .white.opacity(0.15)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: .black.opacity(0.3), radius: 30, y: 20)
            .task {
                withAnimation(
                    .linear(duration: 10)
                    .repeatForever(autoreverses: false)
                ) {
                    time = 20
                }
            }
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat, intensity: Float = 0.4) -> some View {
        modifier(LiquidGlass(cornerRadius: cornerRadius, intensity: intensity))
    }
}
