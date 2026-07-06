import Foundation

public struct WeeklyDigest: Identifiable, Codable, Equatable {
    public let id: UUID
    public let weekOf: Date
    public let peakMemoryPressureEvents: Int
    public let worstThermalState: String
    public let mostUsedModel: String
    public let mostUsedModelAvgGB: Double
    public let totalTimeInCompileMode: TimeInterval
    public let totalTimeInAIFirstMode: TimeInterval
    public let totalTimeInBatteryMode: TimeInterval
    public let throttleEventsPrevented: Int
    public let estimatedHoursSaved: Double
    public let gbFreedTotal: Double
    public let buildsProtected: Int
    
    public init(
        id: UUID = UUID(),
        weekOf: Date,
        peakMemoryPressureEvents: Int,
        worstThermalState: String,
        mostUsedModel: String,
        mostUsedModelAvgGB: Double,
        totalTimeInCompileMode: TimeInterval,
        totalTimeInAIFirstMode: TimeInterval,
        totalTimeInBatteryMode: TimeInterval,
        throttleEventsPrevented: Int,
        estimatedHoursSaved: Double,
        gbFreedTotal: Double,
        buildsProtected: Int
    ) {
        self.id = id
        self.weekOf = weekOf
        self.peakMemoryPressureEvents = peakMemoryPressureEvents
        self.worstThermalState = worstThermalState
        self.mostUsedModel = mostUsedModel
        self.mostUsedModelAvgGB = mostUsedModelAvgGB
        self.totalTimeInCompileMode = totalTimeInCompileMode
        self.totalTimeInAIFirstMode = totalTimeInAIFirstMode
        self.totalTimeInBatteryMode = totalTimeInBatteryMode
        self.throttleEventsPrevented = throttleEventsPrevented
        self.estimatedHoursSaved = estimatedHoursSaved
        self.gbFreedTotal = gbFreedTotal
        self.buildsProtected = buildsProtected
    }
}
