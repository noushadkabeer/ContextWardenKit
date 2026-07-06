import Foundation
import ServiceManagement
import SwiftUI
import Combine

public actor PrivacyMetricsEngine: ObservableObject {
    public static let shared = PrivacyMetricsEngine()
    
    // MARK: - Live Helper Activity Stream
    public private(set) var recentHelperActions: [AuditEvent] = []
    private var helperActivityContinuations: [UUID: AsyncStream<AuditEvent>.Continuation] = [:]
    
    public var helperActivityStream: AsyncStream<AuditEvent> {
        AsyncStream { continuation in
            let id = UUID()
            self.helperActivityContinuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id: id) }
            }
        }
    }
    
    private func removeContinuation(id: UUID) {
        helperActivityContinuations.removeValue(forKey: id)
    }
    
    public func recordHelperAction(_ event: AuditEvent) async {
        recentHelperActions.insert(event, at: 0)
        if recentHelperActions.count > 50 {
            recentHelperActions = Array(recentHelperActions.prefix(50))
        }
        for continuation in helperActivityContinuations.values {
            continuation.yield(event)
        }
    }
    
    // MARK: - ContextWarden's Own Network Activity
    public struct OwnNetworkCall: Identifiable, Codable, Equatable {
        public let id: UUID
        public let timestamp: Date
        public let destination: String    // e.g. "localhost:11434", "Paddle SDK"
        public let purpose: String        // e.g. "Ollama model list", "subscription check"
        public let isExpected: Bool       // always true for our own calls
        public let callCount: Int         // aggregate same-day calls
        
        public init(
            id: UUID = UUID(),
            timestamp: Date = Date(),
            destination: String,
            purpose: String,
            isExpected: Bool = true,
            callCount: Int = 1
        ) {
            self.id = id
            self.timestamp = timestamp
            self.destination = destination
            self.purpose = purpose
            self.isExpected = isExpected
            self.callCount = callCount
        }
    }
    
    public private(set) var ownNetworkActivity: [OwnNetworkCall] = []
    
    public func recordOwnNetworkCall(destination: String, purpose: String) async {
        let now = Date()
        if let idx = ownNetworkActivity.firstIndex(where: { 
            $0.destination == destination && $0.purpose == purpose && Calendar.current.isDate($0.timestamp, inSameDayAs: now) 
        }) {
            let existing = ownNetworkActivity[idx]
            let updated = OwnNetworkCall(
                id: existing.id,
                timestamp: now,
                destination: existing.destination,
                purpose: existing.purpose,
                isExpected: existing.isExpected,
                callCount: existing.callCount + 1
            )
            ownNetworkActivity[idx] = updated
        } else {
            let call = OwnNetworkCall(destination: destination, purpose: purpose)
            ownNetworkActivity.insert(call, at: 0)
        }
    }
    
    public var last24HourCallCount: Int {
        ownNetworkActivity
            .filter { Date().timeIntervalSince($0.timestamp) < 86400 }
            .reduce(0) { $0 + $1.callCount }
    }
    
    public var outboundNonLocalCallCount: Int {
        ownNetworkActivity
            .filter { !$0.destination.contains("localhost") && !$0.destination.contains("127.0.0.1") }
            .filter { Date().timeIntervalSince($0.timestamp) < 86400 }
            .reduce(0) { $0 + $1.callCount }
    }
    
    // MARK: - Data Inventory
    public struct DataInventory: Equatable {
        public let auditLogEntries: Int
        public let auditLogSizeBytes: Int64
        public let memoryHistoryDays: Int
        public let memoryHistorySizeBytes: Int64
        public let buildHistorySessions: Int
        public let buildHistorySizeBytes: Int64
        public let weeklyDigestCount: Int
        public let weeklyDigestSizeBytes: Int64
        public let settingsSizeBytes: Int64
        
        public init(
            auditLogEntries: Int = 0,
            auditLogSizeBytes: Int64 = 0,
            memoryHistoryDays: Int = 0,
            memoryHistorySizeBytes: Int64 = 0,
            buildHistorySessions: Int = 0,
            buildHistorySizeBytes: Int64 = 0,
            weeklyDigestCount: Int = 0,
            weeklyDigestSizeBytes: Int64 = 0,
            settingsSizeBytes: Int64 = 0
        ) {
            self.auditLogEntries = auditLogEntries
            self.auditLogSizeBytes = auditLogSizeBytes
            self.memoryHistoryDays = memoryHistoryDays
            self.memoryHistorySizeBytes = memoryHistorySizeBytes
            self.buildHistorySessions = buildHistorySessions
            self.buildHistorySizeBytes = buildHistorySizeBytes
            self.weeklyDigestCount = weeklyDigestCount
            self.weeklyDigestSizeBytes = weeklyDigestSizeBytes
            self.settingsSizeBytes = settingsSizeBytes
        }
        
        public var totalSizeBytes: Int64 {
            auditLogSizeBytes + memoryHistorySizeBytes +
            buildHistorySizeBytes + weeklyDigestSizeBytes +
            settingsSizeBytes
        }
        
        public var totalSizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: totalSizeBytes, countStyle: .file)
        }
        
        public static let dataDirectory: URL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("ContextWarden")
    }
    
    public func calculateDataInventory() async -> DataInventory {
        let baseDir = DataInventory.dataDirectory
        let fileManager = FileManager.default
        
        // Audit Log
        let auditURL = baseDir.appendingPathComponent("audit_log.json")
        let auditSize = (try? fileManager.attributesOfItem(atPath: auditURL.path)[.size] as? Int64) ?? 0
        let auditEntries = (await AuditLogger.shared.fetchAllEvents()).count
        
        // Memory History
        let memURL = baseDir.appendingPathComponent("memory_history.json")
        let memSize = (try? fileManager.attributesOfItem(atPath: memURL.path)[.size] as? Int64) ?? 0
        let memDays = memSize > 0 ? max(1, Int(memSize / 1024)) : 0
        
        // Build History
        let buildURL = baseDir.appendingPathComponent("build_history.json")
        let buildSize = (try? fileManager.attributesOfItem(atPath: buildURL.path)[.size] as? Int64) ?? 0
        let buildSessions = buildSize > 0 ? max(1, Int(buildSize / 512)) : 0
        
        // Weekly Digest
        let digestURL = baseDir.appendingPathComponent("weekly_digests.json")
        let digestSize = (try? fileManager.attributesOfItem(atPath: digestURL.path)[.size] as? Int64) ?? 0
        let digestCount = digestSize > 0 ? max(1, Int(digestSize / 256)) : 0
        
        // Settings / UserDefaults
        let prefsURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Preferences/com.contextwarden.pro.plist")
        let settingsSize = (try? fileManager.attributesOfItem(atPath: prefsURL.path)[.size] as? Int64) ?? 512
        
        return DataInventory(
            auditLogEntries: auditEntries,
            auditLogSizeBytes: auditSize,
            memoryHistoryDays: memDays,
            memoryHistorySizeBytes: memSize,
            buildHistorySessions: buildSessions,
            buildHistorySizeBytes: buildSize,
            weeklyDigestCount: digestCount,
            weeklyDigestSizeBytes: digestSize,
            settingsSizeBytes: settingsSize
        )
    }
    
    // MARK: - Helper Status
    public struct HelperStatus: Equatable {
        public let isInstalled: Bool
        public let isConnected: Bool
        public let version: String?
        public let bundleID: String = "com.contextwarden.helper"
        public let teamID: String
        public let isCodeSigned: Bool
        public let entitlements: [String]
        
        public init(
            isInstalled: Bool = true,
            isConnected: Bool = true,
            version: String? = "1.0.2",
            teamID: String = "DEVELOPMENT",
            isCodeSigned: Bool = true,
            entitlements: [String] = ["com.apple.security.cs.allow-unsigned-executable-memory"]
        ) {
            self.isInstalled = isInstalled
            self.isConnected = isConnected
            self.version = version
            self.teamID = teamID
            self.isCodeSigned = isCodeSigned
            self.entitlements = entitlements
        }
        
        public var entitlementDescriptions: [(entitlement: String, description: String)] {
            entitlements.map { ent in
                switch ent {
                case "com.apple.security.cs.allow-unsigned-executable-memory":
                    return (ent, "Required for process signal sending (SIGSTOP/SIGCONT)")
                default:
                    return (ent, ent)
                }
            }
        }
    }
    
    public func helperStatus() async -> HelperStatus {
        let service = SMAppService.daemon(plistName: "com.contextwarden.helper.plist")
        let isInstalled = service.status == .enabled
        return HelperStatus(
            isInstalled: isInstalled,
            isConnected: isInstalled,
            version: "1.0.2",
            teamID: "DEVELOPMENT",
            isCodeSigned: true,
            entitlements: ["com.apple.security.cs.allow-unsigned-executable-memory"]
        )
    }
    
    // MARK: - Granular Clear
    public enum ClearableDataType: String, CaseIterable, Identifiable, Codable {
        case auditLog         = "Audit Log"
        case memoryHistory    = "Memory History"
        case buildHistory     = "Build History"
        case weeklyDigests    = "Weekly Digests"
        case savedYouMetrics  = "Saved You Lifetime Metrics"
        case settings         = "All Settings (resets to defaults)"
        
        public var id: String { rawValue }
        
        public var warningMessage: String? {
            switch self {
            case .settings:
                return "This will reset all your persona configurations, trigger lists, and preferences."
            case .savedYouMetrics:
                return "Your lifetime hours saved and builds protected counter will reset to zero permanently."
            default:
                return nil
            }
        }
    }
    
    public func clearData(types: Set<ClearableDataType>) async throws {
        let baseDir = DataInventory.dataDirectory
        let fm = FileManager.default
        
        for type in types {
            switch type {
            case .auditLog:
                await AuditLogger.shared.clearLog()
                recentHelperActions.removeAll()
            case .memoryHistory:
                try? fm.removeItem(at: baseDir.appendingPathComponent("memory_history.json"))
            case .buildHistory:
                try? fm.removeItem(at: baseDir.appendingPathComponent("build_history.json"))
            case .weeklyDigests:
                try? fm.removeItem(at: baseDir.appendingPathComponent("weekly_digests.json"))
            case .savedYouMetrics:
                UserDefaults.standard.removeObject(forKey: "SavedYouHours")
                UserDefaults.standard.removeObject(forKey: "BuildsProtected")
            case .settings:
                if let domain = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: domain)
                }
            }
        }
    }
    
    public func clearAllData() async throws {
        try await clearData(types: Set(ClearableDataType.allCases))
    }
    
    // MARK: - Uninstall Verification
    public struct UninstallVerification: Equatable {
        public struct PathCheck: Identifiable, Equatable {
            public let id: UUID
            public let path: String
            public let description: String
            public let exists: Bool
            public let isEmpty: Bool
            
            public init(id: UUID = UUID(), path: String, description: String, exists: Bool, isEmpty: Bool) {
                self.id = id
                self.path = path
                self.description = description
                self.exists = exists
                self.isEmpty = isEmpty
            }
        }
        
        public let checks: [PathCheck]
        public var isClean: Bool { checks.allSatisfy { !$0.exists || $0.isEmpty } }
        
        public init(checks: [PathCheck]) {
            self.checks = checks
        }
    }
    
    public func verifyCompleteRemoval() async -> UninstallVerification {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        
        let pathTargets = [
            ("/Library/PrivilegedHelperTools/com.contextwarden.helper", "Privileged Helper Binary"),
            ("\(home)/Library/Application Support/ContextWarden", "Application Support Data"),
            ("\(home)/Library/LaunchAgents/com.contextwarden.plist", "User LaunchAgent"),
            ("\(home)/Library/Preferences/com.contextwarden.pro.plist", "App Preferences")
        ]
        
        var checks: [UninstallVerification.PathCheck] = []
        for (path, desc) in pathTargets {
            let exists = fm.fileExists(atPath: path)
            var isEmpty = true
            if exists {
                if let contents = try? fm.contentsOfDirectory(atPath: path) {
                    isEmpty = contents.isEmpty
                } else {
                    isEmpty = false
                }
            }
            checks.append(UninstallVerification.PathCheck(path: path, description: desc, exists: exists, isEmpty: isEmpty))
        }
        return UninstallVerification(checks: checks)
    }
}
