//
//  ContentView.swift
//  whiteboard
//
//  Created by alec on 3/26/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var dataService: DataService
    
    var body: some View {
        // This is now a simple redirect view that will be replaced by the App's main view
        Text("Redirecting...")
            .font(.system(.body, design: .monospaced))
            .onAppear {
                print("ContentView appeared - this view should not be used directly")
                // Trigger a notification to refresh the root view
                NotificationCenter.default.post(name: NSNotification.Name("RefreshRootView"), object: nil)
            }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataService())
    }
}
