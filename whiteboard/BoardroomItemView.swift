import SwiftUI
import UIKit
import Foundation

// Interactive, draggable, rotatable, scalable item view
struct BoardroomInteractiveItem: View {
    let item: BoardroomItem
    let isSelected: Bool
    let state: BoardItemState
    let onSelect: () -> Void
    let onUpdate: (BoardItemState) -> Void
    let onDelete: () -> Void
    
    // Gesture state
    @State private var dragOffset: CGSize = .zero
    @State private var lastDragValue: CGSize = .zero
    @State private var currentRotation: Angle = .zero
    @State private var lastRotation: Angle = .zero
    @State private var currentScale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        // The content view depends on the item type
        Group {
            switch item.type {
            case .text:
                textItemView
                
            case .image:
                imageItemView
                
            case .drawing:
                drawingItemView
            }
        }
        // Apply selection border if selected
        .overlay(
            isSelected ?
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 2)
                    .padding(-4)
            : nil
        )
        // Interface to handle core gestures
        .overlay(DeleteButton(isVisible: isSelected, action: onDelete), alignment: .topTrailing)
        .contentShape(Rectangle()) // Make the whole area tappable
        .onTapGesture {
            onSelect()
        }
        // Drag gesture
        .gesture(
            DragGesture(minimumDistance: 0.1, coordinateSpace: .global)
                .onChanged { value in
                    // Calculate new offset relative to the last known position
                    let translation = CGSize(
                        width: value.translation.width - lastDragValue.width,
                        height: value.translation.height - lastDragValue.height
                    )
                    
                    // Apply translation considering rotation
                    let angle = state.rotation * .pi / 180
                    let rotatedDx = translation.width * Darwin.cos(angle) - translation.height * Darwin.sin(angle)
                    let rotatedDy = translation.width * Darwin.sin(angle) + translation.height * Darwin.cos(angle)
                    
                    // Update the drag offset
                    dragOffset = CGSize(
                        width: dragOffset.width + rotatedDx,
                        height: dragOffset.height + rotatedDy
                    )
                    
                    // Save the last drag value
                    lastDragValue = value.translation
                    
                    // Calculate the new position
                    let newPosition = CGPoint(
                        x: state.position.x + translation.width,
                        y: state.position.y + translation.height
                    )
                    
                    // Update the state
                    onUpdate(BoardItemState(
                        position: newPosition,
                        rotation: state.rotation,
                        scale: state.scale
                    ))
                }
                .onEnded { _ in
                    // Reset drag tracking state for next drag
                    lastDragValue = .zero
                }
        )
        // Combined rotation and magnification gestures
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    let delta = value / lastScale
                    currentScale = delta
                    
                    // Update scale relative to current state
                    let newScale = state.scale * Double(currentScale)
                    
                    // Update state with new scale
                    onUpdate(BoardItemState(
                        position: state.position,
                        rotation: state.rotation,
                        scale: newScale
                    ))
                    
                    // Remember this value for next change
                    lastScale = value
                }
                .onEnded { _ in
                    // Reset scaling tracking for next gesture
                    lastScale = 1.0
                }
        )
        .simultaneousGesture(
            RotationGesture()
                .onChanged { angle in
                    // Calculate delta angle from last position
                    let delta = angle - lastRotation
                    currentRotation = delta
                    
                    // Convert to degrees
                    let deltaInDegrees = delta.degrees
                    
                    // Update rotation relative to current state
                    let newRotation = state.rotation + deltaInDegrees
                    
                    // Update state with new rotation
                    onUpdate(BoardItemState(
                        position: state.position,
                        rotation: newRotation,
                        scale: state.scale
                    ))
                    
                    // Remember this angle for next change
                    lastRotation = angle
                }
                .onEnded { _ in
                    // Reset rotation tracking for next gesture
                    lastRotation = .zero
                }
        )
    }
    
    // MARK: - Item Type Views
    
    // Text item view
    private var textItemView: some View {
        Text(item.content)
            .font(.system(size: 14 * CGFloat(state.scale)))
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
    
    // Image item view
    private var imageItemView: some View {
        Group {
            if item.content.starts(with: "http") {
                // Remote image
                AsyncImage(url: URL(string: item.content)) { image in
                    image.resizable().aspectRatio(contentMode: .fit)
                } placeholder: {
                    ProgressView()
                }
            } else if item.content.starts(with: "local_photo:") {
                // Local photo from library
                LocalImageView(imageId: item.content)
            } else if item.content == "emoji_fire" {
                Text("🔥")
                    .font(.system(size: 60 * CGFloat(state.scale)))
            } else if item.content == "emoji_dog" {
                Text("🐕")
                    .font(.system(size: 60 * CGFloat(state.scale)))
            } else if item.content == "emoji_monkey" {
                Text("🐒")
                    .font(.system(size: 60 * CGFloat(state.scale)))
            } else if item.content == "emoji_party" {
                Text("🎉")
                    .font(.system(size: 60 * CGFloat(state.scale)))
            } else {
                // Default placeholder
                Image(systemName: "photo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundColor(.gray)
            }
        }
        .frame(width: 150 * CGFloat(state.scale), height: 150 * CGFloat(state.scale))
    }
    
    // Drawing item view (placeholder)
    private var drawingItemView: some View {
        Text("Drawing")
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
    }
}

// Delete button shown when an item is selected
struct DeleteButton: View {
    let isVisible: Bool
    let action: () -> Void
    
    var body: some View {
        if isVisible {
            Button(action: action) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.red)
                    .background(Color.white.opacity(0.7))
                    .clipShape(Circle())
            }
            .offset(x: 10, y: -10)
            .contentShape(Rectangle())
            // Stop tap propagation to parent
            .onTapGesture {
                action()
            }
        }
    }
}

// Helper view to load images from local storage
struct LocalImageView: View {
    let imageId: String
    @State private var image: UIImage?
    
    var body: some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Placeholder while loading
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                    
                    Image(systemName: "photo")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
            }
        }
        .onAppear {
            // Try to load the image from storage
            if let storedImage = BoardroomUtility.getImage(fromIdentifier: imageId) {
                self.image = storedImage
            }
        }
    }
} 