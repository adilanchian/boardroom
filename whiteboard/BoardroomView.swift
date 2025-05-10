import SwiftUI

struct BoardroomView: View {
    let boardroom: Boardroom
    
    @StateObject private var boardroomVM = BoardroomViewModel()
    @State private var selectedItemId: String? = nil
    @State private var isAddingText = false
    @State private var newText = ""
    @State private var textPosition = CGPoint(x: 0, y: 0)
    @FocusState private var isTextFieldFocused: Bool
    
    // Canvas size
    @State private var canvasWidth: CGFloat = 340
    @State private var canvasHeight: CGFloat = 360
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "E8E9E2").ignoresSafeArea()
            
            VStack(spacing: 20) {
                // Header section
                boardHeaderView
                
                // Main content
                if boardroomVM.isLoading {
                    loadingView
                } else {
                    // Boardroom canvas
                    canvasView
                }
                
                // Action buttons
                actionButtonsView
            }
        }
        .alert(isPresented: Binding<Bool>(
            get: { boardroomVM.errorMessage != nil },
            set: { if !$0 { boardroomVM.errorMessage = nil } }
        )) {
            Alert(
                title: Text("Error"),
                message: Text(boardroomVM.errorMessage ?? "Unknown error"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            // Load boardroom when view appears
            boardroomVM.loadBoardroom(id: boardroom.id)
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
            let formattedDate = formatDateFromDate(boardroom.createdAt)
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
                
                // Text input overlay
                if isAddingText {
                    textInputOverlay
                }
                
                // Instructions overlay
                if boardroomVM.boardroom?.items.isEmpty ?? true {
                    instructionsOverlay
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                let size = getCanvasDimensions(for: geometry.size.width)
                canvasWidth = size.width
                canvasHeight = size.height
            }
            .onChange(of: geometry.size) { _, newSize in
                let size = getCanvasDimensions(for: newSize.width)
                canvasWidth = size.width
                canvasHeight = size.height
            }
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    // Deselect any selected item when tapping on the canvas
                    if !isAddingText {
                        selectedItemId = nil
                    }
                }
        )
        .padding(.horizontal)
        .frame(maxHeight: .infinity)
    }
    
    private var itemsContainerView: some View {
        ZStack {
            // Boardroom items
            if let boardroom = boardroomVM.boardroom {
                ForEach(boardroom.items) { item in
                    BoardroomItemView(
                        item: item,
                        isSelected: selectedItemId == item.id,
                        onSelected: { selectedItemId = item.id },
                        onPositionChanged: { newPosition in
                            boardroomVM.updateItemPosition(id: item.id, position: newPosition)
                        },
                        onRotationChanged: { newRotation in
                            boardroomVM.updateItemRotation(id: item.id, rotation: newRotation)
                        },
                        onScaleChanged: { newScale in
                            boardroomVM.updateItemScale(id: item.id, scale: newScale)
                        },
                        onDelete: {
                            boardroomVM.deleteItem(id: item.id)
                        }
                    )
                }
            }
        }
    }
    
    private var actionButtonsView: some View {
        HStack(spacing: 20) {
            // Add text button
            Button(action: {
                textPosition = CGPoint(x: canvasWidth / 2, y: canvasHeight / 2)
                isAddingText = true
                isTextFieldFocused = true
            }) {
                VStack {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 20))
                    Text("Text")
                        .font(.caption)
                }
                .frame(width: 60, height: 60)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 3)
            }
            
            // Add image button (implementation will be added later)
            Button(action: {
                // Will implement in the next phase
            }) {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 20))
                    Text("Image")
                        .font(.caption)
                }
                .frame(width: 60, height: 60)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 3)
                .opacity(0.5) // Disabled for now
            }
            .disabled(true)
            
            // Save button
            Button(action: {
                boardroomVM.saveBoardroom()
            }) {
                VStack {
                    Image(systemName: "arrow.down.doc")
                        .font(.system(size: 20))
                    Text("Save")
                        .font(.caption)
                }
                .frame(width: 60, height: 60)
                .background(Color.white)
                .cornerRadius(10)
                .shadow(color: Color.black.opacity(0.1), radius: 3)
            }
        }
        .padding(.bottom, 30)
    }
    
    private var textInputOverlay: some View {
        VStack {
            TextField("Enter text", text: $newText)
                .padding()
                .background(Color.white)
                .cornerRadius(8)
                .shadow(radius: 3)
                .focused($isTextFieldFocused)
                .position(textPosition)
                .frame(width: 200)
            
            HStack {
                Button("Cancel") {
                    isAddingText = false
                    newText = ""
                }
                .padding()
                
                Button("Add") {
                    if !newText.isEmpty {
                        boardroomVM.addTextItem(text: newText, position: textPosition)
                        isAddingText = false
                        newText = ""
                    }
                }
                .padding()
                .disabled(newText.isEmpty)
            }
            .background(Color.white)
            .cornerRadius(8)
            .shadow(radius: 3)
            .position(x: canvasWidth / 2, y: canvasHeight - 40)
        }
    }
    
    private var instructionsOverlay: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.system(size: 30))
                .foregroundColor(.gray)
            
            Text("Tap the buttons below to add content")
                .font(.system(.body, design: .monospaced))
                .multilineTextAlignment(.center)
                .foregroundColor(.gray)
                .padding(.horizontal)
        }
    }
    
    private var backButton: some View {
        Button(action: {
            // Save before navigating back
            boardroomVM.saveBoardroom()
            // Navigate back
            UINavigationBar.setAnimationsEnabled(false)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                UINavigationBar.setAnimationsEnabled(true)
            }
        }) {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.black)
        }
    }
    
    private var saveButton: some View {
        Button(action: {
            boardroomVM.saveBoardroom()
        }) {
            Text("Save")
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.black)
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ dateString: String) -> String {
        // Convert string date to a readable format
        guard let date = ISO8601DateFormatter().date(from: dateString) else {
            return "recently"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // New function to handle Date objects directly
    private func formatDateFromDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func getCanvasDimensions(for width: CGFloat) -> (width: CGFloat, height: CGFloat) {
        // Calculate canvas dimensions while maintaining aspect ratio
        let maxWidth: CGFloat = min(width - 32, 500)
        let aspectRatio: CGFloat = 1.05 // Portrait orientation: height is 5% more than width
        
        return (width: maxWidth, height: maxWidth * aspectRatio)
    }
    
    private func drawGrid(context: GraphicsContext, size: CGSize) {
        // Draw a subtle grid in the background for positioning reference
        let gridSpacing: CGFloat = 20
        let lineColor = Color.gray.opacity(0.1)
        
        for x in stride(from: 0, through: size.width, by: gridSpacing) {
            let path = Path { p in
                p.move(to: CGPoint(x: x, y: 0))
                p.addLine(to: CGPoint(x: x, y: size.height))
            }
            context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
        }
        
        for y in stride(from: 0, through: size.height, by: gridSpacing) {
            let path = Path { p in
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(path, with: .color(lineColor), lineWidth: 0.5)
        }
    }
}

// A view to display a boardroom item with interactive controls
struct BoardroomItemView: View {
    let item: BoardroomItem
    let isSelected: Bool
    let onSelected: () -> Void
    let onPositionChanged: (CGPoint) -> Void
    let onRotationChanged: (Double) -> Void
    let onScaleChanged: (Double) -> Void
    let onDelete: () -> Void
    
    // Gesture state
    @GestureState private var dragOffset: CGSize = .zero
    @GestureState private var rotationAngle: Angle = .zero
    @GestureState private var scaleAmount: CGFloat = 1.0
    
    // Local state tracking
    @State private var position: CGPoint
    @State private var rotation: Double
    @State private var scale: Double
    
    // Constants
    private let deleteButtonSize: CGFloat = 24
    private let rotateButtonSize: CGFloat = 24
    private let controlsOffset: CGFloat = 12
    
    init(
        item: BoardroomItem,
        isSelected: Bool,
        onSelected: @escaping () -> Void,
        onPositionChanged: @escaping (CGPoint) -> Void,
        onRotationChanged: @escaping (Double) -> Void,
        onScaleChanged: @escaping (Double) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.item = item
        self.isSelected = isSelected
        self.onSelected = onSelected
        self.onPositionChanged = onPositionChanged
        self.onRotationChanged = onRotationChanged
        self.onScaleChanged = onScaleChanged
        self.onDelete = onDelete
        
        // Initialize local state from item
        _position = State(initialValue: item.position)
        _rotation = State(initialValue: item.rotation)
        _scale = State(initialValue: item.scale)
    }
    
    var body: some View {
        ZStack {
            // Item content
            itemContent
                .position(CGPoint(
                    x: position.x + dragOffset.width,
                    y: position.y + dragOffset.height
                ))
                .rotationEffect(Angle(degrees: rotation) + rotationAngle)
                .scaleEffect(scale * scaleAmount)
                .gesture(
                    DragGesture()
                        .updating($dragOffset) { value, state, _ in
                            state = value.translation
                        }
                        .onEnded { value in
                            let newPosition = CGPoint(
                                x: position.x + value.translation.width,
                                y: position.y + value.translation.height
                            )
                            position = newPosition
                            onPositionChanged(newPosition)
                        }
                )
                .onTapGesture {
                    onSelected()
                }
            
            // Show controls when selected
            if isSelected {
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .frame(width: deleteButtonSize, height: deleteButtonSize)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                .position(
                    x: position.x - controlsOffset,
                    y: position.y - controlsOffset
                )
                
                // Rotation handle
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: rotateButtonSize, height: rotateButtonSize)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .position(
                        x: position.x + controlsOffset,
                        y: position.y - controlsOffset
                    )
                    .gesture(
                        RotationGesture()
                            .updating($rotationAngle) { value, state, _ in
                                state = value
                            }
                            .onEnded { value in
                                rotation += value.degrees
                                onRotationChanged(rotation)
                            }
                    )
                
                // Scale handle
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(width: rotateButtonSize, height: rotateButtonSize)
                    .background(Color.green)
                    .clipShape(Circle())
                    .position(
                        x: position.x + controlsOffset,
                        y: position.y + controlsOffset
                    )
                    .gesture(
                        MagnificationGesture()
                            .updating($scaleAmount) { value, state, _ in
                                state = value
                            }
                            .onEnded { value in
                                scale *= Double(value)
                                onScaleChanged(scale)
                            }
                    )
            }
        }
    }
    
    // Render different item types
    private var itemContent: some View {
        Group {
            switch item.type {
            case .text:
                Text(item.content)
                    .font(.system(.body, design: .default))
                    .padding(8)
                    .background(Color.white)
                    .cornerRadius(4)
                    .shadow(color: Color.black.opacity(0.1), radius: 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
                
            case .image:
                // Image placeholder (will be implemented later)
                Text("Image")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
                
            case .drawing:
                // Drawing placeholder (will be implemented later)
                Text("Drawing")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(4)
            }
        }
    }
} 