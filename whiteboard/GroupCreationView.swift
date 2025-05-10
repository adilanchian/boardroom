import SwiftUI
import Supabase

struct GroupCreationView: View {
    @State private var boardroomName: String = ""
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
                Text("let's create a board")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .onAppear {
                        print("Title text in GroupCreationView appeared")
                    }
                
                // Boardroom name input field
                TextField("Name (like the board name)", text: $boardroomName)
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
                    Task { await createBoardroom() }
                }) {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    } else {
                        Text("create")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(boardroomName.isEmpty ? .gray : .white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Capsule()
                        .stroke(Color.gray, lineWidth: 1)
                        .background(boardroomName.isEmpty ? Color.clear : Color.black)
                )
                .foregroundColor(boardroomName.isEmpty ? .gray : .white)
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
                .disabled(boardroomName.isEmpty || isCreating)
                .opacity(boardroomName.isEmpty || isCreating ? 0.7 : 1)
            }
            .padding(.horizontal, 20)
        }
        .navigationBarHidden(true)
        .onAppear {
            print("GroupCreationView appeared - checking for existing boardrooms")
            // Check if user is already in a boardroom - if yes, skip this screen
            checkExistingBoardrooms()
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
    
    // Check if user is already in any boardrooms
    private func checkExistingBoardrooms() {
        Task {
            do {
                // Use SupabaseManager to check if user is in any boardrooms
                let boardrooms = try await SupabaseManager.shared.getUserBoardrooms()
                
                // If user already has boardrooms, skip this screen and go directly to main
                if !boardrooms.isEmpty {
                    print("User already has \(boardrooms.count) boardrooms, skipping boardroom creation")
                    
                    // Mark onboarding as complete
                    dataService.completeOnboarding()
                    
                    // Navigate to main view
                    navigateToMain = true
                } else {
                    print("User has no boardrooms, showing boardroom creation screen")
                }
            } catch {
                // If there's an error checking boardrooms, allow user to create one anyway
                print("Error checking user boardrooms: \(error.localizedDescription)")
            }
        }
    }
    
    // Create a new boardroom using Supabase function
    private func createBoardroom() async {
        guard !boardroomName.isEmpty else { return }
        
        isCreating = true
        errorMessage = nil
        
        do {
            // Use the SupabaseManager to create a boardroom
            let boardroom = try await SupabaseManager.shared.createBoardroom(name: boardroomName)
            
            print("Boardroom created successfully: \(boardroomName) (ID: \(boardroom.id))")
            
            // Also save to local DataService so it appears in the boards list
            let localBoardroom = Boardroom(
                id: boardroom.id,
                name: boardroom.name,
                items: [],
                createdBy: boardroom.createdBy,
                createdAt: boardroom.createdAt,
                updatedAt: boardroom.updatedAt
            )
            
            // Save to local storage
            dataService.saveBoardroom(localBoardroom)
            
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
                errorMessage = "Couldn't create board: \(message)"
            case .invalidUserData:
                errorMessage = "Please enter a valid board name"
            default:
                errorMessage = "Couldn't create board. Please try again."
            }
            
            print("Error creating boardroom: \(error.localizedDescription)")
        } catch {
            isCreating = false
            errorMessage = "Couldn't create board. Please try again."
            print("Error creating boardroom: \(error.localizedDescription)")
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
