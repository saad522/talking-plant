/// Decides whether an "incompatible" result gets one more service discovery. A peripheral that
/// restarts can be reached before it re-adds its services, which looks the same as a wrong
/// device. One retry covers that without a retry loop. A successful connection restores it.
struct IncompatibleRetryPolicy {
    private var isSpent = false

    /// True once per episode; the caller then reconnects and discovers services again.
    mutating func shouldRetry() -> Bool {
        guard !isSpent else { return false }
        isSpent = true
        return true
    }

    mutating func reset() {
        isSpent = false
    }
}
