import Foundation
import WatchConnectivity

class WatchConnectivityManager: NSObject, ObservableObject {
    private var session: WCSession
    var configManager: ConfigurationManager?
    
    override init() {
        self.session = WCSession.default
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    func sendConfigurationUpdate() {
        guard let configManager = configManager else { return }
        guard session.isReachable else { return }
        
        let message: [String: Any] = [
            WatchMessage.configurationUpdate.rawValue: try! JSONEncoder().encode(configManager.configuration)
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send configuration update: \(error.localizedDescription)")
        }
    }
    
    func sendSensorDataUpdate(_ sensor: RuuviSensor) {
        guard session.isReachable else { return }
        
        let message: [String: Any] = [
            WatchMessage.sensorDataUpdate.rawValue: try! JSONEncoder().encode(sensor)
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send sensor data update: \(error.localizedDescription)")
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("WC Session activation failed: \(error.localizedDescription)")
        } else {
            print("WC Session activated with state: \(activationState.rawValue)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("WC Session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("WC Session deactivated")
        session.activate()
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        // Handle messages from watchOS app
        print("Received message from watch: \(message)")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        // Handle messages from watchOS app that expect a reply
        print("Received message from watch with reply handler: \(message)")
        replyHandler([:])
    }
}