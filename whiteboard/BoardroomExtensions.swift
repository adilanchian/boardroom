import Foundation
import SwiftUI

// Extension to make CGPoint codable so it can be saved
extension CGPoint: Codable {
    private enum CodingKeys: String, CodingKey {
        case x, y
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(CGFloat.self, forKey: .x)
        let y = try container.decode(CGFloat.self, forKey: .y)
        self.init(x: x, y: y)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }
}

// Extension to handle BoardroomItem encoding/decoding
extension BoardroomItem {
    // Add debug method for printing item properties
    public func logProperties() {
        print("📋 Item \(id) properties:")
        print("   Type: \(type)")
        print("   Position: \(position)")
        print("   Rotation: \(rotation)")
        print("   Scale: \(scale)")
        print("   Boardroom ID: \(boardroomId)")
    }
}

// Extension to fix potential issues in CGFloat values
extension CGFloat {
    public var isValid: Bool {
        return !isNaN && !isInfinite && self > 0
    }
}

// Helper struct to track item state during interaction
struct BoardItemState {
    var position: CGPoint
    var rotation: Double
    var scale: Double
}

// Extension to provide hex color conversion
extension Color {
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
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String? {
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        guard uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) else {
            return nil
        }
        
        let redComponent = Int(r * 255.0)
        let greenComponent = Int(g * 255.0)
        let blueComponent = Int(b * 255.0)
        
        return String(format: "#%02X%02X%02X", redComponent, greenComponent, blueComponent)
    }
} 