import Foundation

// MARK: - Shared Models for iOS and watchOS

struct RuuviSensor: Identifiable, Codable, Equatable {
    let id = UUID()
    var name: String
    var macAddress: String
    var token: String
    var isActive: Bool
    var lastTemperature: Double?
    var lastHumidity: Double?
    var lastBattery: Double?
    var lastUpdated: Date?
    
    init(name: String, macAddress: String, token: String, isActive: Bool = false) {
        self.name = name
        self.macAddress = macAddress.uppercased()
        self.token = token
        self.isActive = isActive
    }
}

struct RuuviConfiguration: Codable {
    var sensors: [RuuviSensor]
    var activeSensorId: UUID?
    var gatewayURL: String
    
    init() {
        self.sensors = []
        self.activeSensorId = nil
        self.gatewayURL = "http://192.168.1.39"
    }
    
    var activeSensor: RuuviSensor? {
        guard let activeSensorId = activeSensorId else { return nil }
        return sensors.first { $0.id == activeSensorId }
    }
    
    mutating func setActiveSensor(_ sensor: RuuviSensor) {
        // Mark all sensors as inactive
        for i in 0..<sensors.count {
            sensors[i].isActive = false
        }
        
        // Find and activate the selected sensor
        if let index = sensors.firstIndex(where: { $0.id == sensor.id }) {
            sensors[index].isActive = true
            activeSensorId = sensor.id
        }
    }
}

// MARK: - Configuration Manager
class ConfigurationManager: ObservableObject {
    @Published var configuration = RuuviConfiguration()
    
    private let userDefaults = UserDefaults(suiteName: "group.com.ruuvitempwatch") ?? UserDefaults.standard
    private let configurationKey = "ruuvi_configuration"
    
    init() {
        loadConfiguration()
    }
    
    func loadConfiguration() {
        if let data = userDefaults.data(forKey: configurationKey),
           let decoded = try? JSONDecoder().decode(RuuviConfiguration.self, from: data) {
            configuration = decoded
        }
    }
    
    func saveConfiguration() {
        if let encoded = try? JSONEncoder().encode(configuration) {
            userDefaults.set(encoded, forKey: configurationKey)
        }
    }
    
    func addSensor(_ sensor: RuuviSensor) {
        configuration.sensors.append(sensor)
        saveConfiguration()
    }
    
    func updateSensor(_ sensor: RuuviSensor) {
        if let index = configuration.sensors.firstIndex(where: { $0.id == sensor.id }) {
            configuration.sensors[index] = sensor
            saveConfiguration()
        }
    }
    
    func deleteSensor(_ sensor: RuuviSensor) {
        configuration.sensors.removeAll { $0.id == sensor.id }
        if configuration.activeSensorId == sensor.id {
            configuration.activeSensorId = nil
        }
        saveConfiguration()
    }
    
    func setActiveSensor(_ sensor: RuuviSensor) {
        configuration.setActiveSensor(sensor)
        saveConfiguration()
    }
}

// MARK: - WatchConnectivity Messages
enum WatchMessage: String, CaseIterable {
    case configurationUpdate = "configuration_update"
    case sensorDataUpdate = "sensor_data_update"
    case activeSensorChanged = "active_sensor_changed"
}