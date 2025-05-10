import Foundation
import SwiftUI
import Combine

class BoardroomViewModel: ObservableObject {
    @Published var boardroom: Boardroom?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let dataService = BoardroomDataService()
    private var supabaseManager = SupabaseManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Current user info (would be retrieved from your user management)
    private var currentUserId: String {
        UserManager.shared.currentUser?.id ?? UUID().uuidString
    }
    
    // MARK: - Public Methods
    
    /// Load an existing boardroom or create a new one
    func loadBoardroom(id: String) {
        isLoading = true
        
        Task {
            do {
                let loadedBoardroom = try await dataService.getBoardroom(id: id)
                await MainActor.run {
                    self.boardroom = loadedBoardroom
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load boardroom: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Create a new boardroom with the current user as creator
    func createBoardroom(name: String) {
        isLoading = true
        
        Task {
            do {
                let newBoardroom = try await dataService.createBoardroom(
                    name: name,
                    createdBy: currentUserId
                )
                await MainActor.run {
                    self.boardroom = newBoardroom
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to create boardroom: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    /// Load a user's boardrooms (both created and member of)
    func loadUserBoardrooms(completion: @escaping ([Boardroom]) -> Void) {
        Task {
            do {
                let boardrooms = try await dataService.getBoardroomsForUser(userId: currentUserId)
                await MainActor.run {
                    completion(boardrooms)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load boardrooms: \(error.localizedDescription)"
                    completion([])
                }
            }
        }
    }
    
    /// Add a member to the current boardroom
    func addMember(userId: String) {
        guard let boardroom = boardroom else { return }
        
        Task {
            do {
                _ = try await dataService.addMember(boardroomId: boardroom.id, userId: userId)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to add member: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Remove a member from the current boardroom
    func removeMember(userId: String) {
        guard let boardroom = boardroom else { return }
        
        Task {
            do {
                try await dataService.removeMember(boardroomId: boardroom.id, userId: userId)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to remove member: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Get all members of the current boardroom
    func getBoardroomMembers(completion: @escaping ([BoardroomMember]) -> Void) {
        guard let boardroom = boardroom else {
            completion([])
            return
        }
        
        Task {
            do {
                let members = try await dataService.getBoardroomMembers(boardroomId: boardroom.id)
                await MainActor.run {
                    completion(members)
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to get members: \(error.localizedDescription)"
                    completion([])
                }
            }
        }
    }
    
    /// Add a text item to the boardroom
    func addTextItem(text: String, position: CGPoint) {
        guard let boardroom = boardroom else { return }
        
        // Create the new item
        let newItem = BoardroomItem(
            boardroomId: boardroom.id,
            type: .text,
            content: text,
            position: position,
            createdBy: currentUserId
        )
        
        // Optimistically update the UI
        var updatedItems = boardroom.items
        updatedItems.append(newItem)
        
        self.boardroom?.items = updatedItems
        
        // Save to the server
        Task {
            do {
                let savedItem = try await dataService.saveItem(item: newItem)
                
                // Update the item with the server values
                await MainActor.run {
                    if let index = self.boardroom?.items.firstIndex(where: { $0.id == newItem.id }) {
                        self.boardroom?.items[index] = savedItem
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save item: \(error.localizedDescription)"
                    // Remove the item if save failed
                    self.boardroom?.items.removeAll(where: { $0.id == newItem.id })
                }
            }
        }
    }
    
    /// Update an item's position
    func updateItemPosition(id: String, position: CGPoint) {
        guard let boardroom = boardroom,
              let index = boardroom.items.firstIndex(where: { $0.id == id }) else { return }
        
        // Create a copy of the item with updated position
        var updatedItem = boardroom.items[index]
        updatedItem.position = position
        updatedItem.updatedAt = Date()
        
        // Update the local state
        self.boardroom?.items[index] = updatedItem
        
        // Save to the server
        Task {
            do {
                _ = try await dataService.saveItem(item: updatedItem)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update item position: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Update an item's rotation
    func updateItemRotation(id: String, rotation: Double) {
        guard let boardroom = boardroom,
              let index = boardroom.items.firstIndex(where: { $0.id == id }) else { return }
        
        // Create a copy of the item with updated rotation
        var updatedItem = boardroom.items[index]
        updatedItem.rotation = rotation
        updatedItem.updatedAt = Date()
        
        // Update the local state
        self.boardroom?.items[index] = updatedItem
        
        // Save to the server
        Task {
            do {
                _ = try await dataService.saveItem(item: updatedItem)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update item rotation: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Update an item's scale
    func updateItemScale(id: String, scale: Double) {
        guard let boardroom = boardroom,
              let index = boardroom.items.firstIndex(where: { $0.id == id }) else { return }
        
        // Create a copy of the item with updated scale
        var updatedItem = boardroom.items[index]
        updatedItem.scale = scale
        updatedItem.updatedAt = Date()
        
        // Update the local state
        self.boardroom?.items[index] = updatedItem
        
        // Save to the server
        Task {
            do {
                _ = try await dataService.saveItem(item: updatedItem)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to update item scale: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Delete an item
    func deleteItem(id: String) {
        guard let boardroom = boardroom else { return }
        
        // Optimistically remove from UI
        let updatedItems = boardroom.items.filter { $0.id != id }
        self.boardroom?.items = updatedItems
        
        // Delete from server
        Task {
            do {
                try await dataService.deleteItem(id: id)
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to delete item: \(error.localizedDescription)"
                    // Refresh the boardroom data if delete failed
                    self.refreshBoardroom()
                }
            }
        }
    }
    
    /// Save the entire boardroom (useful when navigating away)
    func saveBoardroom() {
        // For now, individual items are already saved when modified
        // This is a placeholder for any additional save operations
        // In the future, this could save batch changes or metadata
    }
    
    // MARK: - Private Methods
    
    private func refreshBoardroom() {
        guard let boardroom = boardroom else { return }
        
        Task {
            do {
                let refreshedBoardroom = try await dataService.getBoardroom(id: boardroom.id)
                await MainActor.run {
                    self.boardroom = refreshedBoardroom
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to refresh boardroom: \(error.localizedDescription)"
                }
            }
        }
    }
} 