import Foundation

/// One completed blocking window. Written by the monitor extension at `intervalDidEnd`.
public struct ProtectedInterval: Codable, Equatable, Hashable, Sendable {
    public let activityName: String
    public let start: Date
    public let end: Date
    /// False when Screen Time authorization was not valid for the window, in which case
    /// the interval is recorded but earns nothing.
    public let wasAuthorized: Bool

    public init(activityName: String, start: Date, end: Date, wasAuthorized: Bool) {
        self.activityName = activityName
        self.start = start
        self.end = end
        self.wasAuthorized = wasAuthorized
    }

    /// Actual elapsed hours, so a window that was cut short credits only what it ran.
    public var creditedHours: Double {
        guard wasAuthorized else { return 0 }
        let elapsedSeconds = end.timeIntervalSince(start)
        // A non-positive or implausibly long span means the clock moved; credit nothing
        // rather than inventing hours.
        guard elapsedSeconds > 0, elapsedSeconds <= ProtectedHoursLedger.maximumIntervalSeconds else {
            return 0
        }
        return elapsedSeconds / 3600
    }
}

/// Append-only record of protected time. The total is the tree's growth metric.
public struct ProtectedHoursLedger: Codable, Equatable, Sendable {
    /// A single window longer than 24 hours cannot be real; treat it as a clock change.
    public static let maximumIntervalSeconds: Double = 24 * 60 * 60

    /// Keeps the stored file small; the running total is never recomputed from a trimmed tail.
    public static let maximumStoredIntervals = 400

    public private(set) var recentIntervals: [ProtectedInterval]
    public private(set) var totalProtectedHours: Double

    public init(recentIntervals: [ProtectedInterval] = [], totalProtectedHours: Double = 0) {
        self.recentIntervals = recentIntervals
        self.totalProtectedHours = max(totalProtectedHours, 0)
    }

    /// Records a finished window and adds its actual elapsed time to the total.
    public mutating func credit(_ interval: ProtectedInterval) {
        recentIntervals.append(interval)
        if recentIntervals.count > Self.maximumStoredIntervals {
            recentIntervals.removeFirst(recentIntervals.count - Self.maximumStoredIntervals)
        }
        totalProtectedHours += interval.creditedHours
    }

    public mutating func credit(
        activityName: String,
        start: Date,
        end: Date,
        wasAuthorized: Bool
    ) {
        credit(
            ProtectedInterval(
                activityName: activityName,
                start: start,
                end: end,
                wasAuthorized: wasAuthorized
            )
        )
    }

    public var growth: TreeGrowth { TreeGrowth(protectedHours: totalProtectedHours) }

    /// Resets growth, used when the user changes tree type.
    public mutating func reset() {
        recentIntervals = []
        totalProtectedHours = 0
    }
}
