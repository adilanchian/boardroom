//
//  widget.swift
//  widget
//
//  Created by alec on 3/26/25.
//

import WidgetKit
import SwiftUI

// The App Group identifier for sharing data with the main app
let appGroupIdentifier = "group.wndn.studio.boardroom"

// Key for accessing boardrooms in UserDefaults
let boardroomsKey = "saved_boardrooms"

// Get shared UserDefaults from the App Group
var sharedDefaults: UserDefaults {
    return UserDefaults(suiteName: appGroupIdentifier) ?? UserDefaults.standard
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> BoardroomEntry {
        BoardroomEntry(
            date: Date(),
            boardroom: Boardroom(
                name: "Example Board",
                items: [
                    BoardroomItem(
                        boardroomId: UUID().uuidString,
                        type: .text,
                        content: "Widget example",
                        position: CGPoint(x: 180, y: 180),
                        rotation: 0,
                        scale: 1.0,
                        createdBy: "System"
                    )
                ],
                createdBy: "System"
            ),
            displaySize: context.displaySize
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BoardroomEntry) -> ()) {
        // Use try-catch for better error handling
        let entry: BoardroomEntry
        
        do {
            // Try to get the latest boardroom from shared UserDefaults
            if let data = sharedDefaults.data(forKey: boardroomsKey) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let boardrooms = try decoder.decode([Boardroom].self, from: data)
                if !boardrooms.isEmpty {
                    // Use the first boardroom (most recently updated one)
                    entry = BoardroomEntry(date: Date(), boardroom: boardrooms[0], displaySize: context.displaySize)
                } else {
                    entry = placeholder(in: context)
                }
            } else {
                entry = placeholder(in: context)
            }
        } catch {
            print("Widget error: \(error)")
            entry = placeholder(in: context)
        }
        
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let currentDate = Date()
        // Update every 15 minutes (more reasonable for widgets)
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        
        let entry: BoardroomEntry
        
        do {
            // Try to get the latest boardroom from shared UserDefaults
            if let data = sharedDefaults.data(forKey: boardroomsKey) {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let boardrooms = try decoder.decode([Boardroom].self, from: data)
                if !boardrooms.isEmpty {
                    // Use the first boardroom (most recently updated one)
                    entry = BoardroomEntry(date: currentDate, boardroom: boardrooms[0], displaySize: context.displaySize)
                } else {
                    entry = placeholder(in: context)
                }
            } else {
                entry = placeholder(in: context)
            }
        } catch {
            print("Widget error: \(error)")
            entry = placeholder(in: context)
        }
        
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }
}

struct BoardroomEntry: TimelineEntry {
    let date: Date
    let boardroom: Boardroom
    let displaySize: CGSize
}

struct BoardroomWidgetEntryView : View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        // For large widget only
        if family == .systemLarge {
            let size = getWidgetDimensions(for: entry.displaySize)
            
            ZStack {
                // Grid for reference
                Canvas { context, canvasSize in
                    drawGrid(context: context, size: canvasSize)
                }
                
                // Items positioned using their relative coordinates in the widget
                ZStack {
                    ForEach(entry.boardroom.items) { item in
                        // Debug log for each item
                        let _ = print("Widget showing item: id=\(item.id), position=\(item.position), rotation=\(item.rotation), scale=\(item.scale)")
                        
                        WidgetItemView(item: item)
                            .position(item.position)
                            .rotationEffect(Angle(degrees: Double(item.rotation)))
                            .scaleEffect(item.scale)
                    }
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped() // Ensure content stays within bounds
        } else {
            // For other widget sizes, we'll use a scaled approach
            Text("Use large widget for best experience")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    // Get exact widget dimensions based on display size
    private func getWidgetDimensions(for size: CGSize) -> CGSize {
        // Default to smallest Large widget size
        var width: CGFloat = 292
        var height: CGFloat = 311
        
        // Match dimensions from our table based on the display size
        if size.width >= 364 && size.height >= 382 {
            // 430x932 or 428x926 screens
            width = 364
            height = 382
        } else if size.width >= 360 && size.height >= 379 {
            // 414x896 screens
            width = 360
            height = 379
        } else if size.width >= 348 && size.height >= 357 {
            // 414x736 screens
            width = 348
            height = 357
        } else if size.width >= 338 && size.height >= 354 {
            // 393x852 or 390x844 screens
            width = 338
            height = 354
        } else if size.width >= 329 && size.height >= 345 {
            // 375x812 or 360x780 screens
            width = 329
            height = 345
        } else if size.width >= 321 && size.height >= 324 {
            // 375x667 screens
            width = 321
            height = 324
        }
        
        return CGSize(width: width, height: height)
    }
    
    // Draw a subtle grid on the canvas matching the app's grid
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
}

struct WidgetItemView: View {
    let item: BoardroomItem
    
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
            } else if item.content.starts(with: "local_photo:") {
                // Show a placeholder for local photos in the widget
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                    
                    Image(systemName: "photo")
                        .font(.system(size: 30))
                        .foregroundColor(.gray)
                }
                .frame(width: 150, height: 150)
            } else if item.content == "emoji_fire" {
                Text("🔥")
                    .font(.system(size: 60))
            } else if item.content == "emoji_dog" {
                Text("🐕")
                    .font(.system(size: 60))
            } else if item.content == "emoji_monkey" {
                Text("🐒")
                    .font(.system(size: 60))
            } else if item.content == "emoji_party" {
                Text("🎉")
                    .font(.system(size: 60))
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 30))
                    .foregroundColor(.gray)
            }
            
        case .text:
            Text(item.content)
                .font(.system(size: 14))
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            
        case .drawing:
            Text("Drawing")
                .font(.system(size: 14))
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
        }
    }
}

struct widget: Widget {
    let kind: String = "BoardroomWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                BoardroomWidgetEntryView(entry: entry)
                    .containerBackground(.white, for: .widget)
            } else {
                BoardroomWidgetEntryView(entry: entry)
                    .background(Color.white)
            }
        }
        .configurationDisplayName("Boardroom")
        .description("See your boardroom exactly as you created it.")
        .supportedFamilies([.systemLarge]) // Only support large widget for perfect 1:1 mapping
    }
}

struct widget_Previews: PreviewProvider {
    static var previews: some View {
        // Preview for large widget only
        BoardroomWidgetEntryView(
            entry: BoardroomEntry(
                date: Date(),
                boardroom: Boardroom(
                    name: "hi sam",
                    items: [
                        BoardroomItem(
                            boardroomId: UUID().uuidString,
                            type: .text,
                            content: "hi becky",
                            position: CGPoint(x: 260, y: 140),
                            rotation: 0,
                            scale: 1.0,
                            createdBy: "You"
                        ),
                        BoardroomItem(
                            boardroomId: UUID().uuidString,
                            type: .image,
                            content: "local_photo:example.jpg",
                            position: CGPoint(x: 180, y: 180),
                            rotation: 0,
                            scale: 1.0,
                            createdBy: "System"
                        )
                    ],
                    createdBy: "You"
                ),
                displaySize: CGSize(width: 338, height: 354)
            )
        )
        .previewContext(WidgetPreviewContext(family: .systemLarge))
        .previewDisplayName("Large Widget (338×354)")
    }
}
