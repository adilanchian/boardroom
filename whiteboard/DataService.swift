import Foundation
import SwiftUI
import WidgetKit

class DataService: ObservableObject {
    @Published var currentUser: User? = User(id: "u1", name: "You")
    @Published var boardrooms: [Boardroom] = []
    @Published var onboardingComplete: Bool = false
    
    private let userDefaultsKey = "boardroom_user"
    private let onboardingCompleteKey = "onboarding_complete"
    
    init() {
        loadOnboardingStatus()
        loadUser()
        loadBoardrooms()
    }
    
    // MARK: - User Management
    
    func loadOnboardingStatus() {
        onboardingComplete = UserDefaults.standard.bool(forKey: onboardingCompleteKey)
    }
    
    func completeOnboarding() {
        onboardingComplete = true
        UserDefaults.standard.set(true, forKey: onboardingCompleteKey)
    }
    
    func loadUser() {
        if let userData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            self.currentUser = user
        }
    }
    
    func saveUser(_ user: User, completeSetup: Bool = false) {
        self.currentUser = user
        
        // Only save to UserDefaults if we're completing setup or user was already saved
        if completeSetup || UserDefaults.standard.data(forKey: userDefaultsKey) != nil {
            if let encoded = try? JSONEncoder().encode(user) {
                UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
            }
            
            // If we're completing setup, mark onboarding as complete
            if completeSetup {
                completeOnboarding()
            }
            
            // Post notification that user has changed
            NotificationCenter.default.post(name: NSNotification.Name("UserChanged"), object: user)
        }
    }
    
    func signOut() {
        currentUser = nil
        onboardingComplete = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: onboardingCompleteKey)
    }
    
    // MARK: - Boardroom Management
    
    func loadBoardrooms() {
        boardrooms = BoardroomUtility.loadBoardrooms()
    }
    
    // Sync boardrooms from Supabase to local storage
    func syncBoardroomsFromSupabase() async {
        guard let currentUser = currentUser else { return }
        
        do {
            // Fetch boardrooms from Supabase
            let supabaseBoardrooms = try await SupabaseManager.shared.getUserBoardrooms()
            print("Syncing \(supabaseBoardrooms.count) boardrooms from Supabase")
            
            // Keep track of which Supabase boardrooms we've processed
            var processedIds = Set<String>()
            var updatedBoardrooms = [Boardroom]()
            
            // First, make a copy of the current boardrooms
            await MainActor.run {
                updatedBoardrooms = self.boardrooms
            }
            
            // Update existing boardrooms and add new ones
            for boardroom in supabaseBoardrooms {
                processedIds.insert(boardroom.id)
                
                // Check if this boardroom already exists locally
                if let index = updatedBoardrooms.firstIndex(where: { $0.id == boardroom.id }) {
                    // Update existing boardroom but keep its items
                    var updatedBoardroom = boardroom
                    updatedBoardroom.items = updatedBoardrooms[index].items
                    updatedBoardrooms[index] = updatedBoardroom
                } else {
                    // Add new boardroom
                    updatedBoardrooms.append(boardroom)
                }
            }
            
            // Update the published property on the main thread
            await MainActor.run {
                self.boardrooms = updatedBoardrooms
                // Save updated boardrooms to local storage
                self.saveBoardrooms()
            }
            
        } catch {
            print("Error syncing boardrooms from Supabase: \(error.localizedDescription)")
        }
    }
    
    func saveBoardrooms() {
        BoardroomUtility.saveBoardrooms(boardrooms)
        
        // Update widgets when boardrooms change
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    func createBoardroom(name: String) -> Boardroom {
        guard let currentUser = currentUser else {
            fatalError("Cannot create boardroom without a logged in user")
        }
        
        let newBoard = Boardroom(
            name: name,
            items: [],
            createdBy: currentUser.id
        )
        
        boardrooms.append(newBoard)
        saveBoardrooms()
        return newBoard
    }
    
    func updateBoardroom(_ boardroom: Boardroom) {
        assert(Thread.isMainThread, "updateBoardroom must be called from the main thread")
        
        if let index = boardrooms.firstIndex(where: { $0.id == boardroom.id }) {
            boardrooms[index] = boardroom
            
            // Move this boardroom to the front of the array so it appears in the widget
            if index != 0 {
                let updatedBoard = boardrooms.remove(at: index)
                boardrooms.insert(updatedBoard, at: 0)
            }
        } else {
            // If not found, add it at the beginning
            boardrooms.insert(boardroom, at: 0)
        }
        saveBoardrooms()
    }
    
    func addItemToBoardroom(boardroomId: String, item: BoardroomItem) {
        if let index = boardrooms.firstIndex(where: { $0.id == boardroomId }) {
            boardrooms[index].items.append(item)
            saveBoardrooms()
        }
    }
    
    // Get a boardroom by its ID
    func getBoardroom(id: String) -> Boardroom? {
        return boardrooms.first(where: { $0.id == id })
    }
    
    // Get all boardrooms
    func getAllBoardrooms() -> [Boardroom] {
        return boardrooms
    }
    
    // Get a boardroom by its ID
    func getBoardroomForBoardroom(_ id: String) -> Boardroom? {
        return getBoardroom(id: id)
    }
    
    // MARK: - Backend Integration (placeholders for future implementation)
    
    func syncWithBackend() {
        // This would connect to your backend service
        // For now, we'll just work with local data
    }
    
    func fetchBoardroomsFromBackend(completion: @escaping ([Boardroom]?) -> Void) {
        // This would fetch boardrooms from your backend
        // For the prototype, just return local data
        completion(boardrooms)
    }
    
    func uploadBoardroomToBackend(_ boardroom: Boardroom, completion: @escaping (Bool) -> Void) {
        // This would upload changes to your backend
        // For the prototype, just save locally
        updateBoardroom(boardroom)
        completion(true)
    }
    
    // Update widgets
    func updateWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // Save a boardroom (updates existing or adds new)
    func saveBoardroom(_ boardroom: Boardroom) {
        // Make sure we're on the main thread when updating published properties
        if Thread.isMainThread {
            updateBoardroom(boardroom)
        } else {
            // Dispatch to the main thread if we're not already there
            DispatchQueue.main.async {
                self.updateBoardroom(boardroom)
            }
        }
    }
} 

