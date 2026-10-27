import Foundation

/// A wall-clock time with no date attached, used for schedule boundaries.
///
/// Wall-clock comparison (rather than absolute `Date` arithmetic) is deliberate: a window
/// written as 22:00–06:00 should mean those local times on every calendar day, including
/// days where a daylight-saving transition makes the real elapsed duration 23 or 25 hours.
public struct TimeOfDay: Codable, Hashable, Comparable, Sendable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    public var minutesSinceMidnight: Int { hour * 60 + minute }

    public static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        lhs.minutesSinceMidnight < rhs.minutesSinceMidnight
    }

    /// The time of day of `date` in `calendar`'s time zone.
    public static func from(date: Date, calendar: Calendar) -> TimeOfDay {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return TimeOfDay(hour: components.hour ?? 0, minute: components.minute ?? 0)
    }

    public var formatted: String { String(format: "%02d:%02d", hour, minute) }
}
