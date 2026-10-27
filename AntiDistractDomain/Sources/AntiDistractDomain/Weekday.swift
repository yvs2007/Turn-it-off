import Foundation

/// Days of the week, using the same raw values as `Calendar`'s `weekday` component
/// (1 = Sunday … 7 = Saturday) so conversions never need a lookup table.
public enum Weekday: Int, Codable, CaseIterable, Hashable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    public static func from(date: Date, calendar: Calendar) -> Weekday {
        let rawWeekday = calendar.component(.weekday, from: date)
        return Weekday(rawValue: rawWeekday) ?? .sunday
    }

    public var next: Weekday {
        Weekday(rawValue: rawValue == 7 ? 1 : rawValue + 1) ?? .sunday
    }

    public var previous: Weekday {
        Weekday(rawValue: rawValue == 1 ? 7 : rawValue - 1) ?? .saturday
    }

    public var fullName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }

    public var shortName: String { String(fullName.prefix(3)) }

    /// Monday-first ordering for the weekday picker; storage still uses `Calendar` raw values.
    public static let displayOrder: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday
    ]
}
