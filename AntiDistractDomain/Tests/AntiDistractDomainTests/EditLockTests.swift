import XCTest
@testable import AntiDistractDomain

final class EditLockTests: XCTestCase {
    private let windowEnd = TimeOfDay(hour: 6, minute: 0)

    private let currentSchedule = BlockSchedule(
        start: TimeOfDay(hour: 22, minute: 0),
        end: TimeOfDay(hour: 6, minute: 0),
        weekdays: [.monday, .tuesday]
    )

    // MARK: - Blocklist

    func testAddingAppsIsAllowedDuringActiveWindow() {
        let decision = EditLockPolicy.decideBlocklistChange(
            BlocklistChange(addedCount: 2, removedCount: 0),
            isWindowActive: true,
            windowEnd: windowEnd
        )
        XCTAssertTrue(decision.isAllowed)
    }

    func testRemovingAppsIsRejectedDuringActiveWindow() {
        let decision = EditLockPolicy.decideBlocklistChange(
            BlocklistChange(addedCount: 0, removedCount: 1),
            isWindowActive: true,
            windowEnd: windowEnd
        )
        XCTAssertEqual(decision, .rejected(reason: .wouldRemoveApps(endTime: windowEnd)))
        XCTAssertEqual(
            decision.rejectionMessage,
            "Apps can't be removed until 06:00."
        )
    }

    func testSwappingAppsIsRejectedDuringActiveWindowEvenWhenCountIsEqual() {
        let decision = EditLockPolicy.decideBlocklistChange(
            BlocklistChange(addedCount: 1, removedCount: 1),
            isWindowActive: true,
            windowEnd: windowEnd
        )
        XCTAssertFalse(decision.isAllowed)
    }

    func testRemovingAppsIsAllowedOutsideWindow() {
        let decision = EditLockPolicy.decideBlocklistChange(
            BlocklistChange(addedCount: 0, removedCount: 5),
            isWindowActive: false,
            windowEnd: nil
        )
        XCTAssertTrue(decision.isAllowed)
    }

    func testNoChangeIsAlwaysAllowed() {
        XCTAssertTrue(
            EditLockPolicy.decideBlocklistChange(
                .none,
                isWindowActive: true,
                windowEnd: windowEnd
            ).isAllowed
        )
    }

    func testBlocklistChangeClampsNegativeCounts() {
        let change = BlocklistChange(addedCount: -4, removedCount: -2)
        XCTAssertEqual(change.addedCount, 0)
        XCTAssertEqual(change.removedCount, 0)
        XCTAssertTrue(change.isStricterOrEqual)
    }

    // MARK: - Schedule

    func testScheduleChangeRejectedDuringActiveWindow() {
        var proposed = currentSchedule
        proposed.end = TimeOfDay(hour: 5, minute: 0)

        let decision = EditLockPolicy.decideScheduleChange(
            from: currentSchedule,
            to: proposed,
            isWindowActive: true,
            windowEnd: windowEnd
        )
        XCTAssertEqual(decision, .rejected(reason: .windowActive(endTime: windowEnd)))
        XCTAssertEqual(decision.rejectionMessage, "Locked until 06:00, while blocking is active.")
    }

    func testDisablingScheduleRejectedDuringActiveWindow() {
        var proposed = currentSchedule
        proposed.isEnabled = false

        XCTAssertFalse(
            EditLockPolicy.decideScheduleChange(
                from: currentSchedule,
                to: proposed,
                isWindowActive: true,
                windowEnd: windowEnd
            ).isAllowed
        )
    }

    func testIdenticalScheduleIsAllowedDuringActiveWindow() {
        XCTAssertTrue(
            EditLockPolicy.decideScheduleChange(
                from: currentSchedule,
                to: currentSchedule,
                isWindowActive: true,
                windowEnd: windowEnd
            ).isAllowed
        )
    }

    func testScheduleChangeAllowedOutsideWindow() {
        var proposed = currentSchedule
        proposed.weekdays = [.friday]

        XCTAssertTrue(
            EditLockPolicy.decideScheduleChange(
                from: currentSchedule,
                to: proposed,
                isWindowActive: false,
                windowEnd: nil
            ).isAllowed
        )
    }

    func testInvalidScheduleRejectedEvenOutsideWindow() {
        var proposed = currentSchedule
        proposed.end = proposed.start

        let decision = EditLockPolicy.decideScheduleChange(
            from: currentSchedule,
            to: proposed,
            isWindowActive: false,
            windowEnd: nil
        )
        XCTAssertEqual(decision, .rejected(reason: .scheduleInvalid(.startEqualsEnd)))
        XCTAssertEqual(decision.rejectionMessage, "Start and end times must be different.")
    }

    func testEmptyWeekdaysRejected() {
        var proposed = currentSchedule
        proposed.weekdays = []

        XCTAssertEqual(
            EditLockPolicy.decideScheduleChange(
                from: currentSchedule,
                to: proposed,
                isWindowActive: false,
                windowEnd: nil
            ),
            .rejected(reason: .scheduleInvalid(.noWeekdaysSelected))
        )
    }

    // MARK: - Editor availability

    func testEditorsClosedOnlyWhileWindowIsActive() {
        XCTAssertFalse(EditLockPolicy.canOpenEditors(isWindowActive: true))
        XCTAssertTrue(EditLockPolicy.canOpenEditors(isWindowActive: false))
    }

    func testReasonMessagesWithoutEndTime() {
        XCTAssertEqual(
            EditLockReason.windowActive(endTime: nil).userFacingMessage,
            "Locked while blocking is active."
        )
        XCTAssertEqual(
            EditLockReason.wouldRemoveApps(endTime: nil).userFacingMessage,
            "Apps can't be removed while blocking is active."
        )
    }

    // MARK: - WindowStatus

    func testWindowStatusActiveFromScheduleAlone() {
        let calendar = TestCalendar.newYork()
        let state = AntiDistractState.onboarded(schedule: currentSchedule)
        let mondayNight = TestDate.make(
            year: 2026, month: 3, day: 2, hour: 23, minute: 0, calendar: calendar
        )
        let status = WindowStatus(state: state, now: mondayNight, calendar: calendar)

        XCTAssertTrue(status.isActive)
        XCTAssertTrue(status.scheduleSaysActive)
        XCTAssertFalse(status.monitorSaysActive)
        XCTAssertFalse(status.canOpenEditors)
        XCTAssertEqual(status.windowEnd, windowEnd)
        XCTAssertFalse(status.isGrowthPaused)
    }

    func testWindowStatusActiveFromMonitorFlagAlone() {
        let calendar = TestCalendar.newYork()
        var state = AntiDistractState.onboarded(schedule: currentSchedule)
        state.monitorReportsActiveWindow = true
        let mondayNoon = TestDate.make(
            year: 2026, month: 3, day: 2, hour: 12, minute: 0, calendar: calendar
        )
        let status = WindowStatus(state: state, now: mondayNoon, calendar: calendar)

        XCTAssertTrue(status.isActive)
        XCTAssertFalse(status.scheduleSaysActive)
        XCTAssertTrue(status.monitorSaysActive)
    }

    func testWindowStatusInactiveAndEditableOutsideWindow() {
        let calendar = TestCalendar.newYork()
        let state = AntiDistractState.onboarded(schedule: currentSchedule)
        let mondayNoon = TestDate.make(
            year: 2026, month: 3, day: 2, hour: 12, minute: 0, calendar: calendar
        )
        let status = WindowStatus(state: state, now: mondayNoon, calendar: calendar)

        XCTAssertFalse(status.isActive)
        XCTAssertTrue(status.canOpenEditors)
        XCTAssertNil(status.windowEnd)
    }

    func testWindowStatusWithoutAuthorizationIsNotActiveAndPausesGrowth() {
        let calendar = TestCalendar.newYork()
        var state = AntiDistractState.onboarded(
            schedule: currentSchedule,
            authorizationState: .denied
        )
        state.monitorReportsActiveWindow = true
        let mondayNight = TestDate.make(
            year: 2026, month: 3, day: 2, hour: 23, minute: 0, calendar: calendar
        )
        let status = WindowStatus(state: state, now: mondayNight, calendar: calendar)

        XCTAssertFalse(status.isActive)
        XCTAssertTrue(status.isGrowthPaused)
        // Editing opens back up, because the app can no longer enforce anything.
        XCTAssertTrue(status.canOpenEditors)
    }
}

private extension EditLockDecision {
    var rejectionMessage: String? {
        switch self {
        case .allowed: return nil
        case .rejected(let reason): return reason.userFacingMessage
        }
    }
}
