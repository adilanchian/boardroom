import SwiftUI

struct BoardsView: View {
    @State private var boardrooms: [Boardroom] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showingNewBoardSheet = false
    @EnvironmentObject private var dataService: DataService
    
    private let backgroundColor = Color(hex: "E8E9E2")
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                backgroundColor.ignoresSafeArea()
                
                VStack {
                    // Title
                    Text("your boards")
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.medium)
                        .padding(.top, 20)
                    
                    if isLoading {
                        // Loading state
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Spacer()
                    } else if let error = errorMessage {
                        // Error state
                        Spacer()
                        VStack(spacing: 16) {
                            Text("Couldn't load your boards")
                                .font(.system(.headline, design: .monospaced))
                            
                            Text(error)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                                
                            Button(action: {
                                Task {
                                    await loadBoardrooms()
                                }
                            }) {
                                Text("try again")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                            }
                        }
                        Spacer()
                    } else if boardrooms.isEmpty {
                        // Empty state
                        Spacer()
                        VStack(spacing: 16) {
                            Text("no boards yet")
                                .font(.system(.headline, design: .monospaced))
                            
                            Text("create a new board to get started")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button(action: {
                                showingNewBoardSheet = true
                            }) {
                                Text("create board")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .stroke(Color.black, lineWidth: 1)
                                    )
                            }
                        }
                        Spacer()
                    } else {
                        // List of boards
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(boardrooms) { boardroom in
                                    NavigationLink(destination: BoardroomDetailView(boardroom: boardroom)) {
                                        BoardroomCard(boardroom: boardroom) {
                                            // The action is handled by the NavigationLink
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                    }
                }
                
                // Add button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: {
                            showingNewBoardSheet = true
                        }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.black)
                                .clipShape(Circle())
                                .shadow(radius: 4)
                        }
                        .padding()
                    }
                }
            }
            .sheet(isPresented: $showingNewBoardSheet) {
                CreateBoardView(onBoardCreated: { newBoardName in
                    Task {
                        if !newBoardName.isEmpty {
                            await createBoardroom(name: newBoardName)
                        }
                    }
                })
                .presentationDetents([.height(300)])
            }
            .navigationBarHidden(true)
            .task {
                await loadBoardrooms()
            }
            .refreshable {
                await loadBoardrooms()
            }
        }
    }
    
    // Load boardrooms from the service
    private func loadBoardrooms() async {
        isLoading = true
        errorMessage = nil
        
        // Get boardrooms from data service
        let fetchedBoardrooms = dataService.getAllBoardrooms()
        
        // Sort boardrooms by most recently created
        let sortedBoardrooms = fetchedBoardrooms.sorted { 
            $0.createdAt > $1.createdAt
        }
        
        await MainActor.run {
            boardrooms = sortedBoardrooms
            isLoading = false
        }
    }
    
    // Create a new boardroom
    private func createBoardroom(name: String) async {
        // Create boardroom using dataService
        let userId = dataService.currentUser?.id ?? "unknown"
        let boardroom = Boardroom(
            id: UUID().uuidString,
            name: name,
            items: [],
            createdBy: userId,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // Save the new boardroom
        dataService.saveBoardroom(boardroom)
        print("Created boardroom: \(boardroom.name) with ID: \(boardroom.id)")
        
        // Refresh the boardrooms list
        await loadBoardrooms()
    }
}

// Sheet for creating a new board
struct CreateBoardView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var boardName: String = ""
    @State private var isCreating: Bool = false
    var onBoardCreated: (String) -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Text("new board")
                .font(.system(.headline, design: .monospaced))
                .padding(.top)
            
            TextField("Board name", text: $boardName)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal)
            
            HStack(spacing: 16) {
                Button(action: {
                    dismiss()
                }) {
                    Text("cancel")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                
                Button(action: {
                    isCreating = true
                    onBoardCreated(boardName)
                    dismiss()
                }) {
                    if isCreating {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("create")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(boardName.isEmpty ? Color.gray : Color.black)
                            )
                    }
                }
                .disabled(boardName.isEmpty || isCreating)
            }
            .padding(.bottom)
        }
        .background(Color(hex: "E8E9E2"))
    }
}

struct BoardsView_Previews: PreviewProvider {
    static var previews: some View {
        BoardsView()
            .environmentObject(DataService())
    }
} 