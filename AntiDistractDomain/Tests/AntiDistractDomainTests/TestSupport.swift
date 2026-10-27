import Foundation
@testable import AntiDistractDomain

/// Fixed calendar so schedule assertions never depend on the machine's locale.
enum TestCalendar {
    static func newYork() -> Calendar {
        make(timeZoneIdentifier: "America/New_York")
    }

    static func utc() -> Calendar {
        make(timeZoneIdentifier: "UTC")
    }

    static func make(timeZoneIdentifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = timeZone
        }
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }
}

enum TestDate {
    /// Builds a local date in `calendar`. Returns `.distantPast` only if the components are
    /// impossible, which would fail the assertion using it rather than hide a mistake.
    static func make(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return calendar.date(from: components) ?? .distantPast
    }
}

extension AntiDistractState {
    static func onboarded(
        treeType: TreeType = .oak,
        schedule: BlockSchedule = .default,
        authorizationState: ScreenTimeAuthorizationState = .approved,
        selectedItemCount: Int = 3,
        totalProtectedHours: Double = 0
    ) -> AntiDistractState {
        AntiDistractState(
            hasCompletedOnboarding: true,
            treeType: treeType,
            schedule: schedule,
            encodedActivitySelection: Data([0x01, 0x02]),
            selectedItemCount: selectedItemCount,
            ledger: ProtectedHoursLedger(totalProtectedHours: totalProtectedHours),
            authorizationState: authorizationState
        )
    }
}
