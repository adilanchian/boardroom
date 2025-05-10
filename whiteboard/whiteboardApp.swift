//
//  boardroomApp.swift
//  boardroom
//
//  Created by alec on 3/26/25.
//

import SwiftUI
import UIKit

// Add photo library usage permission to Info.plist
// IMPORTANT: Add this key to your project settings:
// - NSPhotoLibraryUsageDescription: "Allow access to add photos to your boardroom"

@main
struct boardroomApp: App {
    @StateObject private var dataService = DataService()
    @State private var isCheckingSession = true
    
    init() {
        // Force light mode for the entire app
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        windowScene?.windows.forEach { window in
            window.overrideUserInterfaceStyle = .light
        }
        
        print("App initializing - will check for session")
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                if isCheckingSession {
                    // Show a loading screen while checking session
                    Color(hex: "E8E9E2")
                        .ignoresSafeArea()
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                } else {
                    // If user exists and onboarding is complete, go to MainView
                    // Otherwise go to PhoneRegistrationView for onboarding
                    if dataService.currentUser != nil && dataService.onboardingComplete {
                        MainView()
                            .environmentObject(dataService)
                    } else {
                        NavigationView {
                            PhoneRegistrationView()
                        }
                        .environmentObject(dataService)
                        .navigationViewStyle(StackNavigationViewStyle())
                    }
                }
            }
            .preferredColorScheme(.light)
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshRootView"))) { _ in
                // Handle notification to refresh the root view
                print("Refreshing root view")
                isCheckingSession = true
                Task {
                    await checkForExistingSession()
                }
            }
            .task {
                // Perform initial session check on app startup
                await checkForExistingSession()
            }
        }
    }
    
    func checkForExistingSession() async {
        print("Checking for existing Supabase session")
        
        do {
            // First, check if we have a valid session
            let session = try await SupabaseManager.shared.client.auth.session
            print("Found existing session: User ID \(session.user.id)")
            
            // Try to fetch the latest user profile from the database using the authenticated session
            do {
                let userProfile = try await SupabaseManager.shared.fetchUserProfile()
                
                // We have a profile, so store the user and mark onboarding as complete
                dataService.saveUser(userProfile, completeSetup: true)
                print("User profile synced from server: \(userProfile.name)")
            } catch let error as SupabaseError {
                // Check if this is specifically a "profile not found" error
                if case .profileNotFound = error {
                    print("No profile found for authenticated user - need to complete onboarding")
                    
                    // User is authenticated but has no profile - keep them signed in but don't complete onboarding
                    let userId = session.user.id.uuidString
                    let userEmail = session.user.email
                    let userPhone = session.user.phone
                    
                    // Create a basic user but DON'T mark onboarding as complete
                    let displayName = userEmail ?? userPhone ?? "User"
                    dataService.currentUser = User(id: userId, name: displayName)
                    dataService.onboardingComplete = false
                    
                    print("Created basic user from session but requiring onboarding: \(userId)")
                } else {
                    // Other fetch errors should still allow a basic session
                    print("Error fetching user profile: \(error.localizedDescription)")
                    
                    // Fall back to basic user info from the session
                    let userId = session.user.id.uuidString
                    let userEmail = session.user.email
                    let userPhone = session.user.phone
                    
                    // Create and store a basic user object
                    let displayName = userEmail ?? userPhone ?? "User"
                    dataService.currentUser = User(id: userId, name: displayName)
                    dataService.completeOnboarding() // Mark onboarding as complete despite error
                    
                    print("Created basic user from session: \(userId)")
                }
            } catch {
                // Generic error handling for other error types
                print("Error fetching user profile: \(error.localizedDescription)")
                
                // Fall back to basic user info from the session
                let userId = session.user.id.uuidString
                let userEmail = session.user.email
                let userPhone = session.user.phone
                
                // Create and store a basic user object
                let displayName = userEmail ?? userPhone ?? "User"
                dataService.currentUser = User(id: userId, name: displayName)
                dataService.completeOnboarding() // Mark onboarding as complete despite error
                
                print("Created basic user from session: \(userId)")
            }
        } catch {
            // Session is invalid or expired - user needs to go through onboarding
            print("No valid session found: \(error.localizedDescription)")
            dataService.currentUser = nil
            dataService.onboardingComplete = false
        }
        
        // Mark session check as complete
        isCheckingSession = false
    }
}
