import Foundation

/// A monotonic span of time that also builds for iOS 15.4.
///
/// `Swift.Duration` (and `ContinuousClock`) are iOS 16 / macOS 13 only. The
/// transport layer needs the same arithmetic on older systems, so this value
/// mirrors the small surface Clawket actually uses: construction from seconds /
/// milliseconds, `+`, `-`, scaling, comparison and `components`.
public struct CompatDuration: Sendable, Hashable, Comparable, AdditiveArithmetic, CustomStringConvertible {
    /// Whole nanoseconds. Spans here are at most a few minutes, so `Int64` is ample.
    public var nanoseconds: Int64

    public init(nanoseconds: Int64) {
        self.nanoseconds = nanoseconds
    }

    public static let zero = CompatDuration(nanoseconds: 0)

    public static func seconds<T: BinaryInteger>(_ value: T) -> CompatDuration {
        CompatDuration(nanoseconds: Int64(value) * 1_000_000_000)
    }

    public static func seconds(_ value: Double) -> CompatDuration {
        CompatDuration(nanoseconds: Int64((value * 1_000_000_000).rounded()))
    }

    public static func milliseconds<T: BinaryInteger>(_ value: T) -> CompatDuration {
        CompatDuration(nanoseconds: Int64(value) * 1_000_000)
    }

    public static func milliseconds(_ value: Double) -> CompatDuration {
        CompatDuration(nanoseconds: Int64((value * 1_000_000).rounded()))
    }

    public static func microseconds<T: BinaryInteger>(_ value: T) -> CompatDuration {
        CompatDuration(nanoseconds: Int64(value) * 1_000)
    }

    public static func + (lhs: CompatDuration, rhs: CompatDuration) -> CompatDuration {
        CompatDuration(nanoseconds: lhs.nanoseconds + rhs.nanoseconds)
    }

    public static func - (lhs: CompatDuration, rhs: CompatDuration) -> CompatDuration {
        CompatDuration(nanoseconds: lhs.nanoseconds - rhs.nanoseconds)
    }

    public static func += (lhs: inout CompatDuration, rhs: CompatDuration) {
        lhs = lhs + rhs
    }

    public static func -= (lhs: inout CompatDuration, rhs: CompatDuration) {
        lhs = lhs - rhs
    }

    public static prefix func - (value: CompatDuration) -> CompatDuration {
        CompatDuration(nanoseconds: -value.nanoseconds)
    }

    public static func * <T: BinaryInteger>(lhs: CompatDuration, rhs: T) -> CompatDuration {
        CompatDuration(nanoseconds: lhs.nanoseconds * Int64(rhs))
    }

    public static func * <T: BinaryInteger>(lhs: T, rhs: CompatDuration) -> CompatDuration {
        rhs * lhs
    }

    public static func < (lhs: CompatDuration, rhs: CompatDuration) -> Bool {
        lhs.nanoseconds < rhs.nanoseconds
    }

    /// Matches `CompatDuration.components`: whole seconds plus the sub-second remainder
    /// in attoseconds (1e-18 s).
    public var components: (seconds: Int64, attoseconds: Int64) {
        let seconds = nanoseconds / 1_000_000_000
        let remainder = nanoseconds % 1_000_000_000
        return (seconds, remainder * 1_000_000_000)
    }

    public var description: String {
        let (seconds, attoseconds) = components
        if attoseconds == 0 { return "\(seconds)s" }
        let milliseconds = Double(attoseconds) / 1_000_000_000_000_000
        return "\(Double(seconds) + milliseconds)s"
    }
}

extension CompatDuration {
    /// Convenience for the places that used `Instant.duration(to:)`.
    public func duration(to other: CompatDuration) -> CompatDuration {
        other - self
    }

    public func advanced(by duration: CompatDuration) -> CompatDuration {
        self + duration
    }
}
