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

// Extension to handle WhiteboardItem encoding/decoding
extension WhiteboardItem {
    // Override encode method to ensure proper encoding of scale and rotation
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(type.rawValue, forKey: .type)
        try container.encode(content, forKey: .content)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(position, forKey: .position)
        
        // Get the actual scale and rotation values from the object
        let actualScale = scale
        let actualRotation = rotation
        
        print("💾 Before encoding item \(id):")
        print("   Scale: \(String(describing: actualScale))")
        print("   Rotation: \(String(describing: actualRotation))")
        
        // Encode rotation - validate but preserve the value if valid
        if let rotation = actualRotation {
            if rotation.isNaN || rotation.isInfinite {
                print("⚠️ Found invalid rotation value: \(rotation) for item \(id), replacing with 0.0")
                try container.encode(0.0, forKey: .rotation)
            } else {
                print("🔄 Encoding rotation: \(rotation) for item \(id)")
                try container.encode(rotation, forKey: .rotation)
            }
        } else {
            print("⚠️ No rotation to encode for item \(id), using default 0.0")
            try container.encode(0.0, forKey: .rotation)
        }
        
        // Encode scale - validate but preserve the value if valid
        if let scale = actualScale {
            if scale.isNaN || scale.isInfinite || scale <= 0.0 {
                print("⚠️ Found invalid scale value: \(scale) for item \(id), replacing with 1.0")
                try container.encode(1.0, forKey: .scale)
            } else {
                print("🔢 Encoding scale: \(scale) for item \(id)")
                try container.encode(scale, forKey: .scale)
            }
        } else {
            print("⚠️ No scale to encode for item \(id), using default 1.0")
            try container.encode(1.0, forKey: .scale)
        }
    }
    
    // Add debug method for printing item properties
    public func logProperties() {
        print("📋 Item \(id) properties:")
        print("   Type: \(type)")
        print("   Position: \(position)")
        print("   Rotation: \(rotation ?? 0.0)")
        print("   Scale: \(scale ?? 1.0)")
    }
}

// Extension to fix potential issues in CGFloat values
extension CGFloat {
    public var isValid: Bool {
        return !isNaN && !isInfinite && self > 0
    }
} 