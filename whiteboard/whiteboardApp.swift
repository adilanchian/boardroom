//
//  whiteboardApp.swift
//  whiteboard
//
//  Created by alec on 3/26/25.
//

import SwiftUI
import UIKit

// Add photo library usage permission to Info.plist
// IMPORTANT: Add this key to your project settings:
// - NSPhotoLibraryUsageDescription: "Allow access to add photos to your whiteboard"

@main
struct whiteboardApp: App {
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
                    // If user exists, go to MainView, otherwise go to PhoneRegistrationView
                    if dataService.currentUser != nil {
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
            .task {
                await checkForExistingSession()
            }
        }
    }
    
    func checkForExistingSession() async {
        print("Checking for existing Supabase session")
        
        do {
            let session = try await SupabaseManager.shared.client.auth.session
            
            print("Found existing session: User ID \(session.user.id)")
            
            // Create a user object based on session info
            let userId = session.user.id.uuidString
            let userEmail = session.user.email
            
            // Create and store the user
            dataService.currentUser = User(id: userId, name: userEmail ?? "User")
            print("User session restored: \(userId)")
        } catch {
            print("Error checking session: \(error.localizedDescription)")
            dataService.currentUser = nil
        }
        
        // Mark session check as complete
        isCheckingSession = false
    }
}
