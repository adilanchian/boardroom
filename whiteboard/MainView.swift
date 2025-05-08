import SwiftUI

struct MainView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var dataService: DataService
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Boards Tab
            BoardsView()
                .environmentObject(dataService)
                .tabItem {
                    Label("Boards", systemImage: "rectangle.grid.2x2")
                }
                .tag(0)
            
            // Profile Tab
            ProfileView()
                .environmentObject(dataService)
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(1)
        }
        .accentColor(.black)
        .onAppear {
            // Set tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor(Color(hex: "E8E9E2"))
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

// Simple Profile View (placeholder)
struct ProfileView: View {
    @EnvironmentObject private var dataService: DataService
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Profile")
                .font(.system(.title2, design: .monospaced))
            
            if let user = dataService.currentUser {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Circle()
                            .fill(Color(hex: user.color ?? "#4285F4"))
                            .frame(width: 50, height: 50)
                        
                        Text(user.name)
                            .font(.system(.title3, design: .monospaced))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                    )
                    .padding()
                }
                
                Button(action: {
                    // Sign out
                    Task {
                        try? await SupabaseManager.shared.client.auth.signOut()
                        dataService.signOut()
                        // Refresh root view
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshRootView"), object: nil)
                    }
                }) {
                    Text("Sign Out")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Capsule().fill(Color.black))
                }
            }
            
            Spacer()
        }
        .padding(.top, 50)
        .frame(maxWidth: .infinity)
        .background(Color(hex: "E8E9E2").ignoresSafeArea())
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(DataService())
    }
} 