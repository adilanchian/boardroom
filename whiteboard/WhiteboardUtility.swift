import Foundation

// Utility class with static methods for accessing whiteboard data
public class WhiteboardUtility {
    // The key used to store whiteboards in UserDefaults - must match what the widget uses
    public static let whiteboardsKey = "saved_whiteboards"
    
    // App Group identifier for sharing data between app and widget
    public static let appGroupIdentifier = "group.wndn.studio.whiteboard"
    
    // Get shared UserDefaults for the App Group
    public static var sharedDefaults: UserDefaults {
        return UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
    }
    
    // Get the latest whiteboard for widgets
    public static func getLatestWhiteboard() -> Whiteboard? {
        let whiteboards = loadWhiteboards()
        
        // Sort by most recently updated
        let sorted = whiteboards.sorted { board1, board2 in
            let board1LatestDate = board1.items.map { $0.createdAt }.max() ?? board1.createdAt
            let board2LatestDate = board2.items.map { $0.createdAt }.max() ?? board2.createdAt
            return board1LatestDate > board2LatestDate
        }
        
        return sorted.first
    }
    
    // Load all saved whiteboards
    public static func loadWhiteboards() -> [Whiteboard] {
        if let data = sharedDefaults.data(forKey: whiteboardsKey) {
            do {
                let decoder = JSONDecoder()
                let decoded = try decoder.decode([Whiteboard].self, from: data)
                return decoded
            } catch {
                print("Error decoding whiteboards: \(error)")
                return []
            }
        }
        return []
    }
    
    // Save whiteboards to UserDefaults
    public static func saveWhiteboards(_ whiteboards: [Whiteboard]) {
        do {
            let encoder = JSONEncoder()
            let encoded = try encoder.encode(whiteboards)
            sharedDefaults.set(encoded, forKey: whiteboardsKey)
            
            // Force sync to ensure data is written immediately
            sharedDefaults.synchronize()
        } catch {
            print("Error saving whiteboards: \(error)")
        }
    }
} 