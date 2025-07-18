import SwiftUI

struct ContentView: View {
    @EnvironmentObject var apiClient: RuuviAPIClient
    @State private var isRefreshing = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Temperature display
                if let temperature = apiClient.latestTemperature {
                    Text("\(temperature, specifier: "%.1f")°C")
                        .font(.custom("Montserrat-Bold", size: 20))
                        .foregroundColor(.white)
                } else {
                    Text("--.- °C")
                        .font(.custom("Montserrat-Bold", size: 20))
                        .foregroundColor(.gray)
                }
                
                // Sensor name and additional data
                VStack(spacing: 5) {
                    Text(apiClient.sensorName)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    
                    // Additional sensor data in small text
                    if apiClient.humidity != nil || apiClient.battery != nil {
                        HStack(spacing: 10) {
                            if let humidity = apiClient.humidity {
                                Label("\(humidity, specifier: "%.1f")%", systemImage: "humidity")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            if let battery = apiClient.battery {
                                Label("\(battery, specifier: "%.2f")V", systemImage: "battery.100")
                                    .font(.system(size: 12))
                                    .foregroundColor(battery < 2.5 ? .orange : .gray)
                            }
                        }
                    }
                }
                
                // Last update time
                if let lastUpdate = apiClient.lastUpdateTime {
                    Text("Päivitetty: \(lastUpdate, style: .time)")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                // Refresh button
                Button(action: {
                    Task {
                        await refreshTemperature()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)
                        .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                        .animation(isRefreshing ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRefreshing)
                }
                .disabled(isRefreshing)
            }
            .navigationTitle("RuuviTemp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(apiClient)
            }
            .onAppear {
                Task {
                    await refreshTemperature()
                }
            }
        }
    }
    
    private func refreshTemperature() async {
        print("🔄 Aloitetaan lämpötilan päivitys...")
        isRefreshing = true
        defer { isRefreshing = false }
        
        do {
            try await apiClient.fetchTemperature()
            print("✅ Lämpötilan päivitys onnistui!")
        } catch {
            print("❌ Virhe lämpötilan haussa: \(error)")
            // Error handling is done in apiClient
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(RuuviAPIClient())
}