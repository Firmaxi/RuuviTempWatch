import SwiftUI
import Security

struct SettingsView: View {
    @EnvironmentObject var apiClient: RuuviAPIClient
    @Environment(\.dismiss) var dismiss
    
    @State private var accessToken = ""
    @State private var macAddress = ""
    @State private var isLoading = false
    @State private var showSuccessMessage = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Ruuvi Cloud -asetukset")) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Access Token")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Bearer token", text: $accessToken)
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
                
                Section {
                    Button(action: {
                        Task {
                            await saveSettings()
                        }
                    }) {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Tallenna")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .foregroundColor(.white)
                    .listRowBackground(Color.blue)
                    .disabled(isLoading)
                }
                
                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
                
                if showSuccessMessage {
                    Section {
                        Text("Asetukset tallennettu!")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Section(footer: VStack(alignment: .leading, spacing: 5) {
                    Text("Nykyinen anturi: \(apiClient.macAddress)")
                    Text("Gateway: \(apiClient.baseURL)")
                        .font(.caption2)
                }) {
                    // Empty section for footer
                }
            }
            .navigationTitle("Asetukset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Peruuta") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentSettings()
            }
        }
    }
    
    private func loadCurrentSettings() {
        // Load access token from Keychain
        if let token = loadFromKeychain(key: "ruuvi_access_token") {
            accessToken = token
        }
        
        // Load MAC address from UserDefaults
        macAddress = UserDefaults.standard.string(forKey: "ruuvi_mac_address") ?? ""
    }
    
    private func saveSettings() async {
        guard !accessToken.isEmpty && isValidMacAddress(macAddress) else {
            errorMessage = "Täytä molemmat kentät oikein"
            return
        }
        
        isLoading = true
        errorMessage = nil
        showSuccessMessage = false
        
        defer { isLoading = false }
        
        do {
            // Save to storage
            try saveToKeychain(key: "ruuvi_access_token", value: accessToken)
            UserDefaults.standard.set(macAddress, forKey: "ruuvi_mac_address")
            
            // Update API client
            await MainActor.run {
                apiClient.accessToken = accessToken
                apiClient.macAddress = macAddress
            }
            
            // Test the connection
            try await apiClient.fetchTemperature()
            
            // Success
            showSuccessMessage = true
            
            // Dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                dismiss()
            }
        } catch {
            if let apiError = error as? RuuviAPIClient.APIError {
                switch apiError {
                case .unauthorized:
                    errorMessage = "Virheellinen Access Token"
                case .forbidden:
                    errorMessage = "Ei oikeuksia anturiin"
                case .gatewayNotFound:
                    errorMessage = "Gateway ei vastaa"
                case .rateLimited:
                    errorMessage = "Liikaa pyyntöjä"
                case .networkError(let message):
                    errorMessage = "Verkkovirhe: \(message)"
                case .invalidData:
                    errorMessage = "Virheellinen data"
                case .serverError:
                    errorMessage = "Palvelin ei vastaa"
                }
            } else {
                errorMessage = "Virhe: \(error.localizedDescription)"
            }
        }
    }
    
    private func isValidMacAddress(_ mac: String) -> Bool {
        let pattern = "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$"
        return mac.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ruuvitempwatch",
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
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
    SettingsView()
        .environmentObject(RuuviAPIClient())
}