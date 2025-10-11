import SwiftUI

extension Color {
    // Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Tennis theme colors
    static let tennisGreen = Color(hex: "#1a3d2e")
    static let tennisDarkGreen = Color(hex: "#0d2419")
    static let tennisYellow = Color(hex: "#C3D730")
    static let tennisOrange = Color(hex: "#FF6B35")
    static let tennisBlue = Color(hex: "#4A90E2")
    static let tennisLightBlue = Color(hex: "#87CEEB")
    static let tennisRed = Color(hex: "#FF6B6B")
    
    // UI colors
    static let cardBackground = Color.white.opacity(0.1)
    static let cardBorder = Color.white.opacity(0.2)
}
