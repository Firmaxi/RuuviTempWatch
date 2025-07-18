import SwiftUI

@main
struct RuuviTempWatchApp: App {
    @StateObject private var apiClient = RuuviAPIClient()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    
    var body: some Scene {
        WindowGroup {
            #if DEBUG
            // Kehitysvaiheessa: ohita onboarding
            ContentView()
                .environmentObject(apiClient)
            #else
            // Production: näytä onboarding tarvittaessa
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(apiClient)
            } else {
                OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                    .environmentObject(apiClient)
            }
            #endif
        }
    }
}