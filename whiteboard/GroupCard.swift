import SwiftUI
import WidgetKit
import PhotosUI

struct BoardDetailView: View {
    let group: Group
    @EnvironmentObject private var dataService: DataService
    @Environment(\.presentationMode) var presentationMode
    @State private var isLoading = true
    @State private var whiteboard: Whiteboard?
    @State private var showingInviteSheet = false
    
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
                    // Whiteboard canvas
                    canvasView
                }
                
                // Action buttons
                actionButtonsView
            }
        }
        .sheet(isPresented: $showingInviteSheet) {
            InviteView(group: group)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            PhotoPicker(selectedImage: $selectedImage, onImageSelected: { image in
                addImageToWhiteboard(image)
            })
        }
        .onChange(of: selectedImage) { oldImage, newImage in
            if let image = newImage {
                addImageToWhiteboard(image)
                // Reset selected image
                selectedImage = nil
            }
        }
        // Listen for explicit save requests
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("SaveWhiteboardRequest"))) { _ in
            print("📢 Received save request notification - saving whiteboard")
            saveWhiteboard()
        }
        // Listen for FORCE save requests (higher priority)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ForceWhiteboardSave"))) { _ in
            print("🔥 Received FORCE save notification - saving whiteboard immediately")
            saveWhiteboard()
        }
        // Listen for app going to background
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            print("📱 App going to background - saving whiteboard")
            saveWhiteboard()
        }
        .onAppear {
            // Initialize whiteboard for this group
            loadOrCreateWhiteboard()
        }
        .onDisappear {
            // Save when leaving the view
            print("📱 View disappearing - saving whiteboard")
            saveWhiteboard()
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
            Text(group.name)
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.medium)
            
            // Format and show creation date
            let formattedDate = formatDate(group.createdAt)
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
            // Whiteboard items
            if let board = whiteboard {
                ForEach(board.items) { item in
                    BoardInteractiveItem(
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
            
            ActionButton(title: "invite", icon: "person.badge.plus") {
                // Show invite view
                showingInviteSheet = true
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 30)
    }
    
    private var backButton: some View {
        Button(action: {
            // Save before dismissing
            saveWhiteboard()
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
            saveWhiteboard()
        }) {
            Text("save")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.black)
        }
    }
    
    // MARK: - Helper Methods
    
    // Format ISO date string to readable format
    private func formatDate(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = isoFormatter.date(from: isoString) {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
        
        return "recently"
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
    
    // Initialize item states from whiteboard items
    private func initializeItemStates() {
        guard let board = whiteboard else { return }
        
        itemStates.removeAll()
        
        for item in board.items {
            // Ensure scale is explicitly set to 1.0 if nil
            let scaleValue = item.scale ?? 1.0
            let rotationValue = item.rotation ?? 0.0
            
            print("🔍 Initializing item \(item.id) with scale: \(scaleValue) (original: \(String(describing: item.scale)))")
            
            // If scale is nil, set it in the model
            if item.scale == nil {
                print("⚠️ Fixing nil scale during initialization")
                if let index = whiteboard?.items.firstIndex(where: { $0.id == item.id }) {
                    whiteboard?.items[index].scale = 1.0
                }
            }
            
            itemStates[item.id] = BoardItemState(
                position: item.position,
                rotation: rotationValue,
                scale: scaleValue
            )
        }
        
        // Save after initialization to ensure all scales are set
        saveWhiteboard()
    }
    
    // Get or create a state for an item
    private func itemStateFor(_ item: WhiteboardItem) -> BoardItemState {
        if let state = itemStates[item.id] {
            return state
        } else {
            // Get the scale value directly from the item, defaulting to 1.0 if nil
            let itemScale = item.scale ?? 1.0
            print("🔍 Creating new state for item \(item.id) with scale: \(itemScale)")
            
            // Create state but update it outside of the rendering cycle
            DispatchQueue.main.async {
                let newState = BoardItemState(
                    position: item.position,
                    rotation: item.rotation ?? 0,
                    scale: itemScale
                )
                self.itemStates[item.id] = newState
            }
            
            // Return a temporary state for this render cycle with the correct scale
            return BoardItemState(
                position: item.position,
                rotation: item.rotation ?? 0,
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
        
        // Update the item in our whiteboard model
        if let board = whiteboard, let index = board.items.firstIndex(where: { $0.id == id }) {
            let oldScaleValue = whiteboard?.items[index].scale
            let oldRotationValue = whiteboard?.items[index].rotation
            
            print("🔄 Found item in whiteboard at index \(index)")
            print("   Current values in model - rotation: \(oldRotationValue ?? 0.0), scale: \(oldScaleValue ?? 1.0)")
            print("   New values from state - rotation: \(state.rotation), scale: \(state.scale)")
            
            // Create a mutable copy of the item
            var updatedItem = whiteboard!.items[index]
            
            // Update all properties on the copy
            updatedItem.position = state.position
            updatedItem.rotation = state.rotation
            updatedItem.scale = state.scale
            
            // Verify the copy has correct values
            print("   Updated item - rotation: \(updatedItem.rotation ?? 0.0), scale: \(updatedItem.scale ?? 1.0)")
            
            // Replace the item in the whiteboard
            whiteboard?.items[index] = updatedItem
            
            // Double-check the change took effect
            let checkScale = whiteboard?.items[index].scale
            let checkRotation = whiteboard?.items[index].rotation
            print("   After replacement - rotation: \(checkRotation ?? 0.0), scale: \(checkScale ?? 1.0)")
            
            // Save immediately after any update
            print("   Calling saveWhiteboard() now")
            saveWhiteboard()
            
            // Verify the scale one more time after save
            let finalCheck = whiteboard?.items[index].scale
            print("   Final model check - scale: \(finalCheck ?? 1.0)\n")
        } else {
            print("❌ Failed to find item \(id) in whiteboard")
        }
    }
    
    // Auto-save the whiteboard after changes
    private func debounceAutoSave() {
        // Cancel previous save task if it exists
        autoSaveTask?.cancel()
        
        // Create a new save task
        let task = DispatchWorkItem {
            print("⏱️ Auto-save timer fired - saving whiteboard")
            self.saveWhiteboard()
        }
        
        // Schedule the save task after a short delay (0.5 seconds)
        autoSaveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: task)
        
        // Also save directly on app going to background
        // Use NotificationCenter publisher instead of Objective-C selector
        // We'll handle this in onReceive in the body
    }
    
    // Function to save the whiteboard and update the widget
    private func saveWhiteboard() {
        guard let board = whiteboard else { return }
        
        print("\n💾 SAVE WHITEBOARD CALLED")
        
        // Create a copy of the whiteboard to ensure we don't lose any data
        var boardToSave = board
        
        // Debug ALL items before doing anything
        for (index, item) in boardToSave.items.enumerated() {
            print("   Item \(index) BEFORE save: id=\(item.id), position=\(item.position), rotation=\(item.rotation ?? 0.0), scale=\(item.scale ?? 1.0)")
        }
        
        // Validate all items before saving
        for (index, item) in boardToSave.items.enumerated() {
            print("📝 Processing item \(item.id) for save:")
            
            // Double-check with itemStates to ensure we have the most up-to-date scale
            if let currentState = itemStates[item.id] {
                print("   Found matching state with scale: \(currentState.scale)")
                
                // If state scale differs from model scale, use state scale
                if item.scale != currentState.scale {
                    print("⚠️ Scale mismatch - itemState:\(currentState.scale) vs item:\(item.scale ?? 1.0) - using itemState value")
                    boardToSave.items[index].scale = currentState.scale
                }
            } else {
                print("   No matching state found for this item")
            }
            
            // Ensure rotation is valid
            if let rotation = item.rotation, (rotation.isNaN || rotation.isInfinite) {
                print("⚠️ Fixed invalid rotation: \(rotation)")
                boardToSave.items[index].rotation = 0.0
            } else if item.rotation == nil {
                print("⚠️ Setting nil rotation to 0.0")
                boardToSave.items[index].rotation = 0.0
            }
            
            // Ensure scale is valid and never nil
            if let scale = item.scale {
                if scale.isNaN || scale.isInfinite || scale <= 0.0 {
                    print("⚠️ Fixed invalid scale: \(scale)")
                    boardToSave.items[index].scale = 1.0
                }
            } else {
                print("⚠️ Setting nil scale to 1.0")
                boardToSave.items[index].scale = 1.0
            }
            
            // Final check before saving
            print("✅ Item after validation: rotation=\(boardToSave.items[index].rotation ?? 0.0), scale=\(boardToSave.items[index].scale ?? 1.0)")
        }
        
        // Update the whiteboard with validated data
        print("   Updating whiteboard reference")
        whiteboard = boardToSave
        
        // Debug ALL items one more time
        for (index, item) in whiteboard!.items.enumerated() {
            print("   Item \(index) AFTER processing: id=\(item.id), rotation=\(item.rotation ?? 0.0), scale=\(item.scale ?? 1.0)")
        }
        
        // Save to storage
        print("   Calling dataService.updateWhiteboard()")
        dataService.updateWhiteboard(boardToSave)
        
        // Update widget
        WidgetCenter.shared.reloadAllTimelines()
        print("💾 SAVE WHITEBOARD COMPLETE\n")
    }
    
    // Load or create a whiteboard for this group
    private func loadOrCreateWhiteboard() {
        isLoading = true
        
        // Check if there's already a whiteboard for this group
        if let existingBoard = dataService.getWhiteboardForGroup(groupId: group.id) {
            print("Found existing whiteboard for group \(group.id) with \(existingBoard.items.count) items")
            
            // Debug: Log each item's properties
            for (index, item) in existingBoard.items.enumerated() {
                print("Loading item \(index): id=\(item.id), type=\(item.type), position=\(item.position), rotation=\(item.rotation ?? 0), scale=\(item.scale ?? 1.0)")
            }
            
            whiteboard = existingBoard
            initializeItemStates()
            isLoading = false
        } else {
            // Create a new whiteboard for this group
            let newBoard = Whiteboard(
                id: group.id, // Use group ID as whiteboard ID for easy mapping
                name: group.name,
                items: [],
                members: [dataService.currentUser?.id ?? ""],
                createdAt: Date()
            )
            
            print("Created new whiteboard for group \(group.id)")
            whiteboard = newBoard
            dataService.updateWhiteboard(newBoard)
            initializeItemStates()
            isLoading = false
        }
    }
    
    // Add an image to the whiteboard
    private func addImageToWhiteboard(_ image: UIImage) {
        guard whiteboard != nil else { return }
        
        // Generate a unique ID for the image
        let imageId = UUID().uuidString
        let fileName = "whiteboard_image_\(imageId).jpg"
        
        // Save image to the documents directory
        if let imageData = image.jpegData(compressionQuality: 0.8),
           let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            // Create a URL for the image file
            let fileURL = documentDirectory.appendingPathComponent(fileName)
            
            // Write the image data to the file
            do {
                try imageData.write(to: fileURL)
                
                // Create a new whiteboard item that references the saved image
                let newItem = WhiteboardItem(
                    type: .image,
                    content: "local_photo:\(fileName)", // Store the filename in the content
                    createdBy: dataService.currentUser?.name ?? "You",
                    position: CGPoint(x: canvasWidth/2, y: canvasHeight/2),
                    rotation: 0.0,  // Explicitly setting rotation to 0
                    scale: 1.0      // Explicitly setting scale to 1
                )
                
                print("📷 Creating new image item with scale: \(newItem.scale ?? 1.0)")
                whiteboard?.items.append(newItem)
                
                // Update the view state with the new item
                DispatchQueue.main.async {
                    let newState = BoardItemState(
                        position: newItem.position,
                        rotation: newItem.rotation ?? 0,
                        scale: newItem.scale ?? 1.0
                    )
                    itemStates[newItem.id] = newState
                    
                    // Select the new item
                    selectedItem = newItem.id
                }
                
                // Save the whiteboard
                saveWhiteboard()
            } catch {
                print("Error saving image: \(error)")
            }
        }
    }
    
    // Function to add a text item at a specific location
    private func addTextItem(_ text: String, at position: CGPoint) {
        guard whiteboard != nil else { return }
        
        let newItem = WhiteboardItem(
            type: .text,
            content: text,
            createdBy: dataService.currentUser?.name ?? "You",
            position: position,
            rotation: 0.0,  // Explicitly setting rotation to 0
            scale: 1.0      // Explicitly setting scale to 1
        )
        
        whiteboard?.items.append(newItem)
        
        // Update the view state with the new item
        DispatchQueue.main.async {
            let newState = BoardItemState(
                position: newItem.position,
                rotation: newItem.rotation ?? 0,
                scale: newItem.scale ?? 1.0
            )
            itemStates[newItem.id] = newState
            
            // Select the new item
            selectedItem = newItem.id
        }
        
        // Save the whiteboard
        saveWhiteboard()
    }
    
    // Function to delete an item from the whiteboard
    private func deleteItem(_ item: WhiteboardItem) {
        // Remove the item from the whiteboard
        if let index = whiteboard?.items.firstIndex(where: { $0.id == item.id }) {
            whiteboard?.items.remove(at: index)
            
            // Update the view state
            DispatchQueue.main.async {
                itemStates.removeValue(forKey: item.id)
                if selectedItem == item.id {
                    selectedItem = nil
                }
            }
            
            // Save the whiteboard
            saveWhiteboard()
        }
    }
}

// Model to track item transformation state
class BoardItemState: ObservableObject {
    @Published var position: CGPoint
    @Published var rotation: CGFloat
    @Published var scale: CGFloat
    
    init(position: CGPoint, rotation: CGFloat = 0, scale: CGFloat = 1.0) {
        print("🏗️ Creating BoardItemState with position: \(position), rotation: \(rotation), scale: \(scale)")
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
    
    // Clone this state
    func copy() -> BoardItemState {
        return BoardItemState(position: position, rotation: rotation, scale: scale)
    }
}

// An interactive item that can be dragged, rotated, and scaled
struct BoardInteractiveItem: View {
    let item: WhiteboardItem
    let isSelected: Bool
    let state: BoardItemState
    let onSelect: () -> Void
    let onUpdate: (BoardItemState) -> Void
    @State private var showDeleteConfirm = false
    
    // Allow deleting items
    var onDelete: (() -> Void)?
    
    // Gesture state
    @GestureState private var dragState = CGSize.zero
    @GestureState private var rotationState: Angle = .zero
    @GestureState private var scaleState: CGFloat = 1.0
    
    // For tracking local gestures
    @State private var currentScale: CGFloat = 1.0
    @State private var lastSavedScale: CGFloat = 1.0
    
    var body: some View {
        BoardItemContent(item: item, scale: state.scale)
            .rotationEffect(Angle(degrees: state.rotation) + rotationState)
            .scaleEffect(currentScale)
            .overlay(selectionOverlay)
            .position(positionWithDrag)
            .onAppear {
                // Initialize scale tracking variables
                self.currentScale = state.scale
                self.lastSavedScale = state.scale
            }
            .onChange(of: state.scale) { oldScale, newScale in
                // Update tracking variables when scale changes externally
                self.currentScale = newScale
                self.lastSavedScale = newScale
            }
            .gesture(tapGesture)
            .gesture(longPressGesture)
            .simultaneousGesture(dragGesture)
            .simultaneousGesture(rotationGesture)
            .simultaneousGesture(magnificationGesture)
    }
    
    // MARK: - Computed Properties
    
    private var positionWithDrag: CGPoint {
        return CGPoint(
            x: state.position.x + dragState.width,
            y: state.position.y + dragState.height
        )
    }
    
    @ViewBuilder
    private var selectionOverlay: some View {
        ZStack {
            // Selection outline
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            
            // Delete button
            if isSelected && showDeleteConfirm {
                VStack {
                    Button(action: {
                        onDelete?()
                    }) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Circle().fill(Color.red))
                            .shadow(radius: 2)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(5)
            }
        }
    }
    
    // MARK: - Gestures
    
    private var tapGesture: some Gesture {
        TapGesture()
            .onEnded {
                onSelect()
                // Hide delete button when tapped
                showDeleteConfirm = false
            }
    }
    
    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                onSelect() // Select the item
                showDeleteConfirm = true // Show delete button
            }
    }
    
    private var dragGesture: some Gesture {
        DragGesture()
            .updating($dragState) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                // Create a new position
                let newPosition = CGPoint(
                    x: state.position.x + value.translation.width,
                    y: state.position.y + value.translation.height
                )
                
                // Create a new state preserving rotation and scale
                let updatedState = BoardItemState(
                    position: newPosition,
                    rotation: state.rotation,
                    scale: lastSavedScale
                )
                
                // Update the state
                onUpdate(updatedState)
            }
    }
    
    private var rotationGesture: some Gesture {
        RotationGesture()
            .updating($rotationState) { value, state, _ in
                state = value
            }
            .onEnded { value in
                // Calculate new rotation
                let newRotation = state.rotation + value.degrees
                
                // Create a new state preserving position and scale
                let updatedState = BoardItemState(
                    position: state.position,
                    rotation: newRotation,
                    scale: lastSavedScale
                )
                
                // Update the state
                onUpdate(updatedState)
            }
    }
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                // Update the current scale in real-time
                currentScale = lastSavedScale * value
            }
            .onEnded { value in
                // Calculate final scale
                let newScale = lastSavedScale * value
                
                // Apply limits and ensure positive scale
                let limitedScale = max(0.1, newScale)
                
                // Update the current scale tracking variables
                currentScale = limitedScale
                lastSavedScale = limitedScale
                
                // Save the scale to our data model
                let updatedState = BoardItemState(
                    position: state.position,
                    rotation: state.rotation,
                    scale: limitedScale
                )
                
                onUpdate(updatedState)
            }
    }
}

// Content view for whiteboard items
struct BoardItemContent: View {
    let item: WhiteboardItem
    let scale: CGFloat
    
    var body: some View {
        contentForType()
    }
    
    @ViewBuilder
    private func contentForType() -> some View {
        switch item.type {
        case .text:
            Text(item.content)
                .font(.system(size: 16 * scale, design: .monospaced))
                .padding(8)
                .background(Color.white.opacity(0.7))
                .cornerRadius(4)
            
        case .image:
            imageContent()
            
        case .drawing:
            // Placeholder for drawing type
            Text("Drawing: \(item.content)")
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color.yellow.opacity(0.3))
                .cornerRadius(4)
        }
    }
    
    @ViewBuilder
    private func imageContent() -> some View {
        if item.content.hasPrefix("local_photo:") {
            // Extract filename from content
            let filename = String(item.content.dropFirst("local_photo:".count))
            
            // Load image from local storage
            if let image = loadImageFromDisk(filename: filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 150 * scale)
                    .cornerRadius(4)
            } else {
                // Fallback if image can't be loaded
                Text("Image not found")
                    .font(.system(.caption, design: .monospaced))
                    .padding(8)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(4)
            }
        } else {
            // Fallback
            Text("Unknown image")
                .font(.system(.caption, design: .monospaced))
                .padding(8)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
        }
    }
    
    // Load image from local storage
    private func loadImageFromDisk(filename: String) -> UIImage? {
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentDirectory.appendingPathComponent(filename)
            return UIImage(contentsOfFile: fileURL.path)
        }
        return nil
    }
}

// Reusable action button
struct ActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                
                Text(title)
                    .font(.system(.caption, design: .monospaced))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black, lineWidth: 1)
            )
        }
        .foregroundColor(.black)
    }
}

struct BoardDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            BoardDetailView(
                group: Group(
                    id: "1",
                    name: "Project Planning",
                    createdBy: "user1",
                    createdAt: "2025-04-20T15:30:00Z"
                )
            )
            .environmentObject(DataService())
        }
    }
} 
