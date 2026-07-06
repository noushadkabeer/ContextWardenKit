import Foundation

public struct SystemMemoryState: Codable, Equatable {
    public let totalGB: Double
    public let systemUsedGB: Double      // wired + active (non-AI processes)
    public let aiModelsGB: Double        // sum of all identified AI process footprints
    public let freeGB: Double            // genuinely available
    public let swapUsedGB: Double        // current swap pressure
    public let inactiveGB: Double        // reclaimable by OS
    public let timestamp: Date
    
    public init(
        totalGB: Double,
        systemUsedGB: Double,
        aiModelsGB: Double,
        freeGB: Double,
        swapUsedGB: Double,
        inactiveGB: Double,
        timestamp: Date = Date()
    ) {
        self.totalGB = totalGB
        self.systemUsedGB = systemUsedGB
        self.aiModelsGB = aiModelsGB
        self.freeGB = freeGB
        self.swapUsedGB = swapUsedGB
        self.inactiveGB = inactiveGB
        self.timestamp = timestamp
    }
    
    public var headroomGB: Double { freeGB + inactiveGB }
    public var isCritical: Bool { headroomGB < 8.0 }
    public var isWarning: Bool { headroomGB < 16.0 }
}
