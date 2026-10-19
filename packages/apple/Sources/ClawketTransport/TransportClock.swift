import Dispatch
import Foundation

public protocol TransportClock: Sendable {
    func now() -> CompatDuration
    func sleep(for duration: CompatDuration) async throws
}

public struct MonotonicTransportClock: TransportClock {
    private let origin = DispatchTime.now().uptimeNanoseconds

    public init() {}

    public func now() -> CompatDuration {
        let elapsed = DispatchTime.now().uptimeNanoseconds &- origin
        return CompatDuration(nanoseconds: Int64(clamping: elapsed))
    }

    public func sleep(for duration: CompatDuration) async throws {
        let nanoseconds = UInt64(clamping: max(0, duration.nanoseconds))
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

/// Socket opens never reset this policy. Only verified current-backend health does.
public struct ReconnectPolicy: Sendable, Equatable {
    public private(set) var attempt = 0

    public init() {}

    public mutating func nextDelay(randomUnit: Double = 0.5) -> CompatDuration {
        let base = min(15_000.0, 800.0 * pow(1.7, Double(min(attempt, 30))))
        attempt = min(attempt + 1, 31)
        let random = randomUnit.isFinite ? min(1, max(0, randomUnit)) : 0.5
        return .milliseconds(min(15_000, max(1, Int(base * (0.8 + random * 0.4)))))
    }

    public mutating func confirmedBackendReady() { attempt = 0 }
}
