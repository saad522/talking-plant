import Darwin

/// The process footprint (what jetsam counts) and its peak so far, from `task_vm_info`.
public struct KokoroMemory: Equatable, Sendable {
    public let currentBytes: UInt64
    public let peakBytes: UInt64

    public init(currentBytes: UInt64, peakBytes: UInt64) {
        self.currentBytes = currentBytes
        self.peakBytes = peakBytes
    }

    public static func current() -> KokoroMemory? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        return KokoroMemory(
            currentBytes: info.phys_footprint,
            peakBytes: UInt64(max(info.ledger_phys_footprint_peak, 0))
        )
    }

    var megabytesDescription: String {
        let megabyte = 1_048_576.0
        return String(format: "%.0f MB now, %.0f MB peak", Double(currentBytes) / megabyte, Double(peakBytes) / megabyte)
    }
}
