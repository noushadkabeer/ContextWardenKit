import Foundation

public struct AuditEvent: Identifiable, Codable, Equatable {
    public let id: UUID
    public let timestamp: Date
    public let category: String
    public let actionDescription: String
    public let targetProcess: String?
    public let targetPid: Int32?
    public let success: Bool
    
    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: String,
        actionDescription: String,
        targetProcess: String? = nil,
        targetPid: Int32? = nil,
        success: Bool = true
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.actionDescription = actionDescription
        self.targetProcess = targetProcess
        self.targetPid = targetPid
        self.success = success
    }
}
