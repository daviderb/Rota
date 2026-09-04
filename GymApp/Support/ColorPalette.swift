import SwiftUI

/// Fixed set of tile colors the user can pick from (Bring!-style bold cards).
enum Palette {
    static let hexes: [String] = [
        "FF6B5E", // coral
        "FFA726", // amber
        "9CCC65", // lime
        "26A69A", // teal
        "42A5F5", // sky
        "5C6BC0", // indigo
        "AB47BC", // purple
        "EC407A", // pink
    ]
}

extension Color {
    /// Creates a color from a "RRGGBB" hex string.
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
            .scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
