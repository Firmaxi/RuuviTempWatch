import XCTest
@testable import RuuviTempWatch_Watch_App

final class HexParserTests: XCTestCase {
    
    func testParseTemperature_ValidData() throws {
        // Test case: 01C3 hex = 451 decimal
        // Temperature = 451 × 0.005 = 2.255 °C
        let hexString = "9901C30000000000000000000000000000000000000000"
        
        let temperature = try HexParser.parseTemperature(from: hexString)
        
        XCTAssertEqual(temperature, 2.255, accuracy: 0.001)
    }
    
    func testParseTemperature_NegativeTemperature() throws {
        // Test case: FE70 hex = -400 decimal (signed int16)
        // Temperature = -400 × 0.005 = -2.0 °C
        let hexString = "99FE700000000000000000000000000000000000000000"
        
        let temperature = try HexParser.parseTemperature(from: hexString)
        
        XCTAssertEqual(temperature, -2.0, accuracy: 0.001)
    }
    
    func testParseTemperature_ZeroTemperature() throws {
        // Test case: 0000 hex = 0 decimal
        // Temperature = 0 × 0.005 = 0 °C
        let hexString = "990000000000000000000000000000000000000000000000"
        
        let temperature = try HexParser.parseTemperature(from: hexString)
        
        XCTAssertEqual(temperature, 0.0, accuracy: 0.001)
    }
    
    func testParseTemperature_MaxTemperature() throws {
        // Test case: 7FFF hex = 32767 decimal (max signed int16)
        // Temperature = 32767 × 0.005 = 163.835 °C
        let hexString = "997FFF000000000000000000000000000000000000000000"
        
        let temperature = try HexParser.parseTemperature(from: hexString)
        
        XCTAssertEqual(temperature, 163.835, accuracy: 0.001)
    }
    
    func testParseTemperature_MinTemperature() throws {
        // Test case: 8000 hex = -32768 decimal (min signed int16)
        // Temperature = -32768 × 0.005 = -163.84 °C
        let hexString = "998000000000000000000000000000000000000000000000"
        
        let temperature = try HexParser.parseTemperature(from: hexString)
        
        XCTAssertEqual(temperature, -163.84, accuracy: 0.001)
    }
    
    func testParseTemperature_InvalidHexString() {
        let hexString = "99XYZ0000000000000000000000000000000000000000000"
        
        XCTAssertThrowsError(try HexParser.parseTemperature(from: hexString)) { error in
            XCTAssertTrue(error is HexParser.ParsingError)
            XCTAssertEqual(error as? HexParser.ParsingError, .invalidHexString)
        }
    }
    
    func testParseTemperature_InsufficientData() {
        let hexString = "99" // Too short
        
        XCTAssertThrowsError(try HexParser.parseTemperature(from: hexString)) { error in
            XCTAssertTrue(error is HexParser.ParsingError)
            XCTAssertEqual(error as? HexParser.ParsingError, .insufficientData)
        }
    }
    
    func testParseTemperature_WithWhitespace() throws {
        let hexString = "  99 01C3 0000 0000 0000 0000 0000 0000 0000 0000 0000 0000  "
        
        let temperature = try HexParser.parseTemperature(from: hexString)
        
        XCTAssertEqual(temperature, 2.255, accuracy: 0.001)
    }
    
    func testParseTemperature_LowercaseHex() throws {
        let hexString = "9901c30000000000000000000000000000000000000000"
        
        let temperature = try HexParser.parseTemperature(from: hexString)
        
        XCTAssertEqual(temperature, 2.255, accuracy: 0.001)
    }
    
    func testParseFullData() throws {
        // Example RAWv2 data with:
        // Temperature: 01C3 = 451 × 0.005 = 2.255 °C
        // Humidity: 8000 = 32768 × 0.0025 = 81.92 %
        // Pressure: C3E8 = 50152 + 50000 = 100152 Pa
        let hexString = "9901C38000C3E800000000000000000000000000000000"
        
        let data = try HexParser.parseFullData(from: hexString)
        
        XCTAssertEqual(data.temperature, 2.255, accuracy: 0.001)
        XCTAssertEqual(data.humidity, 81.92, accuracy: 0.01)
        XCTAssertEqual(data.pressure, 100152, accuracy: 1)
    }
}