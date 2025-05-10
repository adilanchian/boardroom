import SwiftUI
import Supabase

struct VerificationCodeView: View {
    @State private var verificationCode: String = ""
    @State private var phoneNumber: String
    @State private var countryCode: String
    @State private var currentPage: Int = 2
    @State private var totalPages: Int = 3
    @State private var navigateToNextScreen: Bool = false
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String? = nil
    @State private var navigateToGroupCreation: Bool = false
    @EnvironmentObject private var dataService: DataService
    @Environment(\.presentationMode) var presentationMode
    
    private let textColor = Color(hex: "E8E9E2")
    
    init(phoneNumber: String, countryCode: String) {
        self._phoneNumber = State(initialValue: phoneNumber)
        self._countryCode = State(initialValue: countryCode)
    }
    
    var body: some View {
        ZStack {
            Color(hex: "E8E9E2")
                .ignoresSafeArea()
            
            VStack {
                // Top bar with back button and pagination
                HStack {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "arrow.left")
                            .foregroundStyle(textColor)
                            .font(.body)
                            .fontWeight(.medium)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(.black)
                            .clipShape(Capsule())
                    }
                    
                    Spacer()
                    
                    Text("\(currentPage)/\(totalPages)")
                        .foregroundStyle(.gray)
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.medium)
                }
                .padding(.top, 50)
                
                Spacer()
                
                // Question text
                Text("verify your number")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .padding(.bottom, 20)
                
                // Verification code input
                TextField("6 digit code", text: Binding(
                    get: { verificationCode },
                    set: { newValue in
                        let filtered = newValue.filter { $0.isNumber }
                        verificationCode = String(filtered.prefix(6))
                    }
                ))
                    .keyboardType(.numberPad)
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .padding()
                    .background(
                        Capsule()
                            .stroke(.black, lineWidth: 1)
                            .background(.clear)
                    )
                    .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // Continue button
                Button(action: {
                    Task { await verifyOTP() }
                }) {
                    if isVerifying {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    } else {
                        Text("verify")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(verificationCode.count < 6 ? .gray : .white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Capsule()
                        .stroke(.gray, lineWidth: 1)
                        .background(verificationCode.count < 6 ? .clear : .black)
                )
                .clipShape(Capsule())
                .padding(.horizontal)
                .padding(.bottom, 40)
                .disabled(verificationCode.count < 6 || isVerifying)
                .opacity((verificationCode.count < 6 || isVerifying) ? 0.7 : 1)
                
                NavigationLink(
                    destination: UsernameView()
                        .navigationBarHidden(true),
                    isActive: $navigateToNextScreen,
                    label: { EmptyView() }
                )
                .opacity(0)
                NavigationLink(
                    destination: GroupCreationView()
                        .navigationBarHidden(true)
                        .environmentObject(dataService),
                    isActive: $navigateToGroupCreation,
                    label: { EmptyView() }
                )
                .opacity(0)
            }
            .padding(.horizontal, 40)
        }
        .navigationBarHidden(true)
        .onAppear {
            print("Verification code screen for \(countryCode) \(phoneNumber)")
        }
    }
    
    func verifyOTP() async {
        isVerifying = true
        errorMessage = nil
        
        do {
            // Using existing OTP verification logic
            let formattedPhone = "\(countryCode)\(phoneNumber)"
            
            let response = try await SupabaseManager.shared.client.auth.verifyOTP(
                phone: formattedPhone,
                token: verificationCode,
                type: .sms
            )
            
            print("User verified: \(String(describing: response.user))")
            
            let authUser = response.user
            
            // After successful verification, check if the user already has a profile
            do {
                // Try to fetch the user's profile
                let userProfile = try await SupabaseManager.shared.fetchUserProfile()
                print("Existing profile found: \(userProfile.name)")
                
                // User has an existing profile, store it and mark onboarding as complete
                dataService.saveUser(userProfile, completeSetup: true)
                
                // Check if user has any boardrooms
                do {
                    let boardrooms = try await SupabaseManager.shared.getUserBoardrooms()
                    isVerifying = false
                    DispatchQueue.main.async {
                        if boardrooms.isEmpty {
                            // Navigate to GroupCreationView
                            navigateToGroupCreation = true
                        } else {
                            // User has boardrooms, complete onboarding and go to main
                            dataService.currentUser = userProfile
                            dataService.completeOnboarding()
                            NotificationCenter.default.post(name: NSNotification.Name("RefreshRootView"), object: nil)
                            self.presentationMode.wrappedValue.dismiss()
                        }
                    }
                } catch {
                    // Handle the recursion error (treat as if no boardrooms exist)
                    print("Error fetching boardrooms: \(error.localizedDescription)")
                    
                    if error.localizedDescription.contains("infinite recursion") {
                        print("Detected infinite recursion error in policy - treating as no boardrooms")
                        isVerifying = false
                        DispatchQueue.main.async {
                            // Navigate to GroupCreationView
                            navigateToGroupCreation = true
                        }
                    } else {
                        // For other errors, still go to group creation as fallback
                        isVerifying = false
                        DispatchQueue.main.async {
                            navigateToGroupCreation = true
                        }
                    }
                }
                return
            } catch let profileError as SupabaseError {
                // Check if this is specifically a "profile not found" error
                if case .profileNotFound = profileError {
                    // No profile found - this is a new user, proceed with username setup
                    print("No existing profile found. Proceeding to username setup.")
                    
                    // Set minimal user data for the onboarding flow
                    dataService.currentUser = User(id: authUser.id.uuidString, name: authUser.phone ?? "User")
                    dataService.onboardingComplete = false
                    
                    // Navigate to the username setup screen
                    isVerifying = false
                    navigateToNextScreen = true
                } else {
                    // Some other Supabase error
                    print("Error fetching profile: \(profileError.localizedDescription)")
                    handleProfileFetchError(user: authUser)
                }
            } catch {
                // Generic error during profile fetch
                print("Error fetching profile: \(error.localizedDescription)")
                handleProfileFetchError(user: authUser)
            }
        } catch {
            isVerifying = false
            errorMessage = "Invalid verification code. Please try again."
            print("Verification failed: \(error.localizedDescription)")
        }
    }
    
    // Helper to handle profile fetch errors consistently
    private func handleProfileFetchError(user: Supabase.User) {
        // Still create the user but don't complete onboarding yet
        // This ensures they go through username setup
        dataService.currentUser = User(id: user.id.uuidString, name: user.phone ?? "User")
        dataService.onboardingComplete = false
        
        isVerifying = false
        navigateToNextScreen = true
    }
}

struct VerificationCodeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            VerificationCodeView(phoneNumber: "9548043257", countryCode: "+1")
                .environmentObject(DataService())
        }
    }
} 
