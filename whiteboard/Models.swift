import Foundation
import SwiftUI

// Use the shared WhiteboardItem and Whiteboard models from SharedModels.swift

// Model for a user in the system
struct User: Identifiable, Codable {
    var id: String
    var name: String
    var appleIdentifier: String?
    var color: String?
    var apnsToken: String?
    var updatedAt: Date?
    
    init(id: String = UUID().uuidString, name: String, appleIdentifier: String? = nil, color: String? = nil, apnsToken: String? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.appleIdentifier = appleIdentifier
        self.color = color
        self.apnsToken = apnsToken
        self.updatedAt = updatedAt
    }
    
    // Helper to get the SwiftUI Color from the stored hex string
    func getColor() -> Color {
        guard let colorHex = color else {
            return .blue // Default color
        }
        return Color(hex: colorHex)
    }
    
    // Custom keys for profile creation API
    enum ProfileCodingKeys: String, CodingKey {
        case username = "username"
        case selectedColor = "selectedColor" 
        case apnsToken = "apnsToken"
    }
    
    // Generate a profile creation payload
    func profileCreationPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "username": name,
            "selectedColor": color ?? "#4285F4"
        ]
        
        if let token = apnsToken {
            payload["apnsToken"] = token
        }
        
        return payload
    }
} 