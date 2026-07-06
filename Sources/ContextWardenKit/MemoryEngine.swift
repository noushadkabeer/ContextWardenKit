import Foundation
import Darwin

public actor MemoryEngine {
    private var aiModelsGB: Double = 0.0
    private var pollingTask: Task<Void, Never>?
    private var interval: TimeInterval = 3.0
    private var onUpdateHandler: ((SystemMemoryState) -> Void)?
    
    public init() {}
    
    public func updateAIModelsMemory(_ gb: Double) {
        self.aiModelsGB = gb
    }
    
    public func registerOnUpdate(_ handler: @escaping (SystemMemoryState) -> Void) {
        self.onUpdateHandler = handler
    }
    
    public func snapshot() -> SystemMemoryState {
        // 1. Total Physical Memory
        var totalBytes: Int64 = 0
        var size = MemoryLayout<Int64>.size
        let totalResult = sysctlbyname("hw.memsize", &totalBytes, &size, nil, 0)
        let totalGB = totalResult == 0 ? Double(totalBytes) / 1_073_741_824.0 : 0.0
        
        // 2. VM Statistics (free, active, inactive, wired, compressed)
        let hostPort = mach_host_self()
        var hostSize = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride)
        var vmStat = vm_statistics64_data_t()
        
        let kernReturn = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(hostSize)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &hostSize)
            }
        }
        
        var pageSize: vm_size_t = 0
        let pageResult = host_page_size(hostPort, &pageSize)
        let finalPageSize = (pageResult == KERN_SUCCESS && pageSize > 0) ? Double(pageSize) : 4096.0
        
        var freeGB: Double = 0.0
        var activeGB: Double = 0.0
        var inactiveGB: Double = 0.0
        var wiredGB: Double = 0.0

        if kernReturn == KERN_SUCCESS {
            let bytesPerPage = finalPageSize
            freeGB = (Double(vmStat.free_count) * bytesPerPage) / 1_073_741_824.0
            activeGB = (Double(vmStat.active_count) * bytesPerPage) / 1_073_741_824.0
            inactiveGB = (Double(vmStat.inactive_count) * bytesPerPage) / 1_073_741_824.0
            wiredGB = (Double(vmStat.wire_count) * bytesPerPage) / 1_073_741_824.0
        }
        
        // 3. Swap usage
        var swapUsage = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        let swapResult = sysctlbyname("vm.swapusage", &swapUsage, &swapSize, nil, 0)
        let swapUsedGB = swapResult == 0 ? Double(swapUsage.xsu_used) / 1_073_741_824.0 : 0.0
        
        // 4. Calculate systemUsedGB: wired + active (non-AI processes)
        let systemUsedGB = max(0.0, wiredGB + activeGB - aiModelsGB)
        
        let state = SystemMemoryState(
            totalGB: totalGB,
            systemUsedGB: systemUsedGB,
            aiModelsGB: aiModelsGB,
            freeGB: freeGB,
            swapUsedGB: swapUsedGB,
            inactiveGB: inactiveGB,
            timestamp: Date()
        )
        
        return state
    }
    
    public func startPolling(interval: TimeInterval) {
        stopPolling()
        self.interval = interval
        
        pollingTask = Task { [weak self] in
            guard let self = self else { return }
            while !Task.isCancelled {
                let state = await self.snapshot()
                if let handler = await self.onUpdateHandler {
                    handler(state)
                }
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    break
                }
            }
        }
    }
    
    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }
}
