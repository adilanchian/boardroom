import SwiftUI
import Supabase

struct GroupCreationView: View {
    @State private var groupName: String = ""
    @State private var isCreating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var navigateToMain: Bool = false
    @State private var currentPage: Int = 4
    @State private var totalPages: Int = 4
    @EnvironmentObject private var dataService: DataService
    
    private let backgroundColor = Color(hex: "E8E9E2")
    private let textColor = Color(hex: "E8E9E2")
    
    var body: some View {
        ZStack {
            // Background color
            backgroundColor
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Top bar with pagination
                HStack {
                    Spacer()
                    
                    Text("\(currentPage)/\(totalPages)")
                        .foregroundStyle(.gray)
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.medium)
                }
                .padding(.top, 50)
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Title
                Text("let's create a group")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .onAppear {
                        print("Title text in GroupCreationView appeared")
                    }
                
                // Group name input field
                TextField("Name (like the group-chat)", text: $groupName)
                    .padding()
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.black)
                    .background(
                        Capsule()
                            .stroke(Color.black, lineWidth: 1)
                            .background(Color.clear)
                    )
                    .padding(.horizontal, 20)
                
                // Error message if any
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.system(.footnote, design: .monospaced))
                }
                
                Spacer()
                
                // Create button
                Button(action: {
                    Task { await createGroup() }
                }) {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    } else {
                        Text("create")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(groupName.isEmpty ? .gray : .white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Capsule()
                        .stroke(Color.gray, lineWidth: 1)
                        .background(groupName.isEmpty ? Color.clear : Color.black)
                )
                .foregroundColor(groupName.isEmpty ? .gray : .white)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .disabled(groupName.isEmpty || isCreating)
                .opacity(groupName.isEmpty || isCreating ? 0.7 : 1)
            }
            .padding(.horizontal, 20)
        }
        .navigationBarHidden(true)
        .onAppear {
            print("GroupCreationView appeared - checking for existing groups")
            // Check if user is already in a group - if yes, skip this screen
            checkExistingGroups()
        }
        .background(
            NavigationLink(
                destination: MainView()
                    .navigationBarHidden(true)
                    .environmentObject(dataService),
                isActive: $navigateToMain,
                label: { EmptyView() }
            )
            .opacity(0)
        )
    }
    
    // Check if user is already in any groups
    private func checkExistingGroups() {
        Task {
            do {
                // Use SupabaseManager to check if user is in any groups
                let groups = try await SupabaseManager.shared.checkUserGroups()
                
                // If user already has groups, skip this screen and go directly to main
                if !groups.isEmpty {
                    print("User already has \(groups.count) groups, skipping group creation")
                    
                    // Mark onboarding as complete
                    dataService.completeOnboarding()
                    
                    // Navigate to main view
                    navigateToMain = true
                } else {
                    print("User has no groups, showing group creation screen")
                }
            } catch {
                // If there's an error checking groups, allow user to create one anyway
                print("Error checking user groups: \(error.localizedDescription)")
            }
        }
    }
    
    // Create a new group using Supabase function
    private func createGroup() async {
        guard !groupName.isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        
        do {
            // Use the SupabaseManager to create a group
            let group = try await SupabaseManager.shared.createGroup(name: groupName)
            
            print("Group created successfully: \(groupName) (ID: \(group.id))")
            
            // Mark onboarding as complete
            dataService.completeOnboarding()
            
            // Navigate to main view
            isCreating = false
            navigateToMain = true
            
        } catch let error as SupabaseError {
            isCreating = false
            
            // Handle specific Supabase errors with detailed messages
            switch error {
            case .functionError(_, let message):
                errorMessage = "Couldn't create group: \(message)"
            case .invalidUserData:
                errorMessage = "Please enter a valid group name"
            default:
                errorMessage = "Couldn't create group. Please try again."
            }
            
            print("Error creating group: \(error.localizedDescription)")
        } catch {
            isCreating = false
            errorMessage = "Couldn't create group. Please try again."
            print("Error creating group: \(error.localizedDescription)")
        }
    }
}

// Preview
struct GroupCreationView_Previews: PreviewProvider {
    static var previews: some View {
        GroupCreationView()
            .environmentObject(DataService())
    }
} 
