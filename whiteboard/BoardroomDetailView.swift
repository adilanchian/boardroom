import SwiftUI
import WidgetKit
import PhotosUI

struct BoardroomDetailView: View {
    let boardroom: Boardroom
    @EnvironmentObject private var dataService: DataService
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = true
    @State private var whiteboard: Boardroom?
    
    // State variables for item manipulation
    @State private var selectedItem: String? = nil
    @State private var itemStates: [String: BoardItemState] = [:]
    
    // Photo picker state
    @State private var isShowingPhotoPicker = false
    @State private var selectedImage: UIImage?
    
    // Text editing state
    @State private var isAddingText = false
    @State private var newText = ""
    @State private var textPosition = CGPoint(x: 0, y: 0)
    @FocusState private var isTextFieldFocused: Bool
    
    // Instruction overlay state
    @State private var showInstructions = true
    
    // Canvas size
    @State private var canvasWidth: CGFloat = 338
    @State private var canvasHeight: CGFloat = 354
    
    // Auto-save timer
    @State private var autoSaveTask: DispatchWorkItem?
    
    private let backgroundColor = Color(hex: "E8E9E2")
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor.ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header section
                boardHeaderView
                
                // Main content
                if isLoading {
                    loadingView
                } else {
                    // Boardroom canvas
                    canvasView
                }
                
                // Action buttons
                actionButtonsView
            }
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            PhotoPicker(selectedImage: $selectedImage, onImageSelected: { image in
                addImageToBoardroom(image)
            })
        }
        .onChange(of: selectedImage) { oldImage, newImage in
            if let image = newImage {
                addImageToBoardroom(image)
                // Reset selected image
                selectedImage = nil
            }
        }
        // Listen for explicit save requests
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SaveBoardroomRequest"))) { _ in
            print("📢 Received save request notification - saving boardroom")
            saveBoardroom()
        }
        // Listen for FORCE save requests (higher priority)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ForceBoardroomSave"))) { _ in
            print("🔥 Received FORCE save notification - saving boardroom immediately")
            saveBoardroom()
        }
        // Listen for app going to background
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("📱 App going to background - saving boardroom")
            saveBoardroom()
        }
        .onAppear {
            // Initialize boardroom for this boardroom
            loadOrCreateBoardroom()
        }
        .onDisappear {
            // Save when leaving the view
            print("📱 View disappearing - saving boardroom")
            saveBoardroom()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                backButton
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                saveButton
            }
        }
    }
    
    // MARK: - View Components
    
    private var boardHeaderView: some View {
        VStack(spacing: 12) {
            Text(boardroom.name)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.medium)
            
            // Format and show creation date
            let formattedDate = formatDate(boardroom.createdAt)
            Text("Created \(formattedDate)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.gray)
        }
        .padding(.top, 20)
    }
    
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
            Spacer()
        }
    }
    
    private var canvasView: some View {
        GeometryReader { geometry in
            ZStack {
                // Background container
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 5)
                    .frame(width: canvasWidth, height: canvasHeight)
                
                // Canvas for rendering grid
                Canvas { context, size in
                    // Draw a subtle grid for better positioning reference
                    drawGrid(context: context, size: size)
                }
                .frame(width: canvasWidth, height: canvasHeight)
                
                // Items container
                itemsContainerView
                
                // Instructions overlay
                if showInstructions && whiteboard?.items.isEmpty == true {
                    instructionsOverlay
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                let size = getCanvasDimensions(for: geometry.size.width)
                canvasWidth = size.width
                canvasHeight = size.height
            }
            .onChange(of: geometry.size) { oldSize, newSize in
                let size = getCanvasDimensions(for: newSize.width)
                canvasWidth = size.width
                canvasHeight = size.height
            }
        }
        .simultaneousGesture(
            // Tap gesture on the canvas to add text at that position
            TapGesture()
                .onEnded { _ in
                    // Deselect any selected item when tapping on the canvas
                    if !isAddingText {
                        selectedItem = nil
                    }
                }
        )
        .padding(.horizontal)
        .frame(maxHeight: .infinity)
    }
    
    private var itemsContainerView: some View {
        ZStack {
            // Boardroom items
            if let board = whiteboard {
                ForEach(board.items) { item in
                    BoardroomInteractiveItem(
                        item: item,
                        isSelected: selectedItem == item.id,
                        state: itemStateFor(item),
                        onSelect: { selectedItem = item.id },
                        onUpdate: { state in
                            updateItemState(id: item.id, state: state)
                        },
                        onDelete: {
                            deleteItem(item)
                        }
                    )
                }
            }
            
            // Direct text input field
            if isAddingText {
                textInputField
            }
        }
        .frame(width: canvasWidth, height: canvasHeight)
        .clipped()
    }
    
    private var textInputField: some View {
        TextField("Enter text...", text: $newText)
            .padding(8)
            .background(Color.white)
            .cornerRadius(8)
            .frame(width: 200)
            .shadow(radius: 2)
            .position(textPosition)
            .focused($isTextFieldFocused)
            .submitLabel(.done)
            .onSubmit {
                if !newText.isEmpty {
                    addTextItem(newText, at: textPosition)
                }
                isAddingText = false
                newText = ""
            }
            .onAppear {
                isTextFieldFocused = true
            }
    }
    
    private var instructionsOverlay: some View {
        VStack(spacing: 16) {
            Text("How to use:")
                .font(.system(.headline, design: .monospaced))
            
            HStack(spacing: 16) {
                instructionItem(icon: "hand.tap", text: "Tap to select")
                instructionItem(icon: "arrow.up.and.down.and.arrow.left.and.right", text: "Drag to move")
            }
            
            HStack(spacing: 16) {
                instructionItem(icon: "rotate.right", text: "Two fingers\nto rotate", multiline: true)
                instructionItem(icon: "arrow.up.left.and.arrow.down.right", text: "Pinch to scale")
            }
            
            Button("Got it") {
                withAnimation {
                    showInstructions = false
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .padding(24)
        .background(Color.white.opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 5)
        .transition(.opacity)
        .onAppear {
            // Auto-dismiss after 5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    showInstructions = false
                }
            }
        }
    }
    
    private func instructionItem(icon: String, text: String, multiline: Bool = false) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.system(size: 20))
            Text(text)
                .font(.system(.caption, design: .monospaced))
                .multilineTextAlignment(multiline ? .center : .leading)
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 20) {
            ActionButton(title: "text", icon: "text.bubble") {
                // Add text
                textPosition = CGPoint(x: canvasWidth/2, y: canvasHeight/2)
                isAddingText = true
                newText = ""
            }
            
            ActionButton(title: "image", icon: "photo") {
                // Add image
                isShowingPhotoPicker = true
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    private var backButton: some View {
        Button(action: {
            // Save before dismissing
            saveBoardroom()
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(.body, design: .monospaced))
                Text("Boards")
                    .font(.system(.body, design: .monospaced))
            }
            .foregroundColor(.black)
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            // Manually save
            saveBoardroom()
        }) {
            Text("save")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.black)
        }
    }
    
    // MARK: - Helper Methods
    
    // Format ISO date string to readable format
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    // Calculate canvas dimensions that maintain aspect ratio
    private func getCanvasDimensions(for width: CGFloat) -> (width: CGFloat, height: CGFloat) {
        let maxWidth: CGFloat = min(width - 32, 338) // 16px padding on each side
        let aspectRatio: CGFloat = 338 / 354 // Match the widget aspect ratio
        let height = maxWidth / aspectRatio
        
        return (maxWidth, height)
    }
    
    // Draw a subtle grid on the canvas
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridSpacing: CGFloat = min(size.width, size.height) / 12
        let lineWidth: CGFloat = 0.5
        let gridColor = Color.gray.opacity(0.1)
        
        for x in stride(from: gridSpacing, to: size.width, by: gridSpacing) {
            var path = Path()
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(path, with: .color(gridColor), lineWidth: lineWidth)
        }
        
        for y in stride(from: gridSpacing, to: size.height, by: gridSpacing) {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            context.stroke(path, with: .color(gridColor), lineWidth: lineWidth)
        }
    }
    
    // Methods for item management
    
    // Initialize item states from boardroom items
    private func initializeItemStates() {
        guard let board = whiteboard else { return }
        
        itemStates.removeAll()
        
        for item in board.items {
            // Ensure scale is explicitly set to 1.0 if nil
            let scaleValue = item.scale
            let rotationValue = item.rotation
            
            print("🔍 Initializing item \(item.id) with scale: \(scaleValue)")
            
            itemStates[item.id] = BoardItemState(
                position: item.position,
                rotation: rotationValue,
                scale: scaleValue
            )
        }
        
        // Save after initialization to ensure all scales are set
        saveBoardroom()
    }
    
    // Get or create a state for an item
    private func itemStateFor(_ item: BoardroomItem) -> BoardItemState {
        if let state = itemStates[item.id] {
            return state
        } else {
            // Get the scale value directly from the item
            let itemScale = item.scale
            print("🔍 Creating new state for item \(item.id) with scale: \(itemScale)")
            
            // Create state but update it outside of the rendering cycle
            DispatchQueue.main.async {
                let newState = BoardItemState(
                    position: item.position,
                    rotation: item.rotation,
                    scale: itemScale
                )
                self.itemStates[item.id] = newState
            }
            
            // Return a temporary state for this render cycle with the correct scale
            return BoardItemState(
                position: item.position,
                rotation: item.rotation,
                scale: itemScale
            )
        }
    }
    
    // Update the state for an item
    private func updateItemState(id: String, state: BoardItemState) {
        print("\n📝 updateItemState called for item: \(id)")
        print("   With state - position: \(state.position), rotation: \(state.rotation), scale: \(state.scale)")
        
        // Keep a reference to the old state for debugging
        let oldState = itemStates[id]
        if let oldState = oldState {
            print("   Old state - position: \(oldState.position), rotation: \(oldState.rotation), scale: \(oldState.scale)")
        }
        
        // Update the item state in our tracking dictionary
        itemStates[id] = state
        
        // Update the item in our boardroom model
        if let board = whiteboard, let index = board.items.firstIndex(where: { $0.id == id }) {
            let oldScaleValue = whiteboard?.items[index].scale
            let oldRotationValue = whiteboard?.items[index].rotation
            
            print("🔄 Found item in boardroom at index \(index)")
            print("   Current values in model - rotation: \(oldRotationValue), scale: \(oldScaleValue)")
            print("   New values from state - rotation: \(state.rotation), scale: \(state.scale)")
            
            // Create a mutable copy of the item
            var updatedItem = whiteboard!.items[index]
            
            // Update all properties on the copy
            updatedItem.position = state.position
            updatedItem.rotation = state.rotation
            updatedItem.scale = state.scale
            
            // Verify the copy has correct values
            print("   Updated item - rotation: \(updatedItem.rotation), scale: \(updatedItem.scale)")
            
            // Replace the item in the boardroom
            whiteboard?.items[index] = updatedItem
            
            // Double-check the change took effect
            let checkScale = whiteboard?.items[index].scale
            let checkRotation = whiteboard?.items[index].rotation
            print("   After replacement - rotation: \(checkRotation), scale: \(checkScale)")
            
            // Save immediately after any update
            print("   Calling saveBoardroom() now")
            saveBoardroom()
            
            // Verify the scale one more time after save
            let finalCheck = whiteboard?.items[index].scale
            print("   Final model check - scale: \(finalCheck)\n")
        } else {
            print("❌ Failed to find item \(id) in boardroom")
        }
    }
    
    // Delete an item
    private func deleteItem(_ item: BoardroomItem) {
        whiteboard?.items.removeAll(where: { $0.id == item.id })
        itemStates.removeValue(forKey: item.id)
        
        // Save after deletion
        saveBoardroom()
    }
    
    // Add a text item to the boardroom
    private func addTextItem(_ text: String, at position: CGPoint) {
        guard let board = whiteboard else { return }
        
        let newItem = BoardroomItem(
            boardroomId: board.id,
            type: .text,
            content: text,
            position: position,
            rotation: 0,
            scale: 1.0,
            createdBy: dataService.currentUser?.id ?? "unknown"
        )
        
        // Add the item to our boardroom
        whiteboard?.items.append(newItem)
        
        // Initialize its state
        itemStates[newItem.id] = BoardItemState(
            position: position,
            rotation: 0,
            scale: 1.0
        )
        
        // Save the boardroom with the new item
        saveBoardroom()
    }
    
    // Add an image to the boardroom
    private func addImageToBoardroom(_ image: UIImage) {
        guard let board = whiteboard else { return }
        
        // Create unique local identifier
        let localId = "local_photo:\(UUID().uuidString)"
        
        // Create the new item
        let newItem = BoardroomItem(
            boardroomId: board.id,
            type: .image,
            content: localId,
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2),
            rotation: 0,
            scale: 1.0,
            createdBy: dataService.currentUser?.id ?? "unknown"
        )
        
        // Save the image to local storage using the BoardroomUtility
        BoardroomUtility.saveImage(image, withIdentifier: localId)
        
        // Add the item to our model
        whiteboard?.items.append(newItem)
        
        // Initialize its state
        itemStates[newItem.id] = BoardItemState(
            position: CGPoint(x: canvasWidth/2, y: canvasHeight/2),
            rotation: 0,
            scale: 1.0
        )
        
        // Save the boardroom with the new item
        saveBoardroom()
    }
    
    // Load the boardroom content or create a new one
    private func loadOrCreateBoardroom() {
        // Try to load existing boardroom from dataService
        if let existingBoardroom = dataService.getBoardroomForBoardroom(boardroom.id) {
            whiteboard = existingBoardroom
            print("📂 Loaded existing boardroom with \(existingBoardroom.items.count) items")
            
            // Initialize item states from loaded boardroom
            initializeItemStates()
            
            // Mark loading as complete
            isLoading = false
        } else {
            // Create a new boardroom
            whiteboard = Boardroom(
                id: boardroom.id,
                name: boardroom.name,
                items: [],
                createdBy: dataService.currentUser?.id ?? "unknown",
                createdAt: boardroom.createdAt,
                updatedAt: Date()
            )
            
            // Save the new boardroom
            saveBoardroom()
            
            print("🆕 Created new boardroom for boardroom: \(boardroom.name)")
            
            // Mark loading as complete
            isLoading = false
        }
    }
    
    // Save the current boardroom state
    private func saveBoardroom() {
        guard let board = whiteboard else { return }
        
        // Update the modification time
        var updatedBoardroom = board
        updatedBoardroom.updatedAt = Date()
        
        // Save to dataService
        dataService.saveBoardroom(updatedBoardroom)
        
        // Update local reference
        whiteboard = updatedBoardroom
        
        // Update the widget
        dataService.updateWidgets()
        
        print("💾 Saved boardroom with \(updatedBoardroom.items.count) items")
    }
}

// MARK: - Supporting Views

// Custom action button used in the action buttons section
struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(.caption, design: .monospaced))
            }
            .padding()
            .frame(width: 90, height: 90)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.1), radius: 2)
            )
        }
        .foregroundColor(.black)
    }
} 