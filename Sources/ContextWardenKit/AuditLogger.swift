import Foundation

public actor AuditLogger {
    public static let shared = AuditLogger()
    
    public var onNewEvent: ((AuditEvent) async -> Void)?
    
    public func setOnNewEvent(_ handler: @escaping (AuditEvent) async -> Void) {
        self.onNewEvent = handler
    }
    
    private var events: [AuditEvent] = []
    
    private nonisolated var logFileURL: URL {
        AuditLogger.getLogFileURL()
    }
    
    private static func getLogFileURL() -> URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("ContextWarden")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return appSupport.appendingPathComponent("audit_log.json")
    }
    
    public init() {
        self.events = AuditLogger.loadInitialFromDisk(logFileURL: AuditLogger.getLogFileURL())
    }
    
    private static func loadInitialFromDisk(logFileURL: URL) -> [AuditEvent] {
        guard FileManager.default.fileExists(atPath: logFileURL.path),
              let data = try? Data(contentsOf: logFileURL),
              let events = try? JSONDecoder().decode([AuditEvent].self, from: data) else {
            return []
        }
        return events
    }
    
    public func log(_ event: AuditEvent) async {
        events.insert(event, at: 0)
        saveToDisk()
        await onNewEvent?(event)
    }
    
    public func fetchAllEvents() -> [AuditEvent] {
        return events
    }
    
    public func clearLog() {
        events.removeAll()
        try? FileManager.default.removeItem(at: logFileURL)
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(events)
            try data.write(to: logFileURL, options: .atomic)
        } catch {
            print("Failed to save audit log: \(error)")
        }
    }
    
    private func loadFromDisk() {
        guard FileManager.default.fileExists(atPath: logFileURL.path) else { return }
        do {
            let data = try Data(contentsOf: logFileURL)
            events = try JSONDecoder().decode([AuditEvent].self, from: data)
        } catch {
            print("Failed to load audit log: \(error)")
        }
    }
}
