import SwiftUI
import WidgetKit
import PhotosUI

struct WhiteboardDetailView: View {
    @EnvironmentObject private var dataService: DataService
    @State var board: Whiteboard
    @State private var showingAddItemSheet = false
    @State private var selectedItemType: WhiteboardItem.ItemType = .image
    @Environment(\.presentationMode) var presentationMode
    
    // State variables for item manipulation
    @State private var selectedItem: String? = nil
    @State private var itemStates: [String: ItemState] = [:]
    
    // Photo picker state
    @State private var isShowingPhotoPicker = false
    @State private var selectedImage: UIImage?
    
    // Add a state for direct text editing
    @State private var isAddingText = false
    @State private var newText = ""
    @State private var textPosition = CGPoint(x: 0, y: 0)
    @FocusState private var isTextFieldFocused: Bool
    
    // Instruction overlay state
    @State private var showInstructions = true
    
    // Canvas size - EXACTLY match large widget dimensions (338x354)
    // Now we'll make it responsive to screen size
    @State private var canvasWidth: CGFloat = 338
    @State private var canvasHeight: CGFloat = 354
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                // Use NavigationLink's back button instead
                Spacer()
                
                Text(board.name)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    // Update board before saving
                    saveWhiteboard()
                }) {
                    Text("save")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            
            // Whiteboard content area with Canvas
            GeometryReader { geometry in
                ZStack {
                    // Background container
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        .background(Color.white)
                        .frame(width: canvasWidth, height: canvasHeight)
                    
                    // Canvas for rendering items
                    Canvas { context, size in
                        // Draw a subtle grid for better positioning reference
                        drawGrid(context: context, size: size)
                        
                        // We still use ZStack for interaction, Canvas is just for rendering
                    } .frame(width: canvasWidth, height: canvasHeight)
                    
                    // Items that can be freely positioned, rotated, and scaled
                    ZStack {
                        ForEach(board.items) { item in
                            InteractiveItem(
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
                        
                        // Direct text input field
                        if isAddingText {
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
                    }
                    .frame(width: canvasWidth, height: canvasHeight)
                    .clipped()
                    
                    // Instructions overlay
                    if showInstructions {
                        VStack(spacing: 16) {
                            Text("How to use:")
                                .font(.headline)
                            
                            HStack(spacing: 16) {
                                VStack {
                                    Image(systemName: "hand.tap")
                                        .font(.system(size: 20))
                                    Text("Tap to select")
                                        .font(.caption)
                                }
                                
                                VStack {
                                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                        .font(.system(size: 20))
                                    Text("Drag to move")
                                        .font(.caption)
                                }
                            }
                            
                            HStack(spacing: 16) {
                                VStack {
                                    Image(systemName: "rotate.right")
                                        .font(.system(size: 20))
                                    Text("Two fingers\nto rotate")
                                        .font(.caption)
                                        .multilineTextAlignment(.center)
                                }
                                
                                VStack {
                                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                                        .font(.system(size: 20))
                                    Text("Pinch to scale")
                                        .font(.caption)
                                }
                            }
                            
                            Button("Got it") {
                                withAnimation {
                                    showInstructions = false
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(Color.blue)
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
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    let size = getCanvasDimensions(for: geometry.size.width)
                    canvasWidth = size.width
                    canvasHeight = size.height
                }
                .onChange(of: geometry.size) { newSize in
                    let size = getCanvasDimensions(for: newSize.width)
                    canvasWidth = size.width
                    canvasHeight = size.height
                }
            }
            .padding()
            .simultaneousGesture(
                // Tap gesture on the canvas to add text at that position
                TapGesture()
                    .onEnded { _ in
                        // If we're in text adding mode, tap to position the text field
                        if isAddingText {
                            // Text field is already visible
                        } else {
                            // Deselect any selected item when tapping on the canvas
                            if !isAddingText {
                                selectedItem = nil
                            }
                        }
                    }
            )
            
            // Bottom section for contributors
            HStack {
                ForEach(["You", "Alec", "Rebecca"], id: \.self) { name in
                    HStack {
                        Circle()
                            .fill(name == "You" ? Color.green : name == "Alec" ? Color.blue : Color.pink)
                            .frame(width: 8, height: 8)
                        Text(name)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
                
                Button(action: {
                    // Add contributor action
                }) {
                    HStack {
                        Text("+ add")
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().stroke(Color.gray.opacity(0.3), lineWidth: 1))
                }
            }
            .padding()
            
            // Bottom control section
            HStack(spacing: 0) {
                Spacer()
                
                Button(action: {
                    isShowingPhotoPicker = true
                }) {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 20))
                        Text("Photos")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
                
                Button(action: {
                    // Set the initial position for the text field to the center of the canvas
                    textPosition = CGPoint(x: canvasWidth/2, y: canvasHeight/2)
                    isAddingText = true
                    newText = ""
                }) {
                    VStack {
                        Image(systemName: "text.bubble")
                            .font(.system(size: 20))
                        Text("Text")
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                }
                
                Spacer()
            }
            .padding(.vertical, 10)
            .background(Color.white)
            .overlay(
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(Color.gray.opacity(0.3)),
                alignment: .top
            )
        }
        .navigationBarTitle("", displayMode: .inline)
        .sheet(isPresented: $showingAddItemSheet) {
            AddItemSheet(board: $board, itemType: selectedItemType, canvasCenter: CGPoint(x: canvasWidth/2, y: canvasHeight/2))
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            PhotoPicker(selectedImage: $selectedImage, onImageSelected: { image in
                addImageToWhiteboard(image)
            })
        }
        .onChange(of: selectedImage) { newImage in
            if let image = newImage {
                addImageToWhiteboard(image)
                // Reset selected image
                selectedImage = nil
            }
        }
        .onAppear {
            // Initialize item states
            initializeItemStates()
        }
    }
    
    // Draw a subtle grid on the canvas
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let gridSpacing: CGFloat = min(size.width, size.height) / 12 // Adapt grid spacing to canvas size
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
    
    // Initialize item states from board items
    private func initializeItemStates() {
        itemStates.removeAll()
        
        for item in board.items {
            let scaleValue = item.scale ?? 1.0
            let rotationValue = item.rotation ?? 0.0
            
            itemStates[item.id] = ItemState(
                position: item.position,
                rotation: rotationValue,
                scale: scaleValue
            )
            
            print("Initializing item \(item.id) with scale: \(scaleValue)")
        }
    }
    
    // Get or create a state for an item
    private func itemStateFor(_ item: WhiteboardItem) -> ItemState {
        if let state = itemStates[item.id] {
            return state
        } else {
            // Create state but update it outside of the rendering cycle
            DispatchQueue.main.async {
                let newState = ItemState(
                    position: item.position,
                    rotation: item.rotation ?? 0,
                    scale: item.scale ?? 1.0
                )
                self.itemStates[item.id] = newState
            }
            
            // Return a temporary state for this render cycle
            return ItemState(
                position: item.position,
                rotation: item.rotation ?? 0,
                scale: item.scale ?? 1.0
            )
        }
    }
    
    // Update the state for an item
    private func updateItemState(id: String, state: ItemState) {
        itemStates[id] = state
        
        // Update the item in our board model
        if let index = board.items.firstIndex(where: { $0.id == id }) {
            board.items[index].position = state.position
            board.items[index].rotation = state.rotation
            board.items[index].scale = state.scale
            
            // Trigger auto-save after a short delay
            debounceAutoSave()
        }
    }
    
    // Auto-save the whiteboard after changes
    @State private var autoSaveTask: DispatchWorkItem?
    private func debounceAutoSave() {
        // Cancel previous save task if it exists
        autoSaveTask?.cancel()
        
        // Create a new save task
        let task = DispatchWorkItem { [self] in
            self.saveWhiteboard()
        }
        
        // Schedule the save task after a short delay (1 second)
        autoSaveTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: task)
    }
    
    // Function to save the whiteboard and update the widget
    private func saveWhiteboard() {
        // Make this the most recent whiteboard so it shows in widget
        dataService.updateWhiteboard(board)
        
        // Force widget update
        WidgetCenter.shared.reloadAllTimelines()
    }
    
    // Add an image to the whiteboard
    private func addImageToWhiteboard(_ image: UIImage) {
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
                    content: "local_photo:\(fileName)",  // Store the filename in the content
                    createdBy: dataService.currentUser?.name ?? "You",
                    position: CGPoint(x: canvasWidth/2, y: canvasHeight/2),
                    rotation: 0.0,
                    scale: 1.0
                )
                
                board.items.append(newItem)
                
                // Update the view state with the new item
                DispatchQueue.main.async {
                    let newState = ItemState(
                        position: newItem.position,
                        rotation: newItem.rotation ?? 0,
                        scale: newItem.scale ?? 1.0
                    )
                    itemStates[newItem.id] = newState
                    
                    // Select the new item
                    selectedItem = newItem.id
                }
                
                // Save the board
                saveWhiteboard()
            } catch {
                print("Error saving image: \(error)")
            }
        }
    }
    
    // Function to delete an item from the whiteboard
    private func deleteItem(_ item: WhiteboardItem) {
        // Remove the item from the board
        if let index = board.items.firstIndex(where: { $0.id == item.id }) {
            board.items.remove(at: index)
            
            // Update the view state
            DispatchQueue.main.async {
                self.itemStates.removeValue(forKey: item.id)
                if self.selectedItem == item.id {
                    self.selectedItem = nil
                }
            }
            
            // Save the board
            saveWhiteboard()
        }
    }
    
    // Function to add a text item at a specific location
    private func addTextItem(_ text: String, at position: CGPoint) {
        let newItem = WhiteboardItem(
            type: .text,
            content: text,
            createdBy: dataService.currentUser?.name ?? "You",
            position: position,
            rotation: 0.0,
            scale: 1.0
        )
        
        board.items.append(newItem)
        
        // Update the view state with the new item
        DispatchQueue.main.async {
            let newState = ItemState(
                position: newItem.position,
                rotation: newItem.rotation ?? 0,
                scale: newItem.scale ?? 1.0
            )
            itemStates[newItem.id] = newState
            
            // Select the new item
            selectedItem = newItem.id
        }
        
        // Save the board
        saveWhiteboard()
    }
}

// Model to track item transformation state
class ItemState: ObservableObject {
    @Published var position: CGPoint
    @Published var rotation: CGFloat
    @Published var scale: CGFloat
    
    init(position: CGPoint, rotation: CGFloat = 0, scale: CGFloat = 1.0) {
        self.position = position
        self.rotation = rotation
        self.scale = scale
    }
}

// An interactive item that can be dragged, rotated, and scaled
struct InteractiveItem: View {
    let item: WhiteboardItem
    let isSelected: Bool
    let state: ItemState
    let onSelect: () -> Void
    let onUpdate: (ItemState) -> Void
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
        ItemContent(item: item, scale: state.scale)
            .rotationEffect(Angle(degrees: state.rotation) + rotationState)
            .scaleEffect(currentScale)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .overlay(
                // Delete button appears when selected
                Group {
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
            )
            .position(CGPoint(
                x: state.position.x + dragState.width,
                y: state.position.y + dragState.height
            ))
            .onAppear {
                self.currentScale = state.scale
                self.lastSavedScale = state.scale
            }
            .onChange(of: state.scale) { newScale in
                self.currentScale = newScale
                self.lastSavedScale = newScale
            }
            .gesture(
                TapGesture()
                    .onEnded {
                        onSelect()
                        // Hide delete button when tapped
                        showDeleteConfirm = false
                    }
            )
            // Add long press gesture for delete
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        onSelect() // Select the item
                        showDeleteConfirm = true // Show delete button
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .updating($dragState) { value, state, _ in
                        state = value.translation
                    }
                    .onEnded { value in
                        let newPosition = CGPoint(
                            x: state.position.x + value.translation.width,
                            y: state.position.y + value.translation.height
                        )
                        onUpdate(ItemState(
                            position: newPosition,
                            rotation: state.rotation,
                            scale: lastSavedScale
                        ))
                        // Hide delete after dragging
                        showDeleteConfirm = false
                    }
            )
            .simultaneousGesture(
                RotationGesture()
                    .updating($rotationState) { value, state, _ in
                        state = value
                    }
                    .onEnded { value in
                        let newRotation = state.rotation + CGFloat(value.degrees)
                        onUpdate(ItemState(
                            position: state.position,
                            rotation: newRotation,
                            scale: lastSavedScale
                        ))
                    }
            )
            .simultaneousGesture(
                MagnificationGesture()
                    .onChanged { value in
                        // Update the current scale in real-time
                        currentScale = lastSavedScale * value
                    }
                    .onEnded { value in
                        // Calculate final scale
                        let newScale = lastSavedScale * value
                        
                        // Apply limits
                        let limitedScale = min(max(newScale, 0.3), 3.0)
                        
                        // Update the current scale
                        currentScale = limitedScale
                        lastSavedScale = limitedScale
                        
                        // Save the scale to our data model
                        onUpdate(ItemState(
                            position: state.position,
                            rotation: state.rotation,
                            scale: limitedScale
                        ))
                    }
            )
            .animation(.interactiveSpring(), value: isSelected)
    }
}

// Content for different item types
struct ItemContent: View {
    let item: WhiteboardItem
    let scale: CGFloat
    @State private var localImage: UIImage?
    
    var body: some View {
        switch item.type {
        case .image:
            if item.content.starts(with: "http") {
                AsyncImage(url: URL(string: item.content)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 150, height: 150)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
            } else if item.content.starts(with: "local_photo:") {
                // Display local photo
                if let image = localImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 150, height: 150)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.1))
                            .frame(width: 150, height: 150)
                        
                        Image(systemName: "photo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 50, height: 50)
                            .foregroundColor(.gray)
                    }
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .onAppear {
                        loadLocalImage()
                    }
                }
            } else if item.content == "emoji_fire" {
                Text("🔥")
                    .font(.system(size: 60))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else if item.content == "emoji_dog" {
                Text("🐕")
                    .font(.system(size: 60))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else if item.content == "emoji_monkey" {
                Text("🐒")
                    .font(.system(size: 60))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else if item.content == "emoji_party" {
                Text("🎉")
                    .font(.system(size: 60))
                    .frame(width: 80, height: 80)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 150, height: 150)
                    .foregroundColor(.gray)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            }
            
        case .text:
            Text(item.content)
                .font(.body)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            
        case .drawing:
            Text("Drawing: \(item.content)")
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private func loadLocalImage() {
        // Extract the filename from the content
        if item.content.starts(with: "local_photo:"),
           let fileName = item.content.split(separator: ":").last,
           let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            
            let fileURL = documentDirectory.appendingPathComponent(String(fileName))
            
            // Check if the file exists
            if FileManager.default.fileExists(atPath: fileURL.path),
               let image = UIImage(contentsOfFile: fileURL.path) {
                self.localImage = image
            }
        }
    }
}

struct AddItemSheet: View {
    @Binding var board: Whiteboard
    @EnvironmentObject private var dataService: DataService
    let itemType: WhiteboardItem.ItemType
    let canvasCenter: CGPoint
    
    @State private var text = ""
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            HStack {
                Text("Add \(itemType.rawValue)")
                    .font(.headline)
                Spacer()
                Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
            .padding()
            
            if itemType == .text {
                TextField("Enter text...", text: $text)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                    .padding()
                
                Button("Add Text") {
                    let newItem = WhiteboardItem(
                        type: .text,
                        content: text,
                        createdBy: dataService.currentUser?.name ?? "You",
                        position: canvasCenter,
                        rotation: 0.0,
                        scale: 1.0
                    )
                    board.items.append(newItem)
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(text.isEmpty)
                .padding()
                .foregroundColor(.white)
                .background(text.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(8)
                .padding()
            } else if itemType == .image {
                VStack {
                    HStack {
                        Button(action: {
                            // Camera action would go here in a real app
                        }) {
                            HStack {
                                Image(systemName: "camera")
                                Text("Camera")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    HStack {
                        Button(action: {
                            // Photo library action would go here in a real app
                        }) {
                            HStack {
                                Image(systemName: "photo")
                                Text("Photos or Videos...")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                    
                    // For demo purposes, we'll add some predefined items
                    ScrollView(.horizontal) {
                        HStack(spacing: 20) {
                            Button(action: {
                                addDemoItem("emoji_fire")
                            }) {
                                Text("🔥")
                                    .font(.system(size: 60))
                            }
                            
                            Button(action: {
                                addDemoItem("emoji_dog")
                            }) {
                                Text("🐕")
                                    .font(.system(size: 60))
                            }
                            
                            Button(action: {
                                addDemoItem("emoji_monkey")
                            }) {
                                Text("🐒")
                                    .font(.system(size: 60))
                            }
                            
                            Button(action: {
                                addDemoItem("emoji_party")
                            }) {
                                Text("🎉")
                                    .font(.system(size: 60))
                            }
                        }
                        .padding()
                    }
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .padding()
                }
            } else if itemType == .drawing {
                Text("Drawing functionality coming soon")
                    .padding()
            }
            
            Spacer()
        }
    }
    
    private func addDemoItem(_ content: String) {
        let newItem = WhiteboardItem(
            type: .image,
            content: content,
            createdBy: dataService.currentUser?.name ?? "You",
            position: canvasCenter,
            rotation: 0.0,
            scale: 1.0
        )
        board.items.append(newItem)
        presentationMode.wrappedValue.dismiss()
    }
}

struct WhiteboardDetailView_Previews: PreviewProvider {
    static var previews: some View {
        WhiteboardDetailView(board: Whiteboard(name: "NYC homies"))
            .environmentObject(DataService())
    }
} 
