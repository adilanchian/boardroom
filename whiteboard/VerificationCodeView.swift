import SwiftUI

struct VerificationCodeView: View {
    @State private var verificationCode: String = ""
    @State private var phoneNumber: String
    @State private var countryCode: String
    @State private var currentPage: Int = 2
    @State private var totalPages: Int = 2
    @State private var navigateToMainView: Bool = false
    @State private var isVerifying: Bool = false
    @State private var errorMessage: String? = nil
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
                    destination: MainView()
                        .navigationBarHidden(true),
                    isActive: $navigateToMainView,
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
            
            let user = response.user
            
            // Set the current user in DataService
            dataService.currentUser = User(id: user.id.uuidString, name: user.phone ?? "User")
            print("User created in DataService: \(user.id.uuidString)")
            
            
            // If verification is successful, navigate to the main view
            isVerifying = false
            navigateToMainView = true
            
        } catch {
            isVerifying = false
            errorMessage = "Invalid verification code. Please try again."
            print("Verification failed: \(error.localizedDescription)")
        }
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
