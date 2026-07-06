import Foundation

public struct RunningProcess: Identifiable, Codable, Equatable {
    public let pid: Int32
    public let name: String
    public let memoryMB: Int
    public let cpuPercent: Double
    public let startTime: Date
    
    public var id: Int32 { pid }
    
    public init(pid: Int32, name: String, memoryMB: Int, cpuPercent: Double, startTime: Date) {
        self.pid = pid
        self.name = name
        self.memoryMB = memoryMB
        self.cpuPercent = cpuPercent
        self.startTime = startTime
    }
}
