import Darwin
import Dispatch
import os

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

    static func megabytes(_ bytes: UInt64) -> Int {
        Int((Double(bytes) / 1_048_576).rounded())
    }

    var megabytesDescription: String {
        let megabyte = 1_048_576.0
        return String(format: "%.0f MB now, %.0f MB peak", Double(currentBytes) / megabyte, Double(peakBytes) / megabyte)
    }
}

/// The peak footprint since a point in time. The kernel only keeps a peak since launch, so this
/// samples the footprint every 20 ms and also compares the kernel's peak against its value at the
/// start: when that grew, it is the exact peak of the window. Otherwise the highest sample wins,
/// which can miss a spike shorter than 20 ms.
public final class KokoroPeakWindow: @unchecked Sendable {
    private struct State {
        var kernelPeakAtStart: UInt64
        var highestSample: UInt64
    }

    private let state: OSAllocatedUnfairLock<State>
    private let timer: DispatchSourceTimer

    /// Starts sampling right away. Call `stop()` when done.
    public init(interval: DispatchTimeInterval = .milliseconds(20)) {
        let now = KokoroMemory.current()
        state = OSAllocatedUnfairLock(initialState: State(
            kernelPeakAtStart: now?.peakBytes ?? 0,
            highestSample: now?.currentBytes ?? 0
        ))
        timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "PlantKokoro.peak", qos: .utility))
        timer.schedule(deadline: .now() + interval, repeating: interval)
        let state = state
        timer.setEventHandler {
            guard let current = KokoroMemory.current()?.currentBytes else { return }
            state.withLock { $0.highestSample = max($0.highestSample, current) }
        }
        timer.resume()
    }

    public func stop() {
        timer.cancel()
    }

    /// Bytes. Safe to call while running.
    public var peakBytes: UInt64 {
        let now = KokoroMemory.current()
        return state.withLock { state in
            let sampled = max(state.highestSample, now?.currentBytes ?? 0)
            guard let kernelPeak = now?.peakBytes, kernelPeak > state.kernelPeakAtStart else { return sampled }
            return max(kernelPeak, sampled)
        }
    }

    deinit { timer.cancel() }
}
