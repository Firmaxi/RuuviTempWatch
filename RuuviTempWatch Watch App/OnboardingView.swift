import SwiftUI
import Security

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject var apiClient: RuuviAPIClient
    
    @State private var accessToken = ""
    @State private var macAddress = "EF:AF:84:20:B1:82"
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome message
                    VStack(spacing: 10) {
                        Image(systemName: "thermometer.medium")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("Tervetuloa RuuviTempiin")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Syötä Ruuvi Cloud -tunnuksesi")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Input fields
                    VStack(spacing: 15) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Access Token")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("Bearer token", text: $accessToken)
                                .textContentType(.oneTimeCode)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                        }
                        
                        VStack(alignment: .leading, spacing: 5) {
                            Text("MAC-osoite")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("XX:XX:XX:XX:XX:XX", text: $macAddress)
                                .textContentType(.oneTimeCode)
                                .textInputAutocapitalization(.characters)
                                .disableAutocorrection(true)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Error message
                    if let errorMessage = errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Continue button
                    Button(action: {
                        Task {
                            await saveAndContinue()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Jatka")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isFormValid ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .disabled(!isFormValid || isLoading)
                    
                    // Info text
                    VStack(spacing: 5) {
                    Text("Access token tallennetaan turvallisesti Keychainiin")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                            
                            Text("Ruuvi Cloud API")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal)
                }
            }
            .navigationTitle("Asetukset")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var isFormValid: Bool {
        !accessToken.isEmpty && isValidMacAddress(macAddress)
    }
    
    private func isValidMacAddress(_ mac: String) -> Bool {
        let pattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        return mac.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func saveAndContinue() async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        // Save to Keychain
        do {
            try saveToKeychain(key: "ruuvi_access_token", value: accessToken)
            UserDefaults.standard.set(macAddress, forKey: "ruuvi_mac_address")
            
            // Update API client
            await MainActor.run {
                apiClient.accessToken = accessToken
                apiClient.macAddress = macAddress
            }
            
            // Test the connection
            try await apiClient.fetchTemperature()
            
            // Success - complete onboarding
            hasCompletedOnboarding = true
        } catch {
            if let apiError = error as? RuuviAPIClient.APIError {
                switch apiError {
                case .unauthorized:
                    errorMessage = "Virheellinen Access Token"
                case .forbidden:
                    errorMessage = "Ei oikeuksia anturiin"
                case .serverError:
                    errorMessage = "Palvelin ei vastaa"
                case .rateLimited:
                    errorMessage = "Liikaa pyyntöjä, yritä hetken kuluttua"
                case .networkError(let message):
                    errorMessage = "Verkkovirhe: \(message)"
                case .invalidData:
                    errorMessage = "Virheellinen data palvelimelta"
                case .gatewayNotFound:
                    errorMessage = "Gateway-laitetta ei löydy verkosta"
                }
            } else {
                errorMessage = "Tuntematon virhe: \(error.localizedDescription)"
            }
        }
    }
    
    private func saveToKeychain(key: String, value: String) throws {
        let data = value.data(using: .utf8)!
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ruuvitempwatch",
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unableToStore
        }
    }
    
    enum KeychainError: Error {
        case unableToStore
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
        .environmentObject(RuuviAPIClient())
}