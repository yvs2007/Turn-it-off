import Foundation

public enum ScheduleValidationError: Error, Equatable, CustomStringConvertible {
    case startEqualsEnd
    case noWeekdaysSelected

    public var description: String { userFacingMessage }

    /// One short sentence, safe to show in the UI.
    public var userFacingMessage: String {
        switch self {
        case .startEqualsEnd:
            return "Start and end times must be different."
        case .noWeekdaysSelected:
            return "Pick at least one day of the week."
        }
    }
}

/// The single daily blocking window, repeated on the selected weekdays.
public struct BlockSchedule: Codable, Equatable, Sendable {
    public var start: TimeOfDay
    public var end: TimeOfDay
    public var weekdays: Set<Weekday>
    public var isEnabled: Bool

    public init(
        start: TimeOfDay,
        end: TimeOfDay,
        weekdays: Set<Weekday>,
        isEnabled: Bool = true
    ) {
        self.start = start
        self.end = end
        self.weekdays = weekdays
        self.isEnabled = isEnabled
    }

    public static let `default` = BlockSchedule(
        start: TimeOfDay(hour: 22, minute: 0),
        end: TimeOfDay(hour: 6, minute: 0),
        weekdays: Set(Weekday.allCases)
    )

    /// True when the window runs past midnight, e.g. 22:00 → 06:00.
    public var spansMidnight: Bool { end < start }

    /// Nominal length in minutes. DST days can differ by an hour in real elapsed time;
    /// actual credited time always comes from the monitor extension's timestamps instead.
    public var nominalDurationMinutes: Int {
        let raw = end.minutesSinceMidnight - start.minutesSinceMidnight
        return raw > 0 ? raw : raw + 24 * 60
    }

    public func validate() throws {
        if start == end { throw ScheduleValidationError.startEqualsEnd }
        if weekdays.isEmpty { throw ScheduleValidationError.noWeekdaysSelected }
    }

    public var isValid: Bool {
        do {
            try validate()
            return true
        } catch {
            return false
        }
    }

    /// Whether the window covers `date`, evaluated in `calendar`'s time zone.
    ///
    /// A window belongs to the weekday it *starts* on. For an overnight window, the hours
    /// after midnight belong to the previous day's selection, so Friday 22:00 → 06:00 keeps
    /// blocking into Saturday morning even when Saturday itself is not selected.
    public func isActive(at date: Date, calendar: Calendar = .current) -> Bool {
        guard isEnabled, isValid else { return false }

        let timeOfDay = TimeOfDay.from(date: date, calendar: calendar)
        let weekday = Weekday.from(date: date, calendar: calendar)

        if spansMidnight {
            let inEveningPortion = weekdays.contains(weekday) && timeOfDay >= start
            let inMorningPortion = weekdays.contains(weekday.previous) && timeOfDay < end
            return inEveningPortion || inMorningPortion
        }

        return weekdays.contains(weekday) && timeOfDay >= start && timeOfDay < end
    }

    /// One descriptor per enabled weekday, ready to be turned into a system schedule.
    public var monitoredWindows: [ScheduledWindowDescriptor] {
        guard isEnabled, isValid else { return [] }
        return weekdays
            .sorted { $0.rawValue < $1.rawValue }
            .map { weekday in
                ScheduledWindowDescriptor(
                    startWeekday: weekday,
                    start: start,
                    endWeekday: spansMidnight ? weekday.next : weekday,
                    end: end
                )
            }
    }
}

/// A single weekly occurrence of the window, identified by a stable name so the app can
/// register, replace and stop monitoring without guessing.
public struct ScheduledWindowDescriptor: Equatable, Hashable, Sendable {
    public let startWeekday: Weekday
    public let start: TimeOfDay
    public let endWeekday: Weekday
    public let end: TimeOfDay

    public init(startWeekday: Weekday, start: TimeOfDay, endWeekday: Weekday, end: TimeOfDay) {
        self.startWeekday = startWeekday
        self.start = start
        self.endWeekday = endWeekday
        self.end = end
    }

    /// Stable identifier used as the `DeviceActivityName` raw value.
    public var activityName: String { "antidistract.window.\(startWeekday.rawValue)" }

    public static let activityNamePrefix = "antidistract.window."

    public static func weekday(fromActivityName name: String) -> Weekday? {
        guard name.hasPrefix(activityNamePrefix) else { return nil }
        let suffix = name.dropFirst(activityNamePrefix.count)
        guard let rawValue = Int(suffix) else { return nil }
        return Weekday(rawValue: rawValue)
    }
}
