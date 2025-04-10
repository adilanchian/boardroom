import Foundation
import SwiftUI

// Content item that can be added to a whiteboard
public struct WhiteboardItem: Identifiable, Codable {
    public var id: String
    public var type: ItemType
    public var content: String
    public var createdAt: Date
    public var createdBy: String
    public var position: CGPoint
    public var rotation: CGFloat?
    public var scale: CGFloat?
    
    public enum ItemType: String, Codable {
        case image
        case text
        case drawing
    }
    
    // For positioning in the whiteboard
    public enum CodingKeys: String, CodingKey {
        case id, type, content, createdAt, createdBy
        case position, rotation, scale
    }
    
    public init(id: String = UUID().uuidString, 
         type: ItemType, 
         content: String, 
         createdAt: Date = Date(), 
         createdBy: String,
         position: CGPoint = CGPoint(x: 0, y: 0),
         rotation: CGFloat? = nil,
         scale: CGFloat? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.createdAt = createdAt
        self.createdBy = createdBy
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
}

// A model for the entire whiteboard
public struct Whiteboard: Identifiable, Codable {
    public var id: String
    public var name: String
    public var items: [WhiteboardItem]
    public var members: [String]
    public var createdAt: Date
    
    public init(id: String = UUID().uuidString, 
         name: String, 
         items: [WhiteboardItem] = [], 
         members: [String] = [],
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.items = items
        self.members = members
        self.createdAt = createdAt
    }
} 
