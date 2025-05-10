import SwiftUI
import PhoneNumberKit

struct PhoneRegistrationView: View {
    @State private var phoneNumber: String = ""
    @State private var countryCode: String = "+1"
    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 2
    @State private var navigateToNextScreen: Bool = false
    @State private var isLoading: Bool = false
    @State private var statusMessage: String? = nil
    @EnvironmentObject private var dataService: DataService
    @Environment(\.presentationMode) var presentationMode
    
    private let textColor = Color(hex: "E8E9E2")
    
    enum CountryDial {
        /// +1, +44, etc → 🇺🇸, 🇬🇧, …
        static func flag(from dialCode: String) -> String {
            let digits = dialCode.filter { $0.isNumber }
            guard let code = Int(digits) else { return "🧐" }
            
            let phoneNumberKit = PhoneNumberUtility()
            guard let regions = phoneNumberKit.countries(withCode: UInt64(code)), 
                  let regionCode = regions.first else { 
                return "🧐" 
            }
            
            // Convert region code to flag emoji
            let base = UnicodeScalar("🇦").value - UnicodeScalar("A").value
            var flag = ""
            for scalar in regionCode.unicodeScalars {
                if !scalar.isASCII { continue }
                if let scalarValue = UnicodeScalar(base + scalar.value) {
                    flag.append(String(scalarValue))
                }
            }
            
            return flag.isEmpty ? "🧐" : flag
        }
    }
    
    // Current flag based on the country code
    private var currentFlag: String {
        return CountryDial.flag(from: countryCode)
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
                Text("what's your phone number?")
                    .font(.system(.subheadline, design: .monospaced))
                    .fontWeight(.medium)
                    .padding(.bottom, 20)
                
                // Phone number input field with editable country code
                HStack(spacing: 0) {
                    // Country flag and code
                    HStack(spacing: 4) {
                        Text(currentFlag)
                        TextField("+1", text: $countryCode)
                            .keyboardType(.numbersAndPunctuation)
                            .foregroundColor(.black)
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.medium)
                            .frame(width: 30)
                            .onChange(of: countryCode) { newValue in
                                // Ensure it starts with a plus
                                if !newValue.starts(with: "+") && !newValue.isEmpty {
                                    countryCode = "+" + newValue
                                }
                                
                                // When country code changes, reformat the phone number for the new region
                                if !phoneNumber.isEmpty {
                                    phoneNumber = formatPhoneNumberDisplay(phoneNumber)
                                }
                            }
                    }
                    
                    // Phone number
                    TextField("1573 7477428", text: $phoneNumber)
                        .keyboardType(.numberPad)
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .font(.system(.subheadline, design: .monospaced))
                        .fontWeight(.medium)
                        .padding(.leading, 4)
                        .onChange(of: phoneNumber) { newValue in
                            // Optional: Format the phone number as user types
                            phoneNumber = formatPhoneNumberDisplay(newValue)
                        }
                    
                    Spacer()
                }
                .padding()
                .background(
                    Capsule()
                        .stroke(.black, lineWidth: 1)
                        .background(.clear)
                )
                .padding(.horizontal)
                
                if let message = statusMessage {
                    Text(message)
                        .foregroundColor(.red)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(.top, 8)
                }
                
                Spacer()
                
                // Continue button
                Button(action: {
                    Task { await sendOTP() }
                }) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .gray))
                    } else {
                        Text("continue")
                            .font(.system(.subheadline, design: .monospaced))
                            .fontWeight(.medium)
                            .foregroundColor(phoneNumber.isEmpty ? .gray : .white)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    Capsule()
                        .stroke(.gray, lineWidth: 1)
                        .background(phoneNumber.isEmpty ? .clear : .black)
                )
                .clipShape(Capsule())
                .padding(.horizontal)
                .padding(.bottom, 40)
                .disabled(phoneNumber.isEmpty || isLoading)
                .opacity((phoneNumber.isEmpty || isLoading) ? 0.7 : 1)
                
                NavigationLink(
                    destination: VerificationCodeView(phoneNumber: formatPhoneNumberAPI(), countryCode: countryCode),
                    isActive: $navigateToNextScreen,
                    label: { EmptyView() }
                )
                .opacity(0)
            }
            .padding(.horizontal, 40)
        }
        .navigationBarHidden(true)
    }
    
    // Format phone number for display
    func formatPhoneNumberDisplay(_ number: String) -> String {
        // Create complete number with country code for better formatting
        let completeNumber = "\(countryCode) \(number)"
        
        // Use PartialFormatter with automatic region detection
        let formatter = PartialFormatter()
        let formattedNumber = formatter.formatPartial(completeNumber)
        
        // Strip out the country code portion if present
        if formattedNumber.hasPrefix(countryCode) {
            return formattedNumber.replacingOccurrences(of: countryCode, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // If the country code doesn't appear in the formatted result, just return the formatted number
        return formattedNumber
    }
    
    // Format phone number for API call
    func formatPhoneNumberAPI() -> String {
        return phoneNumber.filter { $0.isNumber }
    }
    
    // Function to initiate the OTP sending process using existing logic
    func sendOTP() async {
        isLoading = true
        statusMessage = nil
        
        do {
            // Format phone number with country code for API call
            let formattedPhone = "\(countryCode)\(formatPhoneNumberAPI())"
            print("Sending OTP to \(formattedPhone)")
            
            try await SupabaseManager.shared.client.auth.signInWithOTP(phone: formattedPhone)
            isLoading = false
            navigateToNextScreen = true
        } catch {
            isLoading = false
            statusMessage = "Could not send verification code. Please try again."
            print("couldn't send message: \(error.localizedDescription)")
        }
    }
}

// Preview provider
struct PhoneRegistrationView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PhoneRegistrationView()
                .environmentObject(DataService())
        }
    }
}
