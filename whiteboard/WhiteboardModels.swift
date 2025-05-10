import Foundation
import SwiftUI

// Content item that can be added to a whiteboard
public struct WhiteboardItem: Identifiable, Codable, Equatable {
    public var id: String
    public var type: ItemType
    public var content: String
    public var createdAt: Date
    public var createdBy: String
    
    // Positioning data
    public var position: CGPoint
    public var rotation: CGFloat
    public var scale: CGFloat
    
    // Metadata for synchronization
    public var lastUpdatedAt: Date
    public var lastUpdatedBy: String
    
    public enum ItemType: String, Codable {
        case text
        case image
        case drawing
    }
    
    // For positioning in the whiteboard
    public enum CodingKeys: String, CodingKey {
        case id, type, content, createdAt, createdBy
        case position, rotation, scale
        case lastUpdatedAt, lastUpdatedBy
    }
    
    public init(id: String = UUID().uuidString, 
         type: ItemType, 
         content: String, 
         createdAt: Date = Date(), 
         createdBy: String,
         position: CGPoint = CGPoint(x: 0, y: 0),
         rotation: CGFloat = 0,
         scale: CGFloat = 1.0,
         lastUpdatedAt: Date = Date(),
         lastUpdatedBy: String = "") {
        self.id = id
        self.type = type
        self.content = content
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.position = position
        self.rotation = rotation
        self.scale = scale
        self.lastUpdatedAt = lastUpdatedAt
        self.lastUpdatedBy = lastUpdatedBy ?? createdBy
    }
    
    // Equatable conformance for better comparison
    public static func == (lhs: WhiteboardItem, rhs: WhiteboardItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.type == rhs.type &&
               lhs.content == rhs.content &&
               lhs.position == rhs.position &&
               lhs.rotation == rhs.rotation &&
               lhs.scale == rhs.scale &&
               lhs.lastUpdatedAt == rhs.lastUpdatedAt
    }
}

// A model for the entire whiteboard
public struct Whiteboard: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var items: [WhiteboardItem]
    public var members: [String]
    public var createdAt: Date
    public var lastSyncedAt: Date
    
    public init(id: String = UUID().uuidString, 
         name: String, 
         items: [WhiteboardItem] = [], 
         members: [String] = [],
         createdAt: Date = Date(),
         lastSyncedAt: Date = Date()) {
        self.id = id
        self.name = name
        self.items = items
        self.members = members
        self.createdAt = createdAt
        self.lastSyncedAt = lastSyncedAt
    }
    
    // Equatable conformance
    public static func == (lhs: Whiteboard, rhs: Whiteboard) -> Bool {
        return lhs.id == rhs.id &&
               lhs.lastSyncedAt == rhs.lastSyncedAt
    }
} 
