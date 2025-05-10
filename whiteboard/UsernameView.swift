import SwiftUI
import UIKit

struct UsernameView: View {
    @State private var username: String = ""
    @State private var selectedColor: Color = Color.blue
    @State private var isAnimating: Bool = false
    @State private var currentPage: Int = 3
    @State private var totalPages: Int = 4
    @State private var navigateToGroupCreation: Bool = false
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var apnsToken: String? = nil
    @EnvironmentObject private var dataService: DataService
    @Environment(\.presentationMode) var presentationMode
    
    private let textColor = Color(hex: "E8E9E2")
    
    // Predefined color options
    private let colorOptions: [Color] = [
        Color.blue,
        Color.red,
        Color.green,
        Color.purple,
        Color.orange,
        Color.pink
    ]
    
    var body: some View {
        ZStack {
            Color(hex: "E8E9E2")
                .ignoresSafeArea()
            
            VStack {
                // Top bar with back button and pagination
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundStyle(textColor)
                            .font(.body)
                            .fontWeight(.medium)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(.black)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Text("\(currentPage)/\(totalPages)")
                        .foregroundStyle(.gray)
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.medium)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Question text
                Text("what your friends will see")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .padding(.bottom, 20)
                
                // User avatar with color and username input
                HStack(spacing: 16) {
                    // Color selector circle
                    ZStack {
                        Circle()
                            .stroke(.black, lineWidth: 1)
                            .frame(width: 64, height: 64)
                        
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 24, height: 24)
                            .scaleEffect(isAnimating ? 2.0 : 1.0)
                            .animation(.spring(response: 0.2, dampingFraction: 0.5), value: isAnimating)
                    }
                    .onTapGesture {
                        // Pick a random color when tapped with animation
                        isAnimating = true
                        
                        // Change color after a brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Ensure we pick a different color
                            let newColor = getNewRandomColor(excluding: selectedColor)
                            selectedColor = newColor
                            
                            // Reset animation state
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isAnimating = false
                            }
                        }
                    }
                    
                    // Username input field
                    TextField("Username", text: $username)
                        .foregroundColor(.white)
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.medium)
                        .multilineTextAlignment(.center)
                        .padding()
                        .frame(height: 64)
                        .background(
                            Capsule()
                                .fill(selectedColor)
                        )
                        .clipShape(Capsule())
                        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: selectedColor)
                }
                .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // Done button
                Button(action: {
                    submitUsername()
                }) {
                    if isSubmitting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    } else {
                        Text("done")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(username.isEmpty ? .gray : .white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Capsule()
                        .stroke(.gray, lineWidth: 1)
                        .background(username.isEmpty ? .clear : .black)
                )
                .clipShape(Capsule())
                .padding(.horizontal)
                .padding(.bottom, 40)
                .disabled(username.isEmpty || isSubmitting)
                .opacity((username.isEmpty || isSubmitting) ? 0.7 : 1)
                
                NavigationLink(
                    destination: GroupCreationView()
                        .navigationBarHidden(true)
                        .environmentObject(dataService),
                    isActive: $navigateToGroupCreation,
                    label: { EmptyView() }
                )
                .opacity(0)
                .onChange(of: navigateToGroupCreation) { newValue in
                    print("navigateToGroupCreation changed to: \(newValue)")
                }
            }
            .padding(.horizontal, 40)
        }
        .navigationBarHidden(true)
    }
    
    func submitUsername() {
        guard !username.isEmpty else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        // Get the hex value of the color for database storage
        let colorHex = selectedColor.toHex() ?? getColorHex(selectedColor)
        
        // Save username and color to your data service
        if let currentUser = dataService.currentUser {
            // Create updated user with the new username and color
            let updatedUser = User(
                id: currentUser.id, 
                name: username,
                appleIdentifier: currentUser.appleIdentifier,
                color: colorHex,
                apnsToken: apnsToken
            )
            
            // Call Supabase function to create the user profile
            Task {
                do {
                    // Show loading indicator
                    await MainActor.run {
                        isSubmitting = true
                    }
                    
                    // Use the SupabaseManager to create the user profile
                    let response = try await SupabaseManager.shared.createUserProfile(user: updatedUser)
                    
                    print("User profile created successfully: \(response)")
                    
                    // Save the user locally but DON'T mark onboarding as complete yet
                    // We want to go through the group creation step first
                    dataService.saveUser(updatedUser, completeSetup: false)
                    
                    // Navigate to group creation view on the main thread
                    await MainActor.run {
                        isSubmitting = false
                        print("Navigation to GroupCreationView triggered: setting navigateToGroupCreation = true")
                        
                        // Navigate programmatically as an alternative approach
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            
                            // Find the navigation controller
                            func findNavigationController(in controller: UIViewController) -> UINavigationController? {
                                if let navController = controller as? UINavigationController {
                                    return navController
                                } else if let tabController = controller as? UITabBarController,
                                          let selectedController = tabController.selectedViewController {
                                    return findNavigationController(in: selectedController)
                                } else if let presented = controller.presentedViewController {
                                    return findNavigationController(in: presented)
                                }
                                
                                for child in controller.children {
                                    if let found = findNavigationController(in: child) {
                                        return found
                                    }
                                }
                                
                                return nil
                            }
                            
                            if let navController = findNavigationController(in: rootViewController) {
                                print("Found navigation controller, attempting to push GroupCreationView")
                                
                                // Create the GroupCreationView and prepare for hosting
                                let groupCreationView = GroupCreationView()
                                    .environmentObject(dataService)
                                
                                // Create a hosting controller for the SwiftUI view
                                let hostingController = UIHostingController(rootView: groupCreationView)
                                
                                // Push the view controller
                                navController.pushViewController(hostingController, animated: true)
                            } else {
                                print("Could not find navigation controller, attempting to use binding")
                                // Force a brief delay to ensure state changes have propagated
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    navigateToGroupCreation = true
                                }
                            }
                        } else {
                            print("Could not access root view controller, falling back to binding")
                            // Force a brief delay to ensure state changes have propagated
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                navigateToGroupCreation = true
                            }
                        }
                    }
                } catch let error as SupabaseError {
                    // Handle specific Supabase errors with more detailed messages
                    print("Supabase error creating profile: \(error.localizedDescription)")
                    
                    await MainActor.run {
                        isSubmitting = false
                        errorMessage = error.localizedDescription
                    }
                } catch {
                    // Handle generic errors
                    print("Error creating user profile: \(error.localizedDescription)")
                    
                    await MainActor.run {
                        isSubmitting = false
                        errorMessage = "Failed to create profile: \(error.localizedDescription)"
                    }
                }
            }
        } else {
            isSubmitting = false
            errorMessage = "No active user session. Please restart the app."
        }
    }
    
    // Helper to get a hex string for predefined colors
    private func getColorHex(_ color: Color) -> String {
        switch colorToString(color) {
        case "blue":    return "#4285F4"
        case "red":     return "#EA4335"
        case "green":   return "#34A853"
        case "purple":  return "#9C27B0"
        case "orange":  return "#FF9800"
        case "pink":    return "#E91E63"
        default:        return "#4285F4" // Default to blue
        }
    }
    
    // Helper function to get a new random color that's different from the current one
    private func getNewRandomColor(excluding currentColor: Color) -> Color {
        // Since Color doesn't conform to Equatable in a way that works reliably with standard colors,
        // we'll use a more deterministic approach for comparison
        
        // Get current color index
        guard let currentIndex = colorOptions.firstIndex(where: { 
            // Compare colors by their description or some other property
            colorToString($0) == colorToString(currentColor)
        }) else {
            // If we can't find the current color (shouldn't happen), just return the first color
            return colorOptions.first ?? .blue
        }
        
        // If we have only one color, return it (should never happen with our setup)
        if colorOptions.count <= 1 {
            return colorOptions.first ?? .blue
        }
        
        // Pick a different index randomly
        var newIndex: Int
        repeat {
            newIndex = Int.random(in: 0..<colorOptions.count)
        } while newIndex == currentIndex
        
        return colorOptions[newIndex]
    }
    
    // Helper to convert a Color to a comparable string representation
    private func colorToString(_ color: Color) -> String {
        // This is a simplistic approach - in a real app you might want to use UIColor components
        // for more precise comparison
        if color == .blue { return "blue" }
        if color == .red { return "red" }
        if color == .green { return "green" }
        if color == .purple { return "purple" }
        if color == .orange { return "orange" }
        if color == .pink { return "pink" }
        return "unknown"
    }
}

// Helper extension for arrays
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

struct UsernameView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            UsernameView()
                .environmentObject(DataService())
        }
    }
} 
