import SwiftUI

struct BoardroomCard: View {
    let boardroom: Boardroom
    let onTap: () -> Void
    
    private let backgroundColor = Color(hex: "F5F5F5")
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(boardroom.name)
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.black)
                    Spacer()
                    
                    // Format date for display
                    Text(formatDate(boardroom.createdAt))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                // Bottom part: members count
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("You")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }
            .padding(16)
            .background(backgroundColor)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Format ISO date string to readable format
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
} 