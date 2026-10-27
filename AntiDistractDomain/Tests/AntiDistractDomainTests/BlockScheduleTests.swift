import XCTest
@testable import AntiDistractDomain

final class BlockScheduleTests: XCTestCase {
    private let calendar = TestCalendar.newYork()

    // 2026-03-02 is a Monday, which anchors every weekday assertion below.
    private func monday(hour: Int, minute: Int = 0) -> Date {
        TestDate.make(year: 2026, month: 3, day: 2, hour: hour, minute: minute, calendar: calendar)
    }

    private func tuesday(hour: Int, minute: Int = 0) -> Date {
        TestDate.make(year: 2026, month: 3, day: 3, hour: hour, minute: minute, calendar: calendar)
    }

    private func sunday(hour: Int, minute: Int = 0) -> Date {
        TestDate.make(year: 2026, month: 3, day: 1, hour: hour, minute: minute, calendar: calendar)
    }

    // MARK: - Validation

    func testStartEqualToEndIsInvalid() {
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 9, minute: 0),
            weekdays: [.monday]
        )
        XCTAssertFalse(schedule.isValid)
        XCTAssertThrowsError(try schedule.validate()) { error in
            XCTAssertEqual(error as? ScheduleValidationError, .startEqualsEnd)
        }
    }

    func testEmptyWeekdaysIsInvalid() {
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
            weekdays: []
        )
        XCTAssertThrowsError(try schedule.validate()) { error in
            XCTAssertEqual(error as? ScheduleValidationError, .noWeekdaysSelected)
        }
    }

    func testInvalidScheduleIsNeverActive() {
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 9, minute: 0),
            weekdays: [.monday]
        )
        XCTAssertFalse(schedule.isActive(at: monday(hour: 9), calendar: calendar))
    }

    // MARK: - Same-day window

    func testSameDayWindowActiveInsideBounds() {
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
            weekdays: [.monday]
        )
        XCTAssertFalse(schedule.spansMidnight)
        XCTAssertFalse(schedule.isActive(at: monday(hour: 8, minute: 59), calendar: calendar))
        XCTAssertTrue(schedule.isActive(at: monday(hour: 9, minute: 0), calendar: calendar))
        XCTAssertTrue(schedule.isActive(at: monday(hour: 16, minute: 59), calendar: calendar))
        XCTAssertFalse(schedule.isActive(at: monday(hour: 17, minute: 0), calendar: calendar))
    }

    func testSameDayWindowIgnoresUnselectedWeekday() {
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
            weekdays: [.monday]
        )
        XCTAssertFalse(schedule.isActive(at: tuesday(hour: 12), calendar: calendar))
    }

    func testDisabledScheduleIsNeverActive() {
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
            weekdays: [.monday],
            isEnabled: false
        )
        XCTAssertFalse(schedule.isActive(at: monday(hour: 12), calendar: calendar))
    }

    // MARK: - Overnight window

    func testOvernightWindowCoversEveningAndNextMorning() {
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 6, minute: 0),
            weekdays: [.monday]
        )
        XCTAssertTrue(schedule.spansMidnight)

        XCTAssertFalse(schedule.isActive(at: monday(hour: 21, minute: 59), calendar: calendar))
        XCTAssertTrue(schedule.isActive(at: monday(hour: 22, minute: 0), calendar: calendar))
        XCTAssertTrue(schedule.isActive(at: monday(hour: 23, minute: 59), calendar: calendar))
        // Tuesday morning still belongs to Monday's window.
        XCTAssertTrue(schedule.isActive(at: tuesday(hour: 0, minute: 1), calendar: calendar))
        XCTAssertTrue(schedule.isActive(at: tuesday(hour: 5, minute: 59), calendar: calendar))
        XCTAssertFalse(schedule.isActive(at: tuesday(hour: 6, minute: 0), calendar: calendar))
        // Monday morning belongs to Sunday's window, which is not selected.
        XCTAssertFalse(schedule.isActive(at: monday(hour: 3), calendar: calendar))
    }

    func testOvernightWindowFromSundayRollsIntoMonday() {
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 6, minute: 0),
            weekdays: [.sunday]
        )
        XCTAssertTrue(schedule.isActive(at: sunday(hour: 23), calendar: calendar))
        XCTAssertTrue(schedule.isActive(at: monday(hour: 5, minute: 30), calendar: calendar))
        XCTAssertFalse(schedule.isActive(at: monday(hour: 22), calendar: calendar))
    }

    func testNominalDuration() {
        let overnight = BlockSchedule(
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 6, minute: 30),
            weekdays: [.monday]
        )
        XCTAssertEqual(overnight.nominalDurationMinutes, 8 * 60 + 30)

        let sameDay = BlockSchedule(
            start: TimeOfDay(hour: 9, minute: 15),
            end: TimeOfDay(hour: 17, minute: 0),
            weekdays: [.monday]
        )
        XCTAssertEqual(sameDay.nominalDurationMinutes, 7 * 60 + 45)
    }

    // MARK: - Time zone and DST

    func testWindowUsesWallClockAcrossSpringForward() {
        // US DST starts 2026-03-08 at 02:00 local; 02:00–02:59 does not exist.
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 6, minute: 0),
            weekdays: Set(Weekday.allCases)
        )
        let beforeTransition = TestDate.make(
            year: 2026, month: 3, day: 8, hour: 1, minute: 30, calendar: calendar
        )
        let afterTransition = TestDate.make(
            year: 2026, month: 3, day: 8, hour: 5, minute: 30, calendar: calendar
        )
        let afterWindow = TestDate.make(
            year: 2026, month: 3, day: 8, hour: 7, minute: 0, calendar: calendar
        )
        XCTAssertTrue(schedule.isActive(at: beforeTransition, calendar: calendar))
        XCTAssertTrue(schedule.isActive(at: afterTransition, calendar: calendar))
        XCTAssertFalse(schedule.isActive(at: afterWindow, calendar: calendar))
    }

    func testSameInstantDiffersByCalendarTimeZone() {
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 6, minute: 0),
            weekdays: Set(Weekday.allCases)
        )
        // 23:00 in New York on 2026-03-02 is 04:00 UTC the next day: active in both zones,
        // but via different halves of the window.
        let instant = monday(hour: 23)
        XCTAssertTrue(schedule.isActive(at: instant, calendar: calendar))
        XCTAssertTrue(schedule.isActive(at: instant, calendar: TestCalendar.utc()))

        // 15:00 New York is 20:00 UTC: inactive in both.
        let afternoon = monday(hour: 15)
        XCTAssertFalse(schedule.isActive(at: afternoon, calendar: calendar))
        XCTAssertFalse(schedule.isActive(at: afternoon, calendar: TestCalendar.utc()))
    }

    // MARK: - Monitored windows

    func testMonitoredWindowsOnePerSelectedWeekday() {
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 6, minute: 0),
            weekdays: [.monday, .friday]
        )
        let windows = schedule.monitoredWindows
        XCTAssertEqual(windows.count, 2)

        guard let mondayWindow = windows.first(where: { $0.startWeekday == .monday }) else {
            return XCTFail("Expected a Monday window")
        }
        XCTAssertEqual(mondayWindow.endWeekday, .tuesday)
        XCTAssertEqual(mondayWindow.activityName, "antidistract.window.2")
        XCTAssertEqual(
            ScheduledWindowDescriptor.weekday(fromActivityName: mondayWindow.activityName),
            .monday
        )

        guard let fridayWindow = windows.first(where: { $0.startWeekday == .friday }) else {
            return XCTFail("Expected a Friday window")
        }
        XCTAssertEqual(fridayWindow.endWeekday, .saturday)
    }

    func testMonitoredWindowsStayOnSameDayWhenNotOvernight() {
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
            weekdays: [.wednesday]
        )
        XCTAssertEqual(schedule.monitoredWindows.first?.endWeekday, .wednesday)
    }

    func testMonitoredWindowsEmptyWhenDisabledOrInvalid() {
        let disabled = BlockSchedule(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 17, minute: 0),
            weekdays: [.monday],
            isEnabled: false
        )
        XCTAssertTrue(disabled.monitoredWindows.isEmpty)

        let invalid = BlockSchedule(
            start: TimeOfDay(hour: 9, minute: 0),
            end: TimeOfDay(hour: 9, minute: 0),
            weekdays: [.monday]
        )
        XCTAssertTrue(invalid.monitoredWindows.isEmpty)
    }

    func testUnknownActivityNameDoesNotMapToWeekday() {
        XCTAssertNil(ScheduledWindowDescriptor.weekday(fromActivityName: "something.else"))
        XCTAssertNil(ScheduledWindowDescriptor.weekday(fromActivityName: "antidistract.window.9"))
    }

    // MARK: - TimeOfDay

    func testTimeOfDayClampsOutOfRangeInput() {
        XCTAssertEqual(TimeOfDay(hour: 99, minute: 99).formatted, "23:59")
        XCTAssertEqual(TimeOfDay(hour: -3, minute: -1).formatted, "00:00")
    }
}
