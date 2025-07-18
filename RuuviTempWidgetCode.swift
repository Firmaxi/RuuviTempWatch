// RuuviTempWidget - Kopioi tämä koodi Widget Extensioniin
//
// HUOM: Tämä koodi vaatii oman Widget Extension targetin.
// Katso ohjeet: WIDGET_SETUP_GUIDE.md

import WidgetKit
import SwiftUI
import Security

struct TemperatureEntry: TimelineEntry {
    let date: Date
    let temperature: Double?
    let humidity: Double?
    let battery: Double?
    let errorMessage: String?
}

// Simplified API client for widgets (without @MainActor)
class WidgetAPIClient {
    private let baseURL = "http://192.168.1.39"
    private let endpoint = "/history"
    
    func fetchSensorData(token: String, macAddress: String) async throws -> SensorData {
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
        
        let gatewayResponse = try JSONDecoder().decode(GatewayResponse.self, from: data)
        
        // Verify MAC address
        guard gatewayResponse.data.mac.uppercased() == macAddress.uppercased() else {
            throw WidgetError.wrongSensor
        }
        
        return SensorData(
            temperature: gatewayResponse.data.temperature,
            humidity: gatewayResponse.data.humidity,
            battery: Double(gatewayResponse.data.battery) / 1000.0  // mV to V
        )
    }
    
    struct SensorData {
        let temperature: Double
        let humidity: Double
        let battery: Double
    }
    
    struct GatewayResponse: Codable {
        let data: GatewayData
        
        struct GatewayData: Codable {
            let temperature: Double
            let humidity: Double
            let battery: Int
            let mac: String
        }
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
                return "HTTP \(code)"
            case .wrongSensor:
                return "Väärä anturi"
            }
        }
    }
}

struct TemperatureProvider: TimelineProvider {
    private let apiClient = WidgetAPIClient()
    
    func placeholder(in context: Context) -> TemperatureEntry {
        TemperatureEntry(
            date: Date(),
            temperature: 22.5,
            humidity: 65.0,
            battery: 2.95,
            errorMessage: nil
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (TemperatureEntry) -> ()) {
        let entry = TemperatureEntry(
            date: Date(),
            temperature: 22.5,
            humidity: 65.0,
            battery: 2.95,
            errorMessage: nil
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<TemperatureEntry>) -> ()) {
        Task {
            var entries: [TemperatureEntry] = []
            let currentDate = Date()
            var sensorData: WidgetAPIClient.SensorData?
            var errorMessage: String?
            
            // Load credentials from shared configuration
            let userDefaults = UserDefaults(suiteName: "group.com.ruuvitempwatch") ?? UserDefaults.standard
            var token = ""
            var macAddress = ""
            
            if let configData = userDefaults.data(forKey: "ruuvi_configuration"),
               let config = try? JSONDecoder().decode(RuuviConfiguration.self, from: configData),
               let activeSensor = config.activeSensor {
                token = activeSensor.token
                macAddress = activeSensor.macAddress
            } else {
                #if DEBUG
                // Kovakoodatut arvot kehitysvaiheessa
                token = "dT5ObtUF/OV6lxhBE2EcxP+lgn715akLrn9Qe/TMTaE="
                macAddress = "EF:AF:84:20:B1:82"
                #endif
            }
            
            // Fetch sensor data
            if !token.isEmpty {
                do {
                    sensorData = try await apiClient.fetchSensorData(token: token, macAddress: macAddress)
                } catch {
                    errorMessage = error.localizedDescription
                }
            } else {
                errorMessage = "Ei tokenia"
            }
            
            // Create entry
            let entry = TemperatureEntry(
                date: currentDate,
                temperature: sensorData?.temperature,
                humidity: sensorData?.humidity,
                battery: sensorData?.battery,
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
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircularView
        case .accessoryCorner:
            accessoryCornerView
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            accessoryCircularView
        }
    }
    
    // MARK: - Pieni pyöreä (ylä/alarivi, 3 kpl)
    var accessoryCircularView: some View {
        ZStack {
            // Tausta
            Circle()
                .fill(Color.black.opacity(0.2))
            
            if let error = entry.errorMessage {
                // Virhetila
                VStack(spacing: 2) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                    
                    Text("Virhe")
                        .font(.system(size: 10))
                        .foregroundColor(.red)
                }
            } else if let temperature = entry.temperature {
                // Lämpötila
                VStack(spacing: 0) {
                    Text("\(temperature, specifier: "%.1f")")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    
                    Text("°C")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("Sensor")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            } else {
                // Ladataan
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
    
    // MARK: - Kulma (vasen/oikea yläkulma)
    var accessoryCornerView: some View {
        HStack(spacing: 3) {
            Image(systemName: "thermometer")
                .font(.system(size: 14))
                .foregroundColor(.blue)
            
            if let temperature = entry.temperature {
                Text("\(temperature, specifier: "%.1f")°")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Text("--.-°")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
            }
        }
    }
    
    // MARK: - Suorakaide (keskellä)
    var accessoryRectangularView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("RuuviTemp")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                
                if let temperature = entry.temperature {
                    Text("\(temperature, specifier: "%.1f") °C")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let humidity = entry.humidity, let battery = entry.battery {
                        HStack(spacing: 8) {
                            Label("\(Int(humidity))%", systemImage: "humidity")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            Label("\(battery, specifier: "%.2f")V", systemImage: "battery.100")
                                .font(.system(size: 10))
                                .foregroundColor(battery < 2.5 ? .orange : .secondary)
                        }
                    }
                } else if let error = entry.errorMessage {
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                } else {
                    Text("Ladataan...")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: entry.errorMessage != nil ? "exclamationmark.triangle" : "thermometer")
                .font(.system(size: 24))
                .foregroundColor(entry.errorMessage != nil ? .red : .blue)
        }
    }
}

@main
struct RuuviTempWidget: Widget {
    let kind: String = "RuuviTempWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TemperatureProvider()) { entry in
            TemperatureWidgetView(entry: entry)
        }
        .configurationDisplayName("RuuviTemp")
        .description("Näyttää RuuviTag-anturin lämpötilan")
        .supportedFamilies([
            .accessoryCircular,      // Pieni pyöreä (3 kpl rivissä)
            .accessoryCorner,        // Kulma
            .accessoryRectangular    // Suorakaide keskellä
        ])
    }
}

// MARK: - Preview
struct RuuviTempWidget_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // accessoryCircular preview
            TemperatureWidgetView(entry: TemperatureEntry(
                date: Date(),
                temperature: 22.5,
                humidity: 65.0,
                battery: 2.95,
                errorMessage: nil
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Circular")
            
            // accessoryCorner preview
            TemperatureWidgetView(entry: TemperatureEntry(
                date: Date(),
                temperature: -5.8,
                humidity: 85.0,
                battery: 2.45,
                errorMessage: nil
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCorner))
            .previewDisplayName("Corner")
            
            // accessoryRectangular preview
            TemperatureWidgetView(entry: TemperatureEntry(
                date: Date(),
                temperature: 18.3,
                humidity: 72.5,
                battery: 2.78,
                errorMessage: nil
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryRectangular))
            .previewDisplayName("Rectangular")
            
            // Error state
            TemperatureWidgetView(entry: TemperatureEntry(
                date: Date(),
                temperature: nil,
                humidity: nil,
                battery: nil,
                errorMessage: "Gateway ei vastaa"
            ))
            .previewContext(WidgetPreviewContext(family: .accessoryCircular))
            .previewDisplayName("Error")
        }
    }
}