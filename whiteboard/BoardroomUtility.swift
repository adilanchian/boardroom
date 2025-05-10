import Foundation
import UIKit

// Utility class with static methods for accessing boardroom data
class BoardroomUtility {
    // The key used to store boardrooms in UserDefaults - must match what the widget uses
    static let boardroomsKey = "saved_boardrooms"
    
    // App Group identifier for sharing data between app and widget
    static let appGroupIdentifier = "group.wndn.studio.whiteboard"
    
    // Get shared UserDefaults for the App Group
    static var sharedDefaults: UserDefaults {
        return UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
    }
    
    // Get the latest boardroom for widgets
    static func getLatestBoardroom() -> Boardroom? {
        let boardrooms = loadBoardrooms()
        
        // Sort by most recently updated
        let sorted = boardrooms.sorted { board1, board2 in
            let board1LatestDate = board1.items.map { $0.createdAt }.max() ?? board1.createdAt
            let board2LatestDate = board2.items.map { $0.createdAt }.max() ?? board2.createdAt
            return board1LatestDate > board2LatestDate
        }
        
        return sorted.first
    }
    
    // Load all saved boardrooms
    static func loadBoardrooms() -> [Boardroom] {
        if let data = sharedDefaults.data(forKey: boardroomsKey) {
            do {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let decoded = try decoder.decode([Boardroom].self, from: data)
                
                // Debug log for loaded boardrooms
                for (boardIndex, board) in decoded.enumerated() {
                    print("📋 Loaded boardroom \(boardIndex): \(board.name) with \(board.items.count) items")
                    
                    // Check scales of items
                    for (itemIndex, item) in board.items.enumerated() {
                        print("  📦 Item \(itemIndex): id=\(item.id), type=\(item.type), scale=\(item.scale)")
                    }
                }
                
                return decoded
            } catch {
                print("Error decoding boardrooms: \(error)")
                return []
            }
        }
        return []
    }
    
    // Save boardrooms to UserDefaults
    static func saveBoardrooms(_ boardrooms: [Boardroom]) {
        // Debug log for boardrooms being saved
        for (boardIndex, board) in boardrooms.enumerated() {
            print("💾 Saving boardroom \(boardIndex): \(board.name) with \(board.items.count) items")
            
            // Check scales of items
            for (itemIndex, item) in board.items.enumerated() {
                print("  📦 Item \(itemIndex): id=\(item.id), type=\(item.type), scale=\(item.scale)")
            }
        }
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = try encoder.encode(boardrooms)
            sharedDefaults.set(encoded, forKey: boardroomsKey)
            
            // Force sync to ensure data is written immediately
            sharedDefaults.synchronize()
            print("✅ Successfully saved \(boardrooms.count) boardrooms to UserDefaults")
        } catch {
            print("❌ Error saving boardrooms: \(error)")
        }
    }
    
    // MARK: - Image Storage
    
    // Save an image to the app's documents directory
    static func saveImage(_ image: UIImage, withIdentifier identifier: String) {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Could not compress image to JPEG")
            return
        }
        
        do {
            let fileURL = getFileURL(for: identifier)
            try data.write(to: fileURL)
            print("✅ Image saved successfully: \(identifier)")
        } catch {
            print("❌ Error saving image: \(error)")
        }
    }
    
    // Get an image from the app's documents directory
    static func getImage(fromIdentifier identifier: String) -> UIImage? {
        let fileURL = getFileURL(for: identifier)
        
        do {
            let data = try Data(contentsOf: fileURL)
            return UIImage(data: data)
        } catch {
            print("❌ Error loading image \(identifier): \(error)")
            return nil
        }
    }
    
    // Delete an image from the app's documents directory
    static func deleteImage(withIdentifier identifier: String) {
        let fileURL = getFileURL(for: identifier)
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            print("✅ Image deleted successfully: \(identifier)")
        } catch {
            print("❌ Error deleting image: \(error)")
        }
    }
    
    // Helper to get the file URL for an image identifier
    private static func getFileURL(for identifier: String) -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("\(identifier).jpg")
    }
} 