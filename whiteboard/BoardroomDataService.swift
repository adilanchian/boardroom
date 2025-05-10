import Foundation
import SwiftUI
import Supabase

class BoardroomDataService {
    private let supabase = SupabaseManager.shared.client
    
    // Create a new boardroom
    func createBoardroom(name: String, createdBy: String) async throws -> Boardroom {
        let response = try await supabase
            .from("boardrooms")
            .insert([
                "name": name,
                "created_by": createdBy
            ])
            .select()
            .execute()
        
        // Data is non-optional, no need to check against nil
        let jsonData = response.data
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let boardrooms = try decoder.decode([Boardroom].self, from: jsonData)
        guard let boardroom = boardrooms.first else {
            throw NSError(domain: "BoardroomDataService", code: 404, 
                          userInfo: [NSLocalizedDescriptionKey: "No boardroom returned"])
        }
        
        // Initialize with empty items array
        var newBoardroom = boardroom
        newBoardroom.items = []
        
        // Add the creator as the first member
        _ = try await addMember(boardroomId: newBoardroom.id, userId: createdBy)
        
        return newBoardroom
    }
    
    // Get a boardroom with all its items
    func getBoardroom(id: String) async throws -> Boardroom {
        // First, get the boardroom
        let boardroomResponse = try await supabase
            .from("boardrooms")
            .select()
            .eq("id", value: id)
            .execute()
        
        // Data is non-optional, no need to check against nil
        let boardroomData = boardroomResponse.data
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let boardrooms = try decoder.decode([Boardroom].self, from: boardroomData)
        guard var boardroom = boardrooms.first else {
            throw NSError(domain: "BoardroomDataService", code: 404, 
                          userInfo: [NSLocalizedDescriptionKey: "No boardroom returned"])
        }
        
        // Then, get all items for this boardroom
        let itemsResponse = try await supabase
            .from("boardroom_items")
            .select()
            .eq("boardroom_id", value: id)
            .execute()
        
        // Data is non-optional, decode directly
        let itemsData = itemsResponse.data
        // Empty data will result in an empty array when decoded
        let items = try decoder.decode([BoardroomItem].self, from: itemsData)
        boardroom.items = items
        
        return boardroom
    }
    
    // Add or update a boardroom item
    func saveItem(item: BoardroomItem) async throws -> BoardroomItem {
        // Format date strings for JSON
        let dateFormatter = ISO8601DateFormatter()
        let createdAtStr = dateFormatter.string(from: item.createdAt)
        let updatedAtStr = dateFormatter.string(from: item.updatedAt)
        
        // We need to handle the ID separately for upsert
        var insertData: [String: Any] = [
            "boardroom_id": item.boardroomId,
            "type": item.type.rawValue,
            "content": item.content,
            "position_x": item.positionX,
            "position_y": item.positionY,
            "rotation": item.rotation,
            "scale": item.scale,
            "created_by": item.createdBy,
            "created_at": createdAtStr,
            "updated_at": updatedAtStr
        ]
        
        // Only include ID for existing items
        if !item.id.isEmpty {
            insertData["id"] = item.id
        }
        
        // For upsert, we need to handle JSON conversion ourselves
        let data = try JSONSerialization.data(withJSONObject: insertData)
        let jsonStr = String(data: data, encoding: .utf8) ?? "{}"
        
        // Use POST request to handle the upsert operation
        let response = try await supabase
            .from("boardroom_items")
            .upsert(jsonStr)
            .select()
            .execute()
        
        // Data is non-optional, decode directly
        let responseData = response.data
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let items = try decoder.decode([BoardroomItem].self, from: responseData)
        guard let savedItem = items.first else {
            throw NSError(domain: "BoardroomDataService", code: 404, 
                          userInfo: [NSLocalizedDescriptionKey: "No item returned"])
        }
        
        return savedItem
    }
    
    // Delete a boardroom item
    func deleteItem(id: String) async throws {
        try await supabase
            .from("boardroom_items")
            .delete()
            .eq("id", value: id)
            .execute()
    }
    
    // Get all boardrooms for a user
    func getBoardroomsForUser(userId: String) async throws -> [Boardroom] {
        // Use the stored function to get all boardrooms the user has access to
        let response = try await supabase
            .rpc("get_user_boardrooms", params: ["user_id_input": userId])
            .execute()
        
        // Data is non-optional, decode directly
        let data = response.data
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([Boardroom].self, from: data)
    }
    
    // Add a member to a boardroom
    func addMember(boardroomId: String, userId: String) async throws -> BoardroomMember {
        let response = try await supabase
            .from("boardroom_members")
            .insert([
                "boardroom_id": boardroomId,
                "user_id": userId
            ])
            .select()
            .execute()
        
        // Data is non-optional, decode directly
        let responseData = response.data
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let members = try decoder.decode([BoardroomMember].self, from: responseData)
        guard let member = members.first else {
            throw NSError(domain: "BoardroomDataService", code: 404, 
                          userInfo: [NSLocalizedDescriptionKey: "No member returned"])
        }
        
        return member
    }
    
    // Remove a member from a boardroom
    func removeMember(boardroomId: String, userId: String) async throws {
        try await supabase
            .from("boardroom_members")
            .delete()
            .eq("boardroom_id", value: boardroomId)
            .eq("user_id", value: userId)
            .execute()
    }
    
    // Get all members of a boardroom
    func getBoardroomMembers(boardroomId: String) async throws -> [BoardroomMember] {
        let response = try await supabase
            .from("boardroom_members")
            .select()
            .eq("boardroom_id", value: boardroomId)
            .execute()
        
        // Data is non-optional, decode directly
        let data = response.data
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode([BoardroomMember].self, from: data)
    }
} 
