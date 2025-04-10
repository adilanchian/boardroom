import Foundation
import SwiftUI

// Use the shared WhiteboardItem and Whiteboard models from SharedModels.swift

// Model for a user in the system
struct User: Identifiable, Codable {
    var id: String
    var name: String
    var appleIdentifier: String?
    
    init(id: String = UUID().uuidString, name: String, appleIdentifier: String? = nil) {
        self.id = id
        self.name = name
        self.appleIdentifier = appleIdentifier
    }
} 