import Foundation
import SwiftUI

// Create a standard date formatter that supports fractional seconds
extension ISO8601DateFormatter {
    static let shared: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

// Boardroom model
struct Boardroom: Identifiable, Codable {
    var id: String
    var name: String
    var items: [BoardroomItem] // This is for in-memory usage, not stored in DB
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(id: String = UUID().uuidString, 
         name: String, 
         items: [BoardroomItem] = [],
         createdBy: String,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.items = items
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Custom init from decoder to handle both string and date formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        
        // Handle date fields which could be strings or actual dates
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            // Try to decode date from string (from API)
            if let date = ISO8601DateFormatter.shared.date(from: createdAtString) {
                createdAt = date
            } else {
                createdAt = Date()
                print("Warning: Could not parse createdAt date: \(createdAtString)")
            }
        } else {
            // Direct date decoding (from our own encoder)
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let updatedAtString = try? container.decode(String.self, forKey: .updatedAt) {
            // Try to decode date from string
            if let date = ISO8601DateFormatter.shared.date(from: updatedAtString) {
                updatedAt = date
            } else {
                updatedAt = Date()
                print("Warning: Could not parse updatedAt date: \(updatedAtString)")
            }
        } else {
            // Direct date decoding or fallback
            updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()
        }
        
        // Items array is handled externally, not in the JSON from API
        items = []
    }
}

// BoardroomItem model
struct BoardroomItem: Identifiable, Codable {
    var id: String
    var boardroomId: String
    var type: ItemType
    var content: String
    var positionX: Double
    var positionY: Double
    var rotation: Double
    var scale: Double
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    
    enum ItemType: String, Codable {
        case text
        case image
        case drawing
    }
    
    enum CodingKeys: String, CodingKey {
        case id, type, content
        case boardroomId = "boardroom_id"
        case positionX = "position_x"
        case positionY = "position_y"
        case rotation, scale
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Helper to get/set position as CGPoint
    var position: CGPoint {
        get {
            return CGPoint(x: positionX, y: positionY)
        }
        set {
            positionX = Double(newValue.x)
            positionY = Double(newValue.y)
        }
    }
    
    init(id: String = UUID().uuidString,
         boardroomId: String,
         type: ItemType,
         content: String,
         position: CGPoint,
         rotation: Double = 0,
         scale: Double = 1,
         createdBy: String,
         createdAt: Date = Date(),
         updatedAt: Date = Date()) {
        self.id = id
        self.boardroomId = boardroomId
        self.type = type
        self.content = content
        self.positionX = Double(position.x)
        self.positionY = Double(position.y)
        self.rotation = rotation
        self.scale = scale
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Custom init from decoder to handle date formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        boardroomId = try container.decode(String.self, forKey: .boardroomId)
        
        // Decode type - can be string or enum
        if let typeString = try? container.decode(String.self, forKey: .type) {
            if let itemType = ItemType(rawValue: typeString) {
                type = itemType
            } else {
                type = .text  // Default if unknown
                print("Warning: Unknown item type: \(typeString)")
            }
        } else {
            type = try container.decode(ItemType.self, forKey: .type)
        }
        
        content = try container.decode(String.self, forKey: .content)
        positionX = try container.decode(Double.self, forKey: .positionX)
        positionY = try container.decode(Double.self, forKey: .positionY)
        rotation = try container.decode(Double.self, forKey: .rotation)
        scale = try container.decode(Double.self, forKey: .scale)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        
        // Handle date fields which could be strings or actual dates
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            if let date = ISO8601DateFormatter.shared.date(from: createdAtString) {
                createdAt = date
            } else {
                createdAt = Date()
                print("Warning: Could not parse item createdAt date: \(createdAtString)")
            }
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let updatedAtString = try? container.decode(String.self, forKey: .updatedAt) {
            if let date = ISO8601DateFormatter.shared.date(from: updatedAtString) {
                updatedAt = date
            } else {
                updatedAt = Date()
                print("Warning: Could not parse item updatedAt date: \(updatedAtString)")
            }
        } else {
            updatedAt = (try? container.decode(Date.self, forKey: .updatedAt)) ?? Date()
        }
    }
}

// BoardroomMember model
struct BoardroomMember: Codable, Identifiable {
    var boardroomId: String
    var userId: String
    var joinedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case boardroomId = "boardroom_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
    }
    
    // Computed ID for use as dictionary key
    var id: String {
        return "\(boardroomId)_\(userId)"
    }
    
    // Custom init from decoder to handle date formats
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        boardroomId = try container.decode(String.self, forKey: .boardroomId)
        userId = try container.decode(String.self, forKey: .userId)
        
        // Handle date fields which could be strings or actual dates
        if let joinedAtString = try? container.decode(String.self, forKey: .joinedAt) {
            if let date = ISO8601DateFormatter.shared.date(from: joinedAtString) {
                joinedAt = date
            } else {
                joinedAt = Date()
                print("Warning: Could not parse joinedAt date: \(joinedAtString)")
            }
        } else {
            joinedAt = try container.decode(Date.self, forKey: .joinedAt)
        }
    }
} 