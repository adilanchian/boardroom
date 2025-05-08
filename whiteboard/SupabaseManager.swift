//
//  SupabaseManager.swift
//  whiteboard
//
//  Created by alec on 4/18/25.
//

import Foundation
import Supabase

// Define the Group model
struct Group: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let createdBy: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdBy = "created_by"
        case createdAt = "created_at"
    }
    
    static func == (lhs: Group, rhs: Group) -> Bool {
        return lhs.id == rhs.id
    }
}

// Custom errors for better error handling
enum SupabaseError: Error {
    case invalidResponse
    case functionError(statusCode: Int, message: String)
    case networkError(Error)
    case decodingError(Error)
    case invalidUserData
    case profileNotFound
    
    var localizedDescription: String {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .functionError(let statusCode, let message):
            return "Server error (code: \(statusCode)): \(message)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to process server data: \(error.localizedDescription)"
        case .invalidUserData:
            return "Invalid user data provided"
        case .profileNotFound:
            return "User profile not found"
        }
    }
}

// Define a GroupMember model
struct GroupMember: Identifiable, Codable {
    let userId: String
    let groupId: String
    let joinedAt: String
    
    // Since we use a composite primary key, we need a computed id
    var id: String {
        return "\(groupId)_\(userId)"
    }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case groupId = "group_id"
        case joinedAt = "joined_at"
    }
}

class SupabaseManager {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    private init() {
        // FIXME: - make sure to add diff env stuff.
        client = SupabaseClient(
            supabaseURL: URL(string: "http://127.0.0.1:54321")!,
            supabaseKey: ""
        )
    }
    
    // Create user profile using the Supabase function
    func createUserProfile(user: User) async throws -> Any {
        // Validate input
        guard !user.name.isEmpty else {
            throw SupabaseError.invalidUserData
        }
        
        do {
            // Use the new direct database method instead of edge function
            let profile = try await createUserProfile(
                username: user.name,
                selectedColor: user.color ?? "#4285F4", // Default blue if no color set
                apnsToken: user.apnsToken
            )
            
            print("Profile created for: \(profile.username)")
            return profile
        } catch {
            // Log error and rethrow
            print("Error creating user profile: \(error.localizedDescription)")
            throw error
        }
    }
    
    // Helper to extract error message from JSON data
    private func extractErrorMessage(from data: Data?) -> String? {
        guard let data = data else { return nil }
        
        do {
            // Try to parse as JSON
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // Look for common error message fields
                if let message = json["message"] as? String {
                    return message
                } else if let error = json["error"] as? String {
                    return error
                } else if let error = json["error"] as? [String: Any], let message = error["message"] as? String {
                    return message
                }
            }
            
            // If we can't parse as JSON, try to convert to string
            return String(data: data, encoding: .utf8)
        } catch {
            // Return raw data as string if JSON parsing fails
            return String(data: data, encoding: .utf8)
        }
    }
    
    // Fetch the latest user profile data from Supabase using JWT auth
    func fetchUserProfile() async throws -> User {
        // Log for debugging
        print("Fetching user profile using direct database access")
        
        do {
            // First, get the session to ensure we have a fallback for user data
            let session = try await client.auth.session
            let userId = session.user.id.uuidString
            let userEmail = session.user.email
            let userPhone = session.user.phone
            
            // Default display name from session
            let displayName = userEmail ?? userPhone ?? "User"
            
            // Fetch profile directly from the database
            do {
                let profile = try await getUserProfile()
                
                print("Successfully retrieved profile for: \(profile.username)")
                
                // Map the profile to our User model
                return User(
                    id: profile.id,
                    name: profile.username,
                    color: profile.selectedColor
                )
            } catch SupabaseError.profileNotFound {
                print("Profile not found in database - user needs to complete onboarding")
                throw SupabaseError.profileNotFound
            } catch {
                print("Database query failed: \(error.localizedDescription)")
                
                // Fall back to session data if database query fails
                print("Using session data to create basic user profile")
                return User(id: userId, name: displayName)
            }
        } catch {
            // Extract error information
            let nsError = error as NSError
            
            // Log detailed error info for debugging
            print("Error fetching profile: \(error)")
            print("Error domain: \(nsError.domain), code: \(nsError.code)")
            
            // Add user info details for more context
            if let userInfo = nsError.userInfo as? [String: Any], !userInfo.isEmpty {
                print("Error user info: \(userInfo)")
            }
            
            throw SupabaseError.networkError(error)
        }
    }
    
    /// Create a new group and automatically add the current user as a member
    /// - Parameter name: The name of the group to create
    /// - Returns: The newly created group
    func createGroup(name: String) async throws -> Group {
        print("Creating group with name: \(name)")
        
        // Validate input
        guard !name.isEmpty else {
            throw SupabaseError.invalidUserData
        }
        
        do {
            // Ensure we have an authenticated session
            let session = try await client.auth.session
            let userId = session.user.id.uuidString
            
            // 1. Insert the group
            let newGroup: Group = try await client.database
                .from("groups")
                .insert([
                    "name": name,
                    "created_by": userId
                ])
                .select("id, name, created_by, created_at")
                .single()
                .execute()
                .value
            
            print("Group created successfully: \(newGroup.name) (ID: \(newGroup.id))")
            
            // 2. Add creator as a member
            try await client.database
                .from("group_members")
                .insert([
                    "group_id": newGroup.id,
                    "user_id": userId
                ])
                .execute()
            
            print("Added creator as member to the group")
            
            return newGroup
            
        } catch let error as PostgrestError {
            // Handle specific database errors
            print("Database error creating group: \(error.message)")
            
            if error.message.contains("permission denied") {
                throw SupabaseError.functionError(statusCode: 403, message: "Not authorized to create groups")
            }
            
            throw SupabaseError.networkError(error)
        } catch {
            print("Error creating group: \(error.localizedDescription)")
            throw SupabaseError.networkError(error)
        }
    }
    
    // Function to check if the current user has created any groups
    func checkUserGroups() async throws -> [String] {
        print("Checking if user has created any groups")
        
        do {
            // Get the current user's ID
            let session = try await client.auth.session
            let userId = session.user.id.uuidString
            
            // Query groups created by this user
            let createdGroups: [Group] = try await client.database
                .from("groups")
                .select("id, name")
                .eq("created_by", value: userId)
                .execute()
                .value
            
            let groupIds = createdGroups.map { $0.id }
            print("User has created \(groupIds.count) groups")
            return groupIds
            
        } catch {
            print("Error checking user groups: \(error.localizedDescription)")
            throw SupabaseError.networkError(error)
        }
    }
    
    /// Fetch groups created by the current user
    /// - Returns: Array of groups created by the user
    func getUserGroups() async throws -> [Group] {
        print("Fetching groups created by user")
        
        do {
            // Get the current user's ID
            let session = try await client.auth.session
            let userId = session.user.id.uuidString
            
            // Query groups created by this user
            let createdGroups: [Group] = try await client.database
                .from("groups")
                .select("id, name, created_by, created_at")
                .eq("created_by", value: userId)
                .execute()
                .value
            
            print("Found \(createdGroups.count) groups created by user")
            return createdGroups
            
        } catch {
            print("Error fetching groups: \(error.localizedDescription)")
            throw SupabaseError.networkError(error)
        }
    }
    
    // MARK: - Group Membership Management
    
    /// Add a user as a member to a group
    /// - Parameters:
    ///   - groupId: The ID of the group to add the member to
    ///   - userId: The ID of the user to add as a member
    /// - Returns: Boolean indicating success
    func addMemberToGroup(groupId: String, userId: String) async throws -> Bool {
        print("Adding user \(userId) to group \(groupId)")
        
        do {
            // Ensure we have an authenticated session
            let session = try await client.auth.session
            
            // No need to verify if current user is creator - RLS policy handles that
            
            // Insert the new member
            try await client.database
                .from("group_members")
                .insert([
                    "group_id": groupId,
                    "user_id": userId
                ])
                .execute()
            
            print("Successfully added user to group")
            return true
            
        } catch let error as PostgrestError {
            // Handle specific database errors
            print("Database error adding member: \(error.message)")
            
            // Check for common errors
            if error.message.contains("duplicate key") {
                print("User is already a member of this group")
                throw SupabaseError.functionError(statusCode: 409, message: "User is already a member of this group")
            } else if error.message.contains("foreign key constraint") {
                print("Group or user does not exist")
                throw SupabaseError.functionError(statusCode: 404, message: "Group or user not found")
            } else if error.message.contains("permission denied") {
                print("Not authorized to add members to this group")
                throw SupabaseError.functionError(statusCode: 403, message: "Not authorized to add members to this group")
            }
            
            throw SupabaseError.networkError(error)
        } catch {
            print("Error adding member to group: \(error.localizedDescription)")
            throw SupabaseError.networkError(error)
        }
    }

    /// Remove a user from a group
    /// - Parameters:
    ///   - groupId: The ID of the group
    ///   - userId: The ID of the user to remove
    /// - Returns: Boolean indicating success
    func removeMemberFromGroup(groupId: String, userId: String) async throws -> Bool {
        print("Removing user \(userId) from group \(groupId)")
        
        do {
            // Ensure we have an authenticated session
            let session = try await client.auth.session
            
            // No need to verify if current user is creator - RLS policy handles that
            
            // Delete the member record
            try await client.database
                .from("group_members")
                .delete()
                .eq("group_id", value: groupId)
                .eq("user_id", value: userId)
                .execute()
            
            print("Successfully removed user from group")
            return true
            
        } catch let error as PostgrestError {
            // Handle specific database errors
            print("Database error removing member: \(error.message)")
            
            // Check for common errors
            if error.message.contains("not found") {
                print("User is not a member of this group")
                throw SupabaseError.functionError(statusCode: 404, message: "User is not a member of this group")
            } else if error.message.contains("permission denied") {
                print("Not authorized to remove members from this group")
                throw SupabaseError.functionError(statusCode: 403, message: "Not authorized to remove members from this group")
            }
            
            throw SupabaseError.networkError(error)
        } catch {
            print("Error removing member from group: \(error.localizedDescription)")
            throw SupabaseError.networkError(error)
        }
    }

    /// Get all members of a group
    /// - Parameter groupId: The ID of the group
    /// - Returns: Array of group members
    func getGroupMembers(groupId: String) async throws -> [GroupMember] {
        print("Fetching members for group \(groupId)")
        
        do {
            // Ensure we have an authenticated session
            let session = try await client.auth.session
            
            // Query members of the group
            let members: [GroupMember] = try await client.database
                .from("group_members")
                .select("user_id, group_id, joined_at")
                .eq("group_id", value: groupId)
                .execute()
                .value
            
            print("Found \(members.count) members for group \(groupId)")
            return members
            
        } catch let error as PostgrestError {
            // Handle specific database errors
            print("Database error fetching group members: \(error.message)")
            
            if error.message.contains("permission denied") {
                print("Not authorized to view members of this group")
                throw SupabaseError.functionError(statusCode: 403, message: "Not authorized to view members of this group")
            }
            
            throw SupabaseError.networkError(error)
        } catch {
            print("Error fetching group members: \(error.localizedDescription)")
            throw SupabaseError.networkError(error)
        }
    }

    /// Look up a user by their email
    /// - Parameter email: The email to look up
    /// - Returns: The user ID if found, nil if not found
    func getUserIdByEmail(_ email: String) async throws -> String? {
        print("Looking up user ID for email: \(email)")
        
        do {
            // Ensure we have an authenticated session
            _ = try await client.auth.session
            
            // Query profiles by email
            // Note: This assumes you have an 'email' column in your profiles table
            // If you don't, you'll need to adjust this query or create the column
            struct UserProfile: Decodable {
                let id: String
                let email: String?
                
                enum CodingKeys: String, CodingKey {
                    case id
                    case email
                }
            }
            
            // Try to find the user by their email in the profiles table
            let profiles: [UserProfile] = try await client.database
                .from("profiles")
                .select("id, email")
                .eq("email", value: email)
                .execute()
                .value
            
            if let profile = profiles.first {
                print("User found with ID: \(profile.id) for email: \(email)")
                return profile.id
            }
            
            // If not found in profiles, check auth.users directly (requires admin privileges)
            // This is just a fallback and might not work depending on your permissions
            print("User not found in profiles table, email may not be stored there")
            return nil
            
        } catch {
            print("Error looking up user by email: \(error.localizedDescription)")
            // Return nil instead of throwing, as user not found is an expected case
            return nil
        }
    }
    
    // MARK: - Profile Management
    
    // Define a Profile model
    struct Profile: Identifiable, Codable {
        let id: String
        let username: String
        let selectedColor: String
        let updatedAt: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case username
            case selectedColor = "selected_color"
            case updatedAt = "updated_at"
        }
    }

    /// Get a user's profile directly from the database
    /// - Parameter userId: Optional user ID. If nil, gets the current user's profile
    /// - Returns: The user's profile data
    func getUserProfile(userId: String? = nil) async throws -> Profile {
        print("Fetching user profile")
        
        do {
            // Ensure we have an authenticated session and resolve the userId
            let session = try await client.auth.session
            let targetUserId = userId ?? session.user.id.uuidString
            
            // Query the profile from the database
            let profile: Profile = try await client.database
                .from("profiles")
                .select("id, username, selected_color, updated_at")
                .eq("id", value: targetUserId)
                .single()
                .execute()
                .value
            
            print("Successfully retrieved profile for: \(profile.username)")
            return profile
            
        } catch let error as PostgrestError {
            // Handle specific database errors
            print("Database error fetching profile: \(error.message)")
            
            // Check if this is a "not found" error
            if error.message.contains("not found") || error.code == "PGRST116" {
                print("Profile not found - user needs to complete onboarding")
                throw SupabaseError.profileNotFound
            }
            
            if error.message.contains("permission denied") {
                throw SupabaseError.functionError(statusCode: 403, message: "Not authorized to view this profile")
            }
            
            throw SupabaseError.networkError(error)
        } catch {
            print("Error fetching profile: \(error.localizedDescription)")
            throw SupabaseError.networkError(error)
        }
    }

    /// Create or update a user profile
    /// - Parameters:
    ///   - username: The username to set for the profile
    ///   - selectedColor: The color preference for the user
    ///   - apnsToken: Optional push notification token
    /// - Returns: The created profile
    func createUserProfile(username: String, selectedColor: String, apnsToken: String? = nil) async throws -> Profile {
        print("Creating profile with username: \(username)")
        
        // Validate input
        guard !username.isEmpty else {
            throw SupabaseError.invalidUserData
        }
        
        guard !selectedColor.isEmpty else {
            throw SupabaseError.invalidUserData
        }
        
        do {
            // Ensure we have an authenticated session
            let session = try await client.auth.session
            let userId = session.user.id.uuidString
            
            // Insert the profile
            let profile: Profile = try await client.database
                .from("profiles")
                .insert([
                    "id": userId,
                    "username": username,
                    "selected_color": selectedColor,
                    "apns_token": apnsToken
                ])
                .select("id, username, selected_color, updated_at")
                .single()
                .execute()
                .value
            
            print("Profile created successfully for user: \(profile.username)")
            return profile
            
        } catch let error as PostgrestError {
            // Handle specific database errors
            print("Database error creating profile: \(error.message)")
            
            // Check for unique constraint violations (username already taken)
            if error.code == "23505" && error.message.contains("username") {
                print("Username already taken")
                throw SupabaseError.functionError(statusCode: 409, message: "Username already taken")
            }
            
            if error.message.contains("permission denied") {
                throw SupabaseError.functionError(statusCode: 403, message: "Not authorized to create profile")
            }
            
            throw SupabaseError.networkError(error)
        } catch {
            print("Error creating profile: \(error.localizedDescription)")
            throw SupabaseError.networkError(error)
        }
    }

    /// Fetch another user's profile by their ID
    /// - Parameter userId: The ID of the user to fetch
    /// - Returns: User model with the profile data
    func fetchOtherUserProfile(userId: String) async throws -> User {
        print("Fetching profile for user: \(userId)")
        
        do {
            // Fetch directly from database
            let profile = try await getUserProfile(userId: userId)
            
            print("Successfully fetched profile for: \(profile.username)")
            
            return User(
                id: profile.id,
                name: profile.username,
                color: profile.selectedColor
            )
        } catch SupabaseError.profileNotFound {
            print("Profile not found for user ID: \(userId)")
            throw SupabaseError.profileNotFound
        } catch {
            print("Error fetching other user profile: \(error.localizedDescription)")
            
            // If permissions error or other db issue, return a placeholder user
            return User(id: userId, name: "Unknown User")
        }
    }
}
