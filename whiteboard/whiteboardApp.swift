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
    
    init() {
        // Force light mode for the entire app
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        windowScene?.windows.forEach { window in
            window.overrideUserInterfaceStyle = .light
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataService)
                .preferredColorScheme(.light) // Also set SwiftUI views to prefer light mode
        }
    }
}
