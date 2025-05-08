import SwiftUI
import Supabase

struct InviteView: View {
    let group: Group
    @Environment(\.dismiss) private var dismiss
    @State private var inviteEmail: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var successMessage: String? = nil
    @State private var groupMembers: [GroupMember] = []
    
    var body: some View {
        ZStack {
            Color(hex: "E8E9E2").ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                Text("invite members")
                    .font(.system(.headline, design: .monospaced))
                    .padding(.top)
                
                // Group info
                Text(group.name)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(.gray)
                
                // Email input
                VStack(alignment: .leading, spacing: 8) {
                    Text("enter user email")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                    
                    TextField("example@email.com", text: $inviteEmail)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .textContentType(.emailAddress)
                }
                .padding(.horizontal)
                
                // Status messages
                if let error = errorMessage {
                    Text(error)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.red)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                if let success = successMessage {
                    Text(success)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(.horizontal)
                        .multilineTextAlignment(.center)
                }
                
                // Invite button
                Button(action: inviteUser) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Text("send invite")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                Capsule()
                                    .fill(isInviteValid ? Color.black : Color.gray)
                            )
                    }
                }
                .disabled(!isInviteValid || isLoading)
                
                Divider()
                    .padding(.vertical)
                
                // Current members section
                VStack(alignment: .leading, spacing: 12) {
                    Text("current members")
                        .font(.system(.subheadline, design: .monospaced))
                        .bold()
                    
                    if groupMembers.isEmpty && !isLoading {
                        Text("No members yet")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.gray)
                            .padding(.vertical, 4)
                    } else if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    } else {
                        ForEach(groupMembers) { member in
                            HStack {
                                Text(member.userId)
                                    .font(.system(.caption, design: .monospaced))
                                
                                Spacer()
                                
                                Button(action: {
                                    removeMember(member)
                                }) {
                                    Image(systemName: "xmark.circle")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                Spacer()
                
                // Cancel button
                Button(action: {
                    dismiss()
                }) {
                    Text("done")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .stroke(Color.gray, lineWidth: 1)
                        )
                }
                .padding(.bottom)
            }
        }
        .task {
            await fetchGroupMembers()
        }
    }
    
    // Validation for the invite email
    private var isInviteValid: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailTest = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return !inviteEmail.isEmpty && emailTest.evaluate(with: inviteEmail)
    }
    
    // Fetch members of the group
    private func fetchGroupMembers() async {
        isLoading = true
        
        do {
            let members = try await SupabaseManager.shared.getGroupMembers(groupId: group.id)
            
            // Update UI on main thread
            await MainActor.run {
                groupMembers = members
                isLoading = false
            }
        } catch {
            // Handle error
            await MainActor.run {
                errorMessage = "Failed to load members: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    // Send invitation to the user
    private func inviteUser() {
        guard isInviteValid else { return }
        
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        Task {
            do {
                // Try to find the user by email
                if let userId = try await SupabaseManager.shared.getUserIdByEmail(inviteEmail) {
                    // User found, add them to the group
                    let success = try await SupabaseManager.shared.addMemberToGroup(
                        groupId: group.id,
                        userId: userId
                    )
                    
                    if success {
                        await MainActor.run {
                            successMessage = "Invitation sent to \(inviteEmail)"
                            inviteEmail = ""
                            isLoading = false
                        }
                        
                        // Refresh member list
                        await fetchGroupMembers()
                    }
                } else {
                    // User not found
                    await MainActor.run {
                        errorMessage = "User with email \(inviteEmail) not found"
                        isLoading = false
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to invite: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
    
    // Remove a member from the group
    private func removeMember(_ member: GroupMember) {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let success = try await SupabaseManager.shared.removeMemberFromGroup(
                    groupId: member.groupId,
                    userId: member.userId
                )
                
                if success {
                    // Refresh member list
                    await fetchGroupMembers()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to remove member: \(error.localizedDescription)"
                    isLoading = false
                }
            }
        }
    }
}

// Preview provider
struct InviteView_Previews: PreviewProvider {
    static var previews: some View {
        InviteView(
            group: Group(
                id: "1",
                name: "Project Planning",
                createdBy: "user1",
                createdAt: "2025-04-20T15:30:00Z"
            )
        )
    }
} 