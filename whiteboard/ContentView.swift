//
//  ContentView.swift
//  whiteboard
//
//  Created by alec on 3/26/25.
//

import SwiftUI
import AuthenticationServices

struct ContentView: View {
    @EnvironmentObject private var dataService: DataService
    
    var body: some View {
        Group {
            if dataService.currentUser != nil {
                MainView()
            } else {
                AuthView()
            }
        }
        .onAppear {
            print("ContentView appeared - checking for existing session")
            Task {
                await checkForExistingSession()
            }
        }
    }
    
    func checkForExistingSession() async {
        print("checkForExistingSession started")
        do {
            print("Attempting to get Supabase session...")
            // Check for existing session using async call
            let session = try await SupabaseManager.shared.client.auth.session
            print("Session response received: \(session != nil ? "Session exists" : "No session")")
            
            if session != nil {
                // Session exists, get user details
                print("User ID: \(session.user.id.uuidString)")
                print("User Email: \(session.user.email ?? "No email")")
                
                let userId = session.user.id.uuidString
                let userEmail = session.user.email
                // Create a user object based on session info
                dataService.currentUser = User(id: userId, name: userEmail ?? "User")
                print("User logged in: \(userId)")
            } else {
                // No session, ensure user is nil
                print("No valid session found, setting currentUser to nil")
                dataService.currentUser = nil
            }
        } catch {
            // Error checking session, ensure user is nil
            print("Error getting session: \(error.localizedDescription)")
            print("Full error: \(error)")
            dataService.currentUser = nil
        }
        print("checkForExistingSession completed")
    }
}

struct AuthView: View {
    @EnvironmentObject private var dataService: DataService
    
    @State private var phoneNumber = ""
    @State private var otpCode = ""
    @State private var isCodeSent = false
    @State private var statusMessage: String?
    @State private var isLoading = false
    
    
    // 3) Request OTP
    func sendOTP() async {
        do {
            print("sending!")
            isLoading = true
            statusMessage = nil
            try await SupabaseManager.shared.client.auth.signInWithOTP(phone: phoneNumber)
            isLoading = false
            isCodeSent = true
            print("sent")
        } catch {
            print("couldn't sent message")
        }
    }
    
    // 4) Verify OTP
    func verifyOTP() async {
        isLoading = true
        do {
            let response = try await SupabaseManager.shared.client.auth.verifyOTP(
                phone: phoneNumber,
                token: otpCode,
                type: .sms
            )
            
            print(response.user)
        } catch {
            print("couldn't verify phone")
        }
        statusMessage = nil
        isLoading = false
    }
    
    var body: some View {
            VStack(spacing: 20) {
                Text("Boardroom Login")
                    .font(.largeTitle)
                
                if !isCodeSent {
                    TextField("Phone (+19548043257)", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Send OTP") {
                        Task { await sendOTP() }
                    }
                    .disabled(isLoading || phoneNumber.isEmpty)
                } else {
                    TextField("Enter OTP", text: $otpCode)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    Button("Verify & Sign In") {
                        Task { await verifyOTP() }
                    }
                    .disabled(isLoading || otpCode.count != 6)
                }
                
                if let msg = statusMessage {
                    Text(msg)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
            }
            .onAppear {
                let session = SupabaseManager.shared.client.auth.currentSession
                print(session)
            }
            .padding()
//        VStack(spacing: 20) {
//            Spacer()
//            
//            // Welcome image from the screenshots
//            ZStack {
//                RoundedRectangle(cornerRadius: 20)
//                    .fill(Color.white)
//                    .shadow(radius: 5)
//                
//                VStack {
//                    Text("welcome to")
//                        .font(.subheadline)
//                    Text("boardroom")
//                        .font(.title3)
//                        .fontWeight(.semibold)
//                }
//                
//                // Images as shown in the screenshot would go here
//                // These would be actual image assets in a real app
//            }
//            .frame(width: 300, height: 300)
//            .padding()
//            
//            Spacer()
//            
//            // Simple continue button instead of Sign in with Apple
//            Button(action: {
//                // Create a simple guest user
//                dataService.signInWithApple(appleIdentifier: "guest-\(UUID().uuidString)", name: "Guest")
//            }) {
//                Text("Continue")
//                    .font(.headline)
//                    .foregroundColor(.white)
//                    .frame(maxWidth: .infinity)
//                    .padding()
//                    .background(
//                        Capsule()
//                            .fill(Color.blue)
//                    )
//            }
//            .padding(.horizontal, 40)
//            
//            Spacer()
//                .frame(height: 50)
//        }
    }
}

struct MainView: View {
    @EnvironmentObject private var dataService: DataService
    
    var body: some View {
        TabView {
            WhiteboardsView()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Boards")
                }
            
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
        }
    }
}

struct WhiteboardsView: View {
    @EnvironmentObject private var dataService: DataService
    @State private var showingCreateSheet = false
    @State private var newBoardName = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(dataService.whiteboards) { board in
                        NavigationLink(destination: WhiteboardDetailView(board: board)) {
                            WhiteboardThumbnail(board: board)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Add new whiteboard button
                    CreateWhiteboardCell()
                        .onTapGesture {
                            showingCreateSheet = true
                        }
                }
                .padding()
            }
            .navigationTitle("Whiteboards")
            .sheet(isPresented: $showingCreateSheet) {
                CreateWhiteboardView { name in
                    let _ = dataService.createWhiteboard(name: name)
                    showingCreateSheet = false
                }
            }
        }
    }
}

struct WhiteboardThumbnail: View {
    let board: Whiteboard
    
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .overlay(
                    VStack {
                        if let firstItem = board.items.first {
                            switch firstItem.type {
                            case .image:
                                if firstItem.content.starts(with: "http") {
                                    AsyncImage(url: URL(string: firstItem.content)) { image in
                                        image.resizable().aspectRatio(contentMode: .fit)
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .padding()
                                } else {
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                        .padding()
                                }
                            case .text:
                                Text(firstItem.content)
                                    .padding()
                            case .drawing:
                                Text("Drawing")
                                    .padding()
                            }
                        } else {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                )
                .aspectRatio(1, contentMode: .fit)
            
            Text(board.name)
                .font(.subheadline)
        }
    }
}

struct CreateWhiteboardCell: View {
    var body: some View {
        VStack {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                .overlay(
                    Image(systemName: "plus")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                )
                .aspectRatio(1, contentMode: .fit)
            
            Text("add new")
                .font(.subheadline)
        }
    }
}

struct CreateWhiteboardView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var boardName = ""
    var onCreate: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Whiteboard Name", text: $boardName)
                    .padding()
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.3)))
                    .padding()
                
                Button("Create Whiteboard") {
                    if !boardName.isEmpty {
                        onCreate(boardName)
                    }
                }
                .disabled(boardName.isEmpty)
                .padding()
                .foregroundColor(.white)
                .background(boardName.isEmpty ? Color.gray : Color.blue)
                .cornerRadius(8)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Create New Whiteboard")
            .navigationBarItems(
                trailing: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var dataService: DataService
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Account")) {
                    if let user = dataService.currentUser {
                        Text("Name: \(user.name)")
                    }
                    
                    Button("Sign Out") {
                        Task {
                            // Sign out from Supabase
                            do {
                                try await SupabaseManager.shared.client.auth.signOut()
                                print("Successfully signed out from Supabase")
                            } catch {
                                print("Error signing out from Supabase: \(error)")
                            }
                            
                            // Clear the current user to return to login screen
                            dataService.currentUser = nil
                            dataService.signOut()
                            
                            // No need to navigate elsewhere - the app root will handle it
                            // when it detects currentUser is nil
                        }
                    }
                    .foregroundColor(.red)
                }
                
                Section(header: Text("About")) {
                    Text("boardroom")
                    Text("Version 1.0")
                }
            }
            .navigationTitle("Settings")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(DataService())
    }
}
