import Foundation

public struct PowerMetrics: Codable, Equatable {
    public let cpuWatts: Double
    public let gpuWatts: Double
    public let timestamp: Date
    
    public init(cpuWatts: Double, gpuWatts: Double, timestamp: Date = Date()) {
        self.cpuWatts = cpuWatts
        self.gpuWatts = gpuWatts
        self.timestamp = timestamp
    }
}

public actor ThermalEngine {
    private var monitoringTask: Task<Void, Never>?
    private var onUpdateHandler: ((CWThermalState) -> Void)?
    
    public init() {}
    
    public func registerOnUpdate(_ handler: @escaping (CWThermalState) -> Void) {
        self.onUpdateHandler = handler
    }
    
    public func currentState() -> CWThermalState {
        let state = ProcessInfo.processInfo.thermalState
        let level: CWThermalState.Level
        let displayName: String
        let colorName: String
        let shouldAlert: Bool
        
        switch state {
        case .nominal:
            level = .balanced
            displayName = "Balanced"
            colorName = "Green"
            shouldAlert = false
        case .fair:
            level = .warm
            displayName = "Warm"
            colorName = "Yellow"
            shouldAlert = false
        case .serious:
            level = .throttling
            displayName = "Throttling"
            colorName = "Orange"
            shouldAlert = true
        case .critical:
            level = .critical
            displayName = "Critical"
            colorName = "Red"
            shouldAlert = true
        @unknown default:
            level = .balanced
            displayName = "Balanced"
            colorName = "Green"
            shouldAlert = false
        }
        
        return CWThermalState(
            level: level,
            displayName: displayName,
            colorName: colorName,
            shouldAlert: shouldAlert,
            topOffendingProcess: nil
        )
    }
    
    public func startMonitoring() {
        stopMonitoring()
        
        monitoringTask = Task { [weak self] in
            guard let self = self else { return }
            let sequence = NotificationCenter.default.notifications(named: ProcessInfo.thermalStateDidChangeNotification)
            for await _ in sequence {
                if Task.isCancelled { break }
                let state = await self.currentState()
                if let handler = await self.onUpdateHandler {
                    handler(state)
                }
            }
        }
    }
    
    public func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
    }
    
    public func powerMetrics() async throws -> PowerMetrics {
        // Will be extended/delegated via XPC in ContextWarden-Pro
        throw NSError(
            domain: "CWErrorDomain",
            code: 403,
            userInfo: [NSLocalizedDescriptionKey: "Power metrics are only available in ContextWarden-Pro via XPC helper."]
        )
    }
}
