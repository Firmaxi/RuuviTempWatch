// HUOM: Widget vaatii oman Extension-targetin toimiakseen!
// Tämä koodi on väliaikaisesti kommentoitu, koska widget ei voi olla samassa
// moduulissa pääsovelluksen kanssa (molemmat käyttäisivät @main-attribuuttia).
//
// Widgetin lisääminen:
// 1. Xcode: File → New → Target
// 2. Valitse: watchOS → Widget Extension
// 3. Nimi: RuuviTempWatchWidget
// 4. Siirrä tämä koodi uuteen targettiin
// 5. Poista kommentit

/*
import WidgetKit
import SwiftUI
import Security

struct TemperatureEntry: TimelineEntry {
    let date: Date
    let temperature: Double?
    let errorMessage: String?
}

// Simplified API client for widgets (without @MainActor)
class WidgetAPIClient {
    private let baseURL = "http://192.168.1.39"
    private let endpoint = "/history"
    
    func fetchTemperature(token: String, macAddress: String) async throws -> Double {
        let urlString = "\(baseURL)\(endpoint)"
        guard let url = URL(string: urlString) else {
            throw WidgetError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10.0
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WidgetError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw WidgetError.httpError(httpResponse.statusCode)
        }
        
        // Parse response
        struct GatewayResponse: Codable {
            let data: SensorData
            
            struct SensorData: Codable {
                let temperature: Double
                let mac: String
            }
        }
        
        let gatewayResponse = try JSONDecoder().decode(GatewayResponse.self, from: data)
        
        // Verify MAC address
        guard gatewayResponse.data.mac.uppercased() == macAddress.uppercased() else {
            throw WidgetError.wrongSensor
        }
        
        return gatewayResponse.data.temperature
    }
    
    enum WidgetError: LocalizedError {
        case invalidURL
        case invalidResponse
        case httpError(Int)
        case wrongSensor
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Virheellinen URL"
            case .invalidResponse:
                return "Virheellinen vastaus"
            case .httpError(let code):
                return "HTTP virhe \(code)"
            case .wrongSensor:
                return "Väärä anturi"
            }
        }
    }
}

struct TemperatureProvider: TimelineProvider {
    private let apiClient = WidgetAPIClient()
    
    func placeholder(in context: Context) -> TemperatureEntry {
        TemperatureEntry(date: Date(), temperature: 22.5, errorMessage: nil)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TemperatureEntry) -> ()) {
        let entry = TemperatureEntry(date: Date(), temperature: 22.5, errorMessage: nil)
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TemperatureEntry>) -> ()) {
        Task {
            var entries: [TemperatureEntry] = []
            let currentDate = Date()
            var fetchedTemperature: Double?
            var errorMessage: String?
            
            // Load credentials
            #if DEBUG
            // Kovakoodatut arvot kehitysvaiheessa
            let token = "dT5ObtUF/OV6lxhBE2EcxP+lgn715akLrn9Qe/TMTaE="
            let macAddress = "EF:AF:84:20:B1:82"
            #else
            // Production: lataa tallennuksesta
            let token = loadFromKeychain(key: "ruuvi_access_token") ?? ""
            let macAddress = UserDefaults.standard.string(forKey: "ruuvi_mac_address") ?? "EF:AF:84:20:B1:82"
            #endif
            
            // Fetch temperature
            if !token.isEmpty {
                do {
                    fetchedTemperature = try await apiClient.fetchTemperature(token: token, macAddress: macAddress)
                } catch {
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = "Ei tokenia"
            }
            
            // Create entry
            let entry = TemperatureEntry(
                date: currentDate,
                temperature: fetchedTemperature,
                errorMessage: errorMessage
            )
            entries.append(entry)
            
            // Schedule next update in 15 minutes
            let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
            let timeline = Timeline(entries: entries, policy: .after(nextUpdate))
            
            completion(timeline)
        }
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
}

struct TemperatureWidgetView: View {
    var entry: TemperatureProvider.Entry
    
    var body: some View {
        accessoryCircularView
    }
    
    var accessoryCircularView: some View {
        ZStack {
            // Background circle
            Circle()
                .fill(Color.black.opacity(0.2))
            
            if let error = entry.errorMessage {
                // Error state
                VStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                    
                    Text("Virhe")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
            } else if let temperature = entry.temperature {
                // Temperature display
                VStack(spacing: 0) {
                    Text("\(temperature, specifier: "%.1f")")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text("°C")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("Ulkoilma")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                // Loading state
                VStack(spacing: 2) {
                    Text("--.-")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    
                    Text("°C")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
        }
    }
}

@main
struct TemperatureWidget: Widget {
    let kind: String = "TemperatureWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TemperatureProvider()) { entry in
            TemperatureWidgetView(entry: entry)
        }
        .configurationDisplayName("RuuviTemp")
        .description("Näyttää RuuviTag-anturin lämpötilan")
        .supportedFamilies([.accessoryCircular])
    }
}

// Preview
struct TemperatureWidget_Previews: PreviewProvider {
    static var previews: some View {
        TemperatureWidgetView(entry: TemperatureEntry(
            date: Date(),
            temperature: 22.5,
            errorMessage: nil
        ))
        .previewContext(WidgetPreviewContext(family: .accessoryCircular))
    }
}
*/