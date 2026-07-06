import Foundation

public struct CWThermalState: Codable, Equatable {
    public enum Level: String, Codable, CaseIterable {
        case balanced
        case warm
        case throttling
        case critical
    }
    
    public let level: Level
    public let displayName: String
    public let colorName: String   // Name of color asset to use
    public let shouldAlert: Bool   // Alerts on serious/throttling or critical
    public let topOffendingProcess: String?  // Name of highest CPU process when warning/critical
    
    public init(
        level: Level,
        displayName: String,
        colorName: String,
        shouldAlert: Bool,
        topOffendingProcess: String? = nil
    ) {
        self.level = level
        self.displayName = displayName
        self.colorName = colorName
        self.shouldAlert = shouldAlert
        self.topOffendingProcess = topOffendingProcess
    }
}
