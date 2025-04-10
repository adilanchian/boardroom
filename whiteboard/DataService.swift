import Foundation
import SwiftUI
import WidgetKit

class DataService: ObservableObject {
    @Published var currentUser: User? = User(id: "u1", name: "You")
    @Published var whiteboards: [Whiteboard] = []
    
    private let userDefaultsKey = "whiteboard_user"
    
    init() {
        loadUser()
        loadWhiteboards()
    }
    
    // MARK: - User Management
    
    func loadUser() {
        if let userData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
        }
    }
    
    func saveUser(_ user: User) {
        self.currentUser = user
        if let encoded = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
    
    func signInWithApple(appleIdentifier: String, name: String) {
        let user = User(name: name, appleIdentifier: appleIdentifier)
        saveUser(user)
    }
    
    func signOut() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    // MARK: - Whiteboard Management
    
    func loadWhiteboards() {
        whiteboards = WhiteboardUtility.loadWhiteboards()
        
        // If no whiteboards, create a sample one
        if whiteboards.isEmpty {
            let sampleBoard = Whiteboard(
                name: "Sample Board",
                items: [
                    WhiteboardItem(
                        type: .text,
                        content: "Welcome to your whiteboard!",
                        createdBy: "System",
                        position: CGPoint(x: 180, y: 180)
                    )
                ]
            )
            whiteboards.append(sampleBoard)
            saveWhiteboards()
        }
    }
    
    func saveWhiteboards() {
        WhiteboardUtility.saveWhiteboards(whiteboards)
        
        // Update widgets when whiteboards change
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func createWhiteboard(name: String) -> Whiteboard {
        guard let currentUser = currentUser else {
            fatalError("Cannot create whiteboard without a logged in user")
        }
        
        let newBoard = Whiteboard(
            name: name,
            items: [],
            members: [currentUser.id]
        )
        
        whiteboards.append(newBoard)
        saveWhiteboards()
        return newBoard
    }
    
    func updateWhiteboard(_ whiteboard: Whiteboard) {
        if let index = whiteboards.firstIndex(where: { $0.id == whiteboard.id }) {
            whiteboards[index] = whiteboard
            
            // Move this whiteboard to the front of the array so it appears in the widget
            if index != 0 {
                let updatedBoard = whiteboards.remove(at: index)
                whiteboards.insert(updatedBoard, at: 0)
            }
        } else {
            // If not found, add it at the beginning
            whiteboards.insert(whiteboard, at: 0)
        }
        saveWhiteboards()
    }
    
    func addItemToWhiteboard(whiteboardId: String, item: WhiteboardItem) {
        if let index = whiteboards.firstIndex(where: { $0.id == whiteboardId }) {
            whiteboards[index].items.append(item)
            saveWhiteboards()
        }
    }
    
    // MARK: - Backend Integration (placeholders for future implementation)
    
    func syncWithBackend() {
        // This would connect to your backend service
        // For now, we'll just work with local data
    }
    
    func fetchWhiteboardsFromBackend(completion: @escaping ([Whiteboard]?) -> Void) {
        // This would fetch whiteboards from your backend
        // For the prototype, just return local data
        completion(whiteboards)
    }
    
    func uploadWhiteboardToBackend(_ whiteboard: Whiteboard, completion: @escaping (Bool) -> Void) {
        // This would upload changes to your backend
        // For the prototype, just save locally
        updateWhiteboard(whiteboard)
        completion(true)
    }
} 