import Foundation

enum HexParser {
    enum ParsingError: Error {
        case invalidHexString
        case invalidDataFormat
        case insufficientData
        case headerNotFound
    }
    
    /// Parse temperature from RuuviTag Data Format 5 (RAWv2) hex string
    /// - Parameter hexString: The RAWv2 hex string from the API
    /// - Returns: Temperature in Celsius
    static func parseTemperature(from hexString: String) throws -> Double {
        let parsedData = try parseFullData(from: hexString)
        return parsedData.temperature
    }
    
    /// Parse complete RAWv2 data according to specification
    static func parseFullData(from hexString: String) throws -> RuuviData {
        let cleanHex = hexString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        print("🧪 Parsing hex data: \(cleanHex)")
        
        // Find "990405" header
        guard let headerRange = cleanHex.range(of: "990405") else {
            print("❌ Header 990405 not found in: \(cleanHex)")
            throw ParsingError.headerNotFound
        }
        
        // Get the index after header
        let payloadStartIndex = cleanHex.index(headerRange.upperBound, offsetBy: 0)
        
        // We need at least 17 bytes (34 hex chars) for basic data
        let remainingLength = cleanHex.distance(from: payloadStartIndex, to: cleanHex.endIndex)
        guard remainingLength >= 34 else {
            print("❌ Insufficient data after header. Need at least 34 chars, got \(remainingLength)")
            throw ParsingError.insufficientData
        }
        
        // Extract available payload
        let payloadEndIndex = cleanHex.index(payloadStartIndex, offsetBy: min(remainingLength, 48))
        let payload = String(cleanHex[payloadStartIndex..<payloadEndIndex])
        print("🧪 Payload: \(payload)")
        
        // Parse temperature (bytes 0-1, signed int16)
        let tempHex = String(payload.prefix(4))
        print("🧪 Temperature hex: \(tempHex)")
        
        // Convert to signed int16
        guard let tempUInt = UInt16(tempHex, radix: 16) else {
            throw ParsingError.invalidDataFormat
        }
        let tempRaw = Int16(bitPattern: tempUInt)
        let temperature = Double(tempRaw) * 0.005
        print("🧪 Temperature: raw=\(tempRaw), calculated=\(temperature)°C")
        
        // Debug: Tarkista muut mahdolliset tulkinnat
        print("🧪 Debug - Alternative interpretations:")
        print("  - As unsigned: \(Double(tempUInt) * 0.005)°C")
        print("  - Direct /100: \(Double(tempRaw) / 100.0)°C")
        print("  - Direct /10: \(Double(tempRaw) / 10.0)°C")
        print("  - Little-endian: \(String(tempHex.suffix(2) + tempHex.prefix(2)))")
        if let leTemp = Int16(String(tempHex.suffix(2) + tempHex.prefix(2)), radix: 16) {
            print("  - LE temp: \(Double(leTemp) * 0.005)°C")
        }
        
        // Parse humidity (bytes 2-3, unsigned uint16)
        let humStart = payload.index(payload.startIndex, offsetBy: 4)
        let humEnd = payload.index(humStart, offsetBy: 4)
        let humHex = String(payload[humStart..<humEnd])
        print("🧪 Humidity hex: \(humHex)")
        
        guard let humRaw = UInt16(humHex, radix: 16) else {
            throw ParsingError.invalidDataFormat
        }
        let humidity = Double(humRaw) * 0.0025
        print("🧪 Humidity: raw=\(humRaw), calculated=\(humidity)%")
        
        // Parse pressure (bytes 4-5, unsigned uint16)
        let presStart = payload.index(payload.startIndex, offsetBy: 8)
        let presEnd = payload.index(presStart, offsetBy: 4)
        let presHex = String(payload[presStart..<presEnd])
        print("🧪 Pressure hex: \(presHex)")
        
        guard let presRaw = UInt16(presHex, radix: 16) else {
            throw ParsingError.invalidDataFormat
        }
        let pressure = (Double(presRaw) + 50000) / 100
        print("🧪 Pressure: raw=\(presRaw), calculated=\(pressure) hPa")
        
        // Parse battery voltage (bytes 12-13) if available
        var battery: Double? = nil
        if payload.count >= 28 {  // Need at least 14 bytes (28 hex chars) for battery
            let powerStart = payload.index(payload.startIndex, offsetBy: 24)
            let powerEnd = payload.index(powerStart, offsetBy: 4)
            let powerHex = String(payload[powerStart..<powerEnd])
            print("🧪 Power info hex: \(powerHex)")
            
            if let powerInfo = UInt16(powerHex, radix: 16) {
                let batteryMV = (powerInfo >> 5) + 1600
                battery = Double(batteryMV) / 1000.0 // Convert to volts
                print("🧪 Battery: \(batteryMV) mV = \(battery!) V")
            }
        }
        
        return RuuviData(
            temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            battery: nil
        )
    }
    
    struct RuuviData {
        let temperature: Double // Celsius
        let humidity: Double    // RH %
        let pressure: Double    // hPa
        let battery: Double?    // Volts
    }
}