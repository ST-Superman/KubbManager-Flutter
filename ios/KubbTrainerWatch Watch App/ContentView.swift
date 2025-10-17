import SwiftUI
import WatchConnectivity

struct ContentView: View {
    @ObservedObject private var connectivity = WatchConnectivityManager()
    @State private var sessionData: WatchSessionData?
    @State private var isConnected = false
    
    var body: some View {
        VStack {
            if let session = sessionData {
                SessionView(session: session, connectivity: connectivity)
            } else {
                WaitingView(isConnected: isConnected, connectivity: connectivity)
            }
        }
        .onAppear {
            connectivity.delegate = WatchConnectivityDelegate(
                onSessionUpdate: { session in
                    sessionData = session
                },
                onConnectionChange: { connected in
                    isConnected = connected
                }
            )
        }
    }
}

// MARK: - Waiting View
struct WaitingView: View {
    let isConnected: Bool
    let connectivity: WatchConnectivityManager
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "applewatch.radiowaves.left.and.right")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Waiting for Session")
                .font(.headline)
                .multilineTextAlignment(.center)
            
            if !isConnected {
                Text("iPhone Not Connected")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("Start a session on your iPhone")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
            
            Button("Refresh") {
                connectivity.requestCurrentState()
            }
        }
        .padding()
    }
}

// MARK: - Session View
struct SessionView: View {
    let session: WatchSessionData
    let connectivity: WatchConnectivityManager
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                HStack {
                    Text(session.title)
                        .font(.headline)
                    
                    Spacer()
                    
                    // Connection indicator
                    Circle()
                        .fill(connectivity.isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Session Stats
                VStack(spacing: 8) {
                    StatRow(label: "Progress", value: "\(session.totalThrows)/\(session.target)")
                    StatRow(label: "Hits", value: "\(session.totalHits)", color: .green)
                    StatRow(label: "Accuracy", value: "\(Int(session.accuracy * 100))%", color: .blue)
                }
                .padding(.horizontal)
                
                Divider()
                
                // Throw Buttons
                VStack(spacing: 12) {
                    Text("Record Throw")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        recordThrow(isHit: true)
                    }) {
                        Text("HIT")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        recordThrow(isHit: false)
                    }) {
                        Text("MISS")
                            .font(.headline)
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
        }
    }
    
    private func recordThrow(isHit: Bool) {
        // Play haptic feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(isHit ? .success : .error)
        
        // Send throw to iPhone
        connectivity.recordThrow(isHit: isHit)
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let label: String
    let value: String
    let color: Color?
    
    init(label: String, value: String, color: Color? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }
    
    var body: some View {
        HStack {
            Text(label)
                .font(.body)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
    }
}

// MARK: - Watch Connectivity Manager
class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    @Published var isConnected = false
    var delegate: WatchConnectivityDelegate?
    
    private var session: WCSession?
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated && session.isReachable
            self.delegate?.onConnectionChange(self.isConnected)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        DispatchQueue.main.async {
            if let type = message["type"] as? String {
                switch type {
                case "start_session", "update_session":
                    if let data = message["data"] as? [String: Any] {
                        let sessionData = WatchSessionData.fromDictionary(data)
                        self.delegate?.onSessionUpdate(sessionData)
                    }
                case "end_session":
                    self.delegate?.onSessionUpdate(nil)
                default:
                    break
                }
            }
        }
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isConnected = session.isReachable
            self.delegate?.onConnectionChange(self.isConnected)
        }
    }
    
    func recordThrow(isHit: Bool) {
        guard let session = session, session.isReachable else { return }
        
        let message: [String: Any] = [
            "type": "throw_recorded",
            "data": [
                "isHit": isHit,
                "timestamp": Date().timeIntervalSince1970
            ]
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error sending throw: \(error.localizedDescription)")
        }
    }
    
    func requestCurrentState() {
        guard let session = session, session.isReachable else { return }
        
        let message: [String: Any] = [
            "type": "request_current_state"
        ]
        
        session.sendMessage(message, replyHandler: nil) { error in
            print("Error requesting state: \(error.localizedDescription)")
        }
    }
}

// MARK: - Watch Connectivity Delegate
class WatchConnectivityDelegate {
    let onSessionUpdate: (WatchSessionData?) -> Void
    let onConnectionChange: (Bool) -> Void
    
    init(onSessionUpdate: @escaping (WatchSessionData?) -> Void,
         onConnectionChange: @escaping (Bool) -> Void) {
        self.onSessionUpdate = onSessionUpdate
        self.onConnectionChange = onConnectionChange
    }
}

// MARK: - Watch Session Data
struct WatchSessionData {
    let sessionId: String
    let title: String
    let target: Int
    let totalThrows: Int
    let totalHits: Int
    let accuracy: Double
    
    static func fromDictionary(_ data: [String: Any]) -> WatchSessionData {
        return WatchSessionData(
            sessionId: data["sessionId"] as? String ?? "",
            title: data["title"] as? String ?? "8-Meter Practice",
            target: data["target"] as? Int ?? 0,
            totalThrows: data["totalThrows"] as? Int ?? 0,
            totalHits: data["totalHits"] as? Int ?? 0,
            accuracy: data["accuracy"] as? Double ?? 0.0
        )
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
#endif