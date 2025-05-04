//
//  SupabaseManager.swift
//  whiteboard
//
//  Created by alec on 4/18/25.
//

import Foundation
import Supabase

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
        
        // Create a properly encodable payload
        struct ProfilePayload: Encodable {
            let username: String
            let selectedColor: String
            let apnsToken: String?
        }
        
        // Create the payload from the user model
        let payload = ProfilePayload(
            username: user.name,
            selectedColor: user.color ?? "#4285F4", // Default blue if no color set
            apnsToken: user.apnsToken
        )
        
        // Log for debugging
        print("Creating user profile for: \(user.name)")
        
        do {
            // Call the Supabase function
            let response: () = try await client.functions
                .invoke(
                    "create-profile",
                    options: FunctionInvokeOptions(
                        body: payload
                    )
                )
            
            print("Response received: \(response)")
            return response
        } catch {
            // Extract error information
            let nsError = error as NSError
            
            // Log detailed error info for debugging
            print("Error creating profile: \(error)")
            print("Error domain: \(nsError.domain), code: \(nsError.code)")
            
            // Check if it's an HTTP error
            if nsError.domain.contains("HTTP") || nsError.domain.contains("Network") {
                // Try to extract status code
                let statusCode = nsError.code
                
                // Try to extract error message from user info
                var errorMessage = "Unknown server error"
                
                if let data = nsError.userInfo["data"] as? Data {
                    errorMessage = extractErrorMessage(from: data) ?? errorMessage
                } else if let responseString = nsError.userInfo["responseString"] as? String,
                          let data = responseString.data(using: .utf8) {
                    errorMessage = extractErrorMessage(from: data) ?? errorMessage
                } else if let localizedDescription = nsError.userInfo[NSLocalizedDescriptionKey] as? String {
                    errorMessage = localizedDescription
                }
                
                throw SupabaseError.functionError(statusCode: statusCode, message: errorMessage)
            } else if nsError.domain == "NSCocoaErrorDomain" {
                // Likely a decoding or parsing error
                throw SupabaseError.decodingError(error)
            } else {
                // General network or other error
                throw SupabaseError.networkError(error)
            }
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
        // Create a struct to decode the profile response
        struct ProfileResponse: Decodable {
            let id: String
            let username: String
            let selectedColor: String?
            let updatedAt: String?
            
            // Add CodingKeys to map snake_case from API to camelCase in Swift
            enum CodingKeys: String, CodingKey {
                case id
                case username
                case selectedColor = "selected_color"
                case updatedAt = "updated_at"
            }
        }
        
        // Log for debugging
        print("Fetching user profile using JWT authentication")
        
        do {
            // First, get the session to ensure we have a fallback for user data
            let session = try await client.auth.session
            let userId = session.user.id.uuidString
            let userEmail = session.user.email
            let userPhone = session.user.phone
            
            // Default display name from session
            let displayName = userEmail ?? userPhone ?? "User"
            
            // Call the Supabase function with direct type decoding
            do {
                let profile: ProfileResponse = try await client.functions
                    .invoke(
                        "get-profile",
                        options: FunctionInvokeOptions(
                            headers: [
                                "Content-Type": "application/json",
                                "Accept": "application/json"
                            ]
                        )
                    )
                
                print("Successfully retrieved profile for: \(profile.username)")
                
                // Map the profile response to our User model
                return User(
                    id: profile.id,
                    name: profile.username,
                    color: profile.selectedColor
                )
            } catch {
                print("Function call failed: \(error.localizedDescription)")
                
                // Try to fetch profile directly from the database as an alternative
                do {
                    // Define a decodable model for the profile table
                    struct ProfileRecord: Decodable {
                        let id: String
                        let username: String
                        let selectedColor: String?
                        
                        enum CodingKeys: String, CodingKey {
                            case id
                            case username
                            case selectedColor = "selected_color"
                        }
                    }
                    
                    // Make a direct database query as fallback
                    let profileData: ProfileRecord = try await client.database
                        .from("profiles")
                        .select()
                        .eq("id", value: userId)
                        .single()
                        .execute()
                        .value
                    
                    print("Database profile query successful for: \(profileData.username)")
                    return User(id: profileData.id, 
                                name: profileData.username, 
                                color: profileData.selectedColor)
                } catch let dbError as PostgrestError {
                    // Check if this is a "not found" error from the database
                    if dbError.message.contains("not found") || dbError.code == "PGRST116" {
                        print("Profile not found in database - user needs to complete onboarding")
                        throw SupabaseError.profileNotFound
                    }
                    
                    print("Direct database query failed: \(dbError)")
                    
                    // Fall back to session data if database query fails for other reasons
                    print("Using session data to create user profile")
                    return User(id: userId, name: displayName)
                } catch {
                    print("Direct database query failed: \(error)")
                    
                    // Fall back to session data if database query fails
                    print("Using session data to create user profile")
                    return User(id: userId, name: displayName)
                }
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
}
