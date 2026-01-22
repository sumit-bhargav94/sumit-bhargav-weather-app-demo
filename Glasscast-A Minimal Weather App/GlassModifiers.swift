import SwiftUI

extension View {
    // Neutral glass style for search fields
    func glassSearchFieldStyle(cornerRadius: CGFloat = 16) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 10, y: 6)
            )
    }
    
    // Tinted glass card that varies slightly by city hash to keep the UI lively
    func glassCardTinted(cornerRadius: CGFloat = 20, city: String) -> some View {
        // Create a stable hue from the city string
        let hue = Double(abs(city.hashValue % 360)) / 360.0
        let tint = Color(hue: hue, saturation: 0.35, brightness: 1.0).opacity(0.18)
        
        return self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        // Subtle gradient tint for personality
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [tint, Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.plusLighter)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.25), radius: 12, y: 8)
            )
    }
}
