# Changelog

All notable changes to RuuviTempWatch will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2025-01-17

### Changed
- **MAJOR: Switched from local gateway to Ruuvi Cloud API**
  - API endpoint changed to `https://network.ruuvi.com/sensors-dense`
  - Now requires internet connection instead of local network
  - Updated authentication to use Ruuvi Cloud Bearer tokens

### Fixed
- **Fixed temperature parsing from RAWv2 hex data**
  - Parser now correctly finds `990405` header in hex string
  - Temperature calculated using correct formula: `raw × 0.005`
  - Added support for offset calibrations from API
- **Fixed APIError enum handling**
  - Added missing `.serverError` and `.gatewayNotFound` cases
  - Fixed `.networkError` case to handle associated String value
- **Fixed UI to show correct sensor name**
  - Removed hardcoded "Ulkoilma" text
  - Now displays actual sensor name from API

### Added
- Battery voltage parsing and display
- Debug output for troubleshooting hex data parsing
- Support for Ruuvi Cloud offset calibrations (temperature, humidity, pressure)
- Comprehensive error handling for all API response codes

### Improved
- Increased API timeout from 10s to 30s for cloud requests
- Better error messages in Finnish
- More detailed debug logging for hex data parsing

## [1.0.0] - 2025-01-15

### Initial Release
- Basic watchOS app for displaying RuuviTag temperature
- Local Ruuvi Gateway support (192.168.1.39)
- Montserrat Bold font for temperature display
- Background refresh every ~15 minutes
- Keychain storage for secure token management
- Basic error handling and network status
- Widget support (accessoryCircular, accessoryCorner, accessoryRectangular)
- DEBUG mode with hardcoded credentials for development

### Features
- Temperature display in Celsius
- Humidity and battery status
- Last update timestamp
- Manual refresh button
- Settings view for token/MAC configuration
- Onboarding flow for first-time setup