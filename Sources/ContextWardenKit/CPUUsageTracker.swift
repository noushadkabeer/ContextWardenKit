import Foundation
import MachO

public final class CPUUsageTracker {
    private var previousCpuInfo: processor_info_array_t?
    private var previousCpuCount: mach_msg_type_number_t = 0
    
    public init() {}
    
    deinit {
        if let prev = previousCpuInfo {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(previousCpuCount * mach_msg_type_number_t(MemoryLayout<Int32>.size)))
        }
    }
    
    public func getCPUUsage() -> Double {
        var processorCount: mach_msg_type_number_t = 0
        var processorInfo: processor_info_array_t?
        var processorInfoCount: mach_msg_type_number_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &processorCount, &processorInfo, &processorInfoCount)
        
        guard result == KERN_SUCCESS, let info = processorInfo else {
            return 0.0
        }
        
        defer {
            if let prev = previousCpuInfo {
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prev), vm_size_t(previousCpuCount * mach_msg_type_number_t(MemoryLayout<Int32>.size)))
            }
            previousCpuInfo = info
            previousCpuCount = processorInfoCount
        }
        
        guard let prevInfo = previousCpuInfo else {
            return 0.0 // Needs a delta to compute usage
        }
        
        var totalUsage = 0.0
        
        for i in 0..<Int(processorCount) {
            let base = i * Int(CPU_STATE_MAX)
            let user = Double(info[base + Int(CPU_STATE_USER)] - prevInfo[base + Int(CPU_STATE_USER)])
            let system = Double(info[base + Int(CPU_STATE_SYSTEM)] - prevInfo[base + Int(CPU_STATE_SYSTEM)])
            let idle = Double(info[base + Int(CPU_STATE_IDLE)] - prevInfo[base + Int(CPU_STATE_IDLE)])
            let nice = Double(info[base + Int(CPU_STATE_NICE)] - prevInfo[base + Int(CPU_STATE_NICE)])
            
            let total = user + system + idle + nice
            if total > 0 {
                let used = (user + system + nice) / total
                totalUsage += used
            }
        }
        
        return (totalUsage / Double(processorCount)) * 100.0
    }
}
