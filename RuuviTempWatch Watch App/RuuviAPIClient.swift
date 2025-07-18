import Foundation
import SwiftUI
import Security

// MARK: - Helper structs for decoding Ruuvi Cloud response

/// Response from local gateway API (legacy endpoint)
private struct GatewayResponse: Codable {
    let data: GatewayData
    
    struct GatewayData: Codable {
        let mac: String
        let temperature: Double
        // Add other fields if needed
    }
}

/// Response from Ruuvi Cloud API
private struct CloudResponse: Codable {
    let result: String
    let data: CloudData?
    
    struct CloudData: Codable {
        let sensors: [CloudSensor]
    }
    
    struct CloudSensor: Codable {
        let sensor: String // MAC address
        let name: String
        let measurements: [CloudMeasurement]
        let offsetTemperature: Double?
        let offsetHumidity: Double?
        let offsetPressure: Double?
    }
    
    struct CloudMeasurement: Codable {
        let data: String // Hex-encoded data
        let rssi: Int
        let timestamp: Int
    }
}

/// RuuviAPIClient is an actor-isolated ObservableObject responsible for managing
/// communication with Ruuvi Cloud API over the internet.
/// - Note: All instance properties and methods are isolated to the main actor to ensure thread safety.
@MainActor
class RuuviAPIClient: ObservableObject {
    @Published var latestTemperature: Double?
    @Published var lastUpdateTime: Date?
    @Published var isLoading = false
    @Published var lastError: APIError?
    
    /// Access token used for API authentication.
    var accessToken: String = ""
    
    /// MAC address of the sensor.
    var macAddress: String = ""
    
    /// Base URL for Ruuvi Cloud API.
    var baseURL: String {
        return "https://network.ruuvi.com"
    }
    private let endpoint = "/sensors-dense?measurements=true"
    private let session = URLSession.shared
    
    // Additional sensor data from gateway
    @Published var humidity: Double?
    @Published var pressure: Double?
    @Published var battery: Double?
    @Published var rssi: Int?
    @Published var sensorName: String = "Anturi"
    
    enum APIError: LocalizedError {
        case unauthorized
        case forbidden
        case rateLimited
        case networkError(String)
        case invalidData
        case serverError
        case gatewayNotFound
        
        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "Virheellinen Access Token"
            case .forbidden:
                return "Ei oikeuksia anturiin"
            case .rateLimited:
                return "Liikaa pyyntöjä, yritä hetken kuluttua"
            case .networkError(let message):
                return "Verkkovirhe: \(message)"
            case .invalidData:
                return "Virheellinen data palvelimelta"
            case .serverError:
                return "Palvelin ei vastaa"
            case .gatewayNotFound:
                return "Gateway-laitetta ei löydy verkosta"
            }
        }
    }
    
    /// Initializes the client with hardcoded credentials.
    /// - Note: This initializer runs on main actor context.
    init() {
        #if DEBUG
        // Kovakoodatut arvot kehitysvaihetta varten - Ruuvi Cloud token
        self.accessToken = "753130313934/p9vdCYTTJDRxz5J3tmHfpgYm4J5ZlnGHrRqXshypwPyTm4sN3zkGrcp9vfcllvt5"
        self.macAddress = "EF:AF:84:20:B1:82"
        #else
        // Production: lataa Keychainista ja UserDefaultsista
        self.accessToken = loadFromKeychain(key: "ruuvi_access_token") ?? ""
        self.macAddress = UserDefaults.standard.string(forKey: "ruuvi_mac_address") ?? ""
        #endif
    }
    
    // HUOM: updateActiveSensor-metodi poistettu väliaikaisesti
    // koska RuuviSensor-tyyppiä ei ole määritelty tässä targetissa
    
    /// Asynchronously fetches temperature and sensor data from the gateway.
    /// - Throws: APIError for various failure cases.
    func fetchTemperature() async throws {
        print("🔐 Token: \(accessToken.prefix(10))...")
        print("📍 MAC: \(macAddress)")
        print("🌐 URL: \(baseURL)\(endpoint)")
        
        guard !accessToken.isEmpty else {
            throw APIError.unauthorized
        }
        
        isLoading = true
        defer { isLoading = false }
        
        let urlString = "\(baseURL)\(endpoint)"
        guard let url = URL(string: urlString) else {
            throw APIError.networkError("Invalid URL")
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 30.0 // Cloud API might need more time
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.networkError("Invalid response")
            }
            
            switch httpResponse.statusCode {
            case 200:
                print("✅ API vastasi 200 OK")
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📦 Raw JSON response:")
                    print(jsonString)
                    
                    // Pretty print JSON
                    if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                       let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
                       let prettyString = String(data: prettyData, encoding: .utf8) {
                        print("📦 Pretty JSON:")
                        print(prettyString)
                    }
                }
                try await parseCloudResponse(data: data)
            case 401:
                throw APIError.unauthorized
            case 403:
                throw APIError.forbidden
            case 404:
                throw APIError.serverError
            case 429:
                throw APIError.rateLimited
            default:
                throw APIError.networkError("HTTP \(httpResponse.statusCode)")
            }
        } catch let error as APIError {
            lastError = error
            throw error
        } catch {
            // Handle network errors
            if (error as NSError).code == NSURLErrorCannotConnectToHost {
                let apiError = APIError.serverError
                lastError = apiError
                throw apiError
            }
            
            let apiError = APIError.networkError(error.localizedDescription)
            lastError = apiError
            throw apiError
        }
    }
    
    /// Parses the JSON response from Ruuvi Cloud and updates published properties.
    /// - Parameter data: JSON data received from cloud.
    /// - Throws: APIError.invalidData if decoding fails or MAC address does not match.
    private func parseCloudResponse(data: Data) async throws {
        do {
            let response = try JSONDecoder().decode(CloudResponse.self, from: data)
            
            guard response.result == "success",
                  let cloudData = response.data else {
                throw APIError.invalidData
            }
            
            // Find the sensor with matching MAC address
            guard let sensor = cloudData.sensors.first(where: { 
                $0.sensor.uppercased() == macAddress.uppercased() 
            }) else {
                print("❌ Sensoria ei löydy MAC-osoitteella: \(macAddress)")
                throw APIError.invalidData
            }
            
            // Get the latest measurement
            guard let measurement = sensor.measurements.first else {
                print("❌ Ei mittauksia sensorille: \(sensor.name)")
                throw APIError.invalidData
            }
            
            print("🔍 DEBUG: Sensor data:")
            print("   - Name: \(sensor.name)")
            print("   - MAC: \(sensor.sensor)")
            print("   - Measurement count: \(sensor.measurements.count)")
            print("   - Raw hex data: \(measurement.data)")
            print("   - Data length: \(measurement.data.count) characters")
            
            // Parse hex data using HexParser
            let parsedData: HexParser.RuuviData
            do {
                parsedData = try HexParser.parseFullData(from: measurement.data)
            } catch {
                print("❌ Hex-datan parsinta epäonnistui: \(measurement.data)")
                print("❌ Virhe: \(error)")
                throw APIError.invalidData
            }
            
            // Apply offsets if available
            let offsetTemp = sensor.offsetTemperature ?? 0.0
            let offsetHum = sensor.offsetHumidity ?? 0.0
            let offsetPres = sensor.offsetPressure ?? 0.0
            
            print("🔧 Offsets - Temp: \(offsetTemp), Hum: \(offsetHum), Pres: \(offsetPres)")
            
            // Update published properties (already on main thread because class is @MainActor)
            self.latestTemperature = parsedData.temperature + offsetTemp
            self.humidity = parsedData.humidity + offsetHum
            self.pressure = parsedData.pressure + offsetPres // Already in hPa from parser
            self.battery = parsedData.battery
            self.rssi = measurement.rssi
            self.sensorName = sensor.name  // Päivitetään anturin nimi
            self.lastUpdateTime = Date(timeIntervalSince1970: TimeInterval(measurement.timestamp))
            self.lastError = nil
            
            print("🌡️ Lämpötila parsittu: \(parsedData.temperature) °C")
            print("💧 Kosteus: \(parsedData.humidity) %")
            print("🔋 Akku: \(self.battery ?? 0) V")
            print("🏕️ Sensori: \(sensor.name)")
            print("📊 Hex data: \(measurement.data)")
            print("🕰️ Timestamp: \(measurement.timestamp) = \(Date(timeIntervalSince1970: TimeInterval(measurement.timestamp)))")
            print("📡 RSSI: \(measurement.rssi) dBm")
            print("🌡️ Parsitut arvot - Lämpö: \(parsedData.temperature)°C, Kosteus: \(parsedData.humidity)%, Paine: \(parsedData.pressure) hPa")
            print("✅ LOPULLINEN LÄMPÖTILA (offsetin jälkeen): \(self.latestTemperature!) °C")
        } catch {
            throw APIError.invalidData
        }
    }
    
    /// Loads a string value from the keychain for the given key.
    /// - Parameter key: Key for the stored item.
    /// - Returns: The string value if found, otherwise nil.
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
    
    /// Synchronously fetches temperature from the gateway using passed-in parameters.
    /// This method does not access any instance properties and can be called without main actor isolation.
    ///
    /// - Parameters:
    ///   - accessToken: Access token to authorize the request.
    ///   - macAddress: MAC address of the sensor to verify response.
    ///   - baseURL: Base URL of the gateway API.
    /// - Returns: A tuple containing optional temperature and optional error.
    static func fetchTemperatureSync(accessToken: String, macAddress: String, baseURL: String) -> (Double?, Error?) {
        guard !accessToken.isEmpty else {
            return (nil, APIError.unauthorized)
        }
        
        let endpoint = "/history"
        let urlString = "\(baseURL)\(endpoint)"
        guard let url = URL(string: urlString) else {
            return (nil, APIError.networkError("Invalid URL"))
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var temperature: Double?
        var returnedError: Error?
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error as NSError? {
                if error.code == NSURLErrorCannotConnectToHost {
                    returnedError = APIError.gatewayNotFound
                    return
                }
                returnedError = APIError.networkError(error.localizedDescription)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                returnedError = APIError.networkError("Invalid response")
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                guard let data = data else {
                    returnedError = APIError.invalidData
                    return
                }
                
                do {
                    let response = try JSONDecoder().decode(GatewayResponse.self, from: data)
                    guard response.data.mac.uppercased() == macAddress.uppercased() else {
                        returnedError = APIError.invalidData
                        return
                    }
                    temperature = response.data.temperature
                } catch {
                    returnedError = APIError.invalidData
                }
            case 401:
                returnedError = APIError.unauthorized
            case 403:
                returnedError = APIError.forbidden
            case 404:
                returnedError = APIError.gatewayNotFound
            case 429:
                returnedError = APIError.rateLimited
            default:
                returnedError = APIError.networkError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        task.resume()
        _ = semaphore.wait(timeout: .now() + 15)
        
        return (temperature, returnedError)
    }
}