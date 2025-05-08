import SwiftUI

struct BoardsView: View {
    @State private var groups: [Group] = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    @State private var showingNewBoardSheet = false
    @EnvironmentObject private var dataService: DataService
    
    private let backgroundColor = Color(hex: "E8E9E2")
    
    var body: some View {
        NavigationView {
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
                                    await loadGroups()
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
                    } else if groups.isEmpty {
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
                                ForEach(groups) { group in
                                    GroupCard(group: group)
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
                CreateBoardView(onBoardCreated: { newGroupName in
                    Task {
                        if !newGroupName.isEmpty {
                            await createBoard(name: newGroupName)
                        }
                    }
                })
                .presentationDetents([.height(300)])
            }
            .navigationBarHidden(true)
            .task {
                await loadGroups()
            }
            .refreshable {
                await loadGroups()
            }
        }
    }
    
    // Load groups from the server
    private func loadGroups() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let fetchedGroups = try await SupabaseManager.shared.getUserGroups()
            
            // Sort groups by most recently created
            let sortedGroups = fetchedGroups.sorted { 
                // Assuming createdAt is in ISO format, this string comparison should work
                $0.createdAt > $1.createdAt
            }
            
            await MainActor.run {
                groups = sortedGroups
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }
    }
    
    // Create a new board/group
    private func createBoard(name: String) async {
        do {
            // Create group using SupabaseManager
            let group = try await SupabaseManager.shared.createGroup(name: name)
            print("Created board: \(group.name) with ID: \(group.id)")
            
            // Refresh the groups list
            await loadGroups()
        } catch {
            print("Error creating board: \(error.localizedDescription)")
            errorMessage = "Failed to create board: \(error.localizedDescription)"
        }
    }
}

// Card view for individual group/board
struct GroupCard: View {
    let group: Group
    @State private var navigateToDetail = false
    
    var body: some View {
        ZStack {
            Button(action: {
                // Navigate to the board details
                print("Selected board: \(group.name)")
                navigateToDetail = true
            }) {
                HStack {
                    // Board info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(group.name)
                            .font(.system(.headline, design: .monospaced))
                            .foregroundColor(.black)
                        
                        let dateStr = formatDate(group.createdAt)
                        Text("Created \(dateStr)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    // Chevron
                    Image(systemName: "chevron.right")
                        .foregroundColor(.black)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                )
            }
            
            NavigationLink(
                destination: BoardDetailView(group: group),
                isActive: $navigateToDetail,
                label: { EmptyView() }
            )
            .opacity(0)
        }
    }
    
    // Format ISO date string to readable format
    private func formatDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: isoString) {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .short
            return formatter.localizedString(for: date, relativeTo: Date())
        }
        
        return "recently"
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