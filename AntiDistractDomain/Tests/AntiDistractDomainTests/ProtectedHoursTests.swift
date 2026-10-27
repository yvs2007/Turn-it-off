import XCTest
@testable import AntiDistractDomain

final class ProtectedHoursTests: XCTestCase {
    private let referenceDate = Date(timeIntervalSince1970: 1_772_000_000)

    private func interval(hours: Double, wasAuthorized: Bool = true) -> ProtectedInterval {
        ProtectedInterval(
            activityName: "antidistract.window.2",
            start: referenceDate,
            end: referenceDate.addingTimeInterval(hours * 3600),
            wasAuthorized: wasAuthorized
        )
    }

    func testFullIntervalCreditsItsDuration() {
        XCTAssertEqual(interval(hours: 8).creditedHours, 8, accuracy: 0.0001)
    }

    func testCutShortIntervalCreditsOnlyElapsedTime() {
        XCTAssertEqual(interval(hours: 2.5).creditedHours, 2.5, accuracy: 0.0001)
    }

    func testUnauthorizedIntervalCreditsNothing() {
        XCTAssertEqual(interval(hours: 8, wasAuthorized: false).creditedHours, 0)
    }

    func testBackwardsIntervalCreditsNothing() {
        let backwards = ProtectedInterval(
            activityName: "antidistract.window.2",
            start: referenceDate,
            end: referenceDate.addingTimeInterval(-3600),
            wasAuthorized: true
        )
        XCTAssertEqual(backwards.creditedHours, 0)
    }

    func testZeroLengthIntervalCreditsNothing() {
        XCTAssertEqual(interval(hours: 0).creditedHours, 0)
    }

    func testImplausiblyLongIntervalCreditsNothing() {
        XCTAssertEqual(interval(hours: 48).creditedHours, 0)
    }

    func testLedgerAccumulatesAndExposesGrowth() {
        var ledger = ProtectedHoursLedger()
        ledger.credit(interval(hours: 2))
        ledger.credit(interval(hours: 1.5))
        XCTAssertEqual(ledger.totalProtectedHours, 3.5, accuracy: 0.0001)
        XCTAssertEqual(ledger.recentIntervals.count, 2)
        XCTAssertEqual(ledger.growth.stage.name, "Sprout")
    }

    func testLedgerKeepsUnauthorizedIntervalsWithoutCrediting() {
        var ledger = ProtectedHoursLedger()
        ledger.credit(interval(hours: 8, wasAuthorized: false))
        XCTAssertEqual(ledger.totalProtectedHours, 0)
        XCTAssertEqual(ledger.recentIntervals.count, 1)
    }

    func testLedgerTrimsOldIntervalsButKeepsTotal() {
        var ledger = ProtectedHoursLedger()
        let creditCount = ProtectedHoursLedger.maximumStoredIntervals + 25
        for _ in 0..<creditCount {
            ledger.credit(interval(hours: 1))
        }
        XCTAssertEqual(ledger.recentIntervals.count, ProtectedHoursLedger.maximumStoredIntervals)
        XCTAssertEqual(ledger.totalProtectedHours, Double(creditCount), accuracy: 0.0001)
    }

    func testLedgerResetClearsEverything() {
        var ledger = ProtectedHoursLedger()
        ledger.credit(interval(hours: 30))
        ledger.reset()
        XCTAssertEqual(ledger.totalProtectedHours, 0)
        XCTAssertTrue(ledger.recentIntervals.isEmpty)
        XCTAssertEqual(ledger.growth.stage.index, 1)
    }

    // MARK: - Recorder

    func testRecorderBeginAndEndCreditsActualElapsedTime() {
        var state = AntiDistractState.onboarded()
        let start = referenceDate
        let end = referenceDate.addingTimeInterval(8 * 3600)

        ProtectedTimeRecorder.beginInterval(in: &state, activityName: "antidistract.window.2", at: start)
        XCTAssertTrue(state.monitorReportsActiveWindow)
        XCTAssertEqual(state.currentIntervalStart, start)
        XCTAssertEqual(state.currentIntervalActivityName, "antidistract.window.2")

        let credited = ProtectedTimeRecorder.endInterval(
            in: &state,
            activityName: "antidistract.window.2",
            at: end
        )
        XCTAssertEqual(credited?.creditedHours ?? 0, 8, accuracy: 0.0001)
        XCTAssertEqual(state.ledger.totalProtectedHours, 8, accuracy: 0.0001)
        XCTAssertFalse(state.monitorReportsActiveWindow)
        XCTAssertNil(state.currentIntervalStart)
        XCTAssertNil(state.currentIntervalActivityName)
    }

    func testRecorderEndWithoutBeginCreditsNothing() {
        var state = AntiDistractState.onboarded()
        let credited = ProtectedTimeRecorder.endInterval(
            in: &state,
            activityName: "antidistract.window.2",
            at: referenceDate
        )
        XCTAssertNil(credited)
        XCTAssertEqual(state.ledger.totalProtectedHours, 0)
        XCTAssertFalse(state.monitorReportsActiveWindow)
    }

    func testRecorderCreditsNothingWhenAuthorizationWasRevoked() {
        var state = AntiDistractState.onboarded(authorizationState: .approved)
        ProtectedTimeRecorder.beginInterval(
            in: &state,
            activityName: "antidistract.window.2",
            at: referenceDate
        )
        state.authorizationState = .denied

        ProtectedTimeRecorder.endInterval(
            in: &state,
            activityName: "antidistract.window.2",
            at: referenceDate.addingTimeInterval(4 * 3600)
        )
        XCTAssertEqual(state.ledger.totalProtectedHours, 0)
        XCTAssertEqual(state.ledger.recentIntervals.count, 1)
    }

    func testStaleOpenIntervalDetection() {
        let calendar = TestCalendar.newYork()
        let schedule = BlockSchedule(
            start: TimeOfDay(hour: 22, minute: 0),
            end: TimeOfDay(hour: 6, minute: 0),
            weekdays: [.monday]
        )
        var state = AntiDistractState.onboarded(schedule: schedule)
        let mondayNight = TestDate.make(
            year: 2026, month: 3, day: 2, hour: 23, minute: 0, calendar: calendar
        )
        ProtectedTimeRecorder.beginInterval(
            in: &state,
            activityName: "antidistract.window.2",
            at: mondayNight
        )

        let insideWindow = TestDate.make(
            year: 2026, month: 3, day: 3, hour: 2, minute: 0, calendar: calendar
        )
        XCTAssertFalse(
            ProtectedTimeRecorder.hasStaleOpenInterval(state: state, now: insideWindow, calendar: calendar)
        )

        let afterWindow = TestDate.make(
            year: 2026, month: 3, day: 3, hour: 9, minute: 0, calendar: calendar
        )
        XCTAssertTrue(
            ProtectedTimeRecorder.hasStaleOpenInterval(state: state, now: afterWindow, calendar: calendar)
        )
    }

    func testNoStaleIntervalWhenNothingIsOpen() {
        let calendar = TestCalendar.newYork()
        let state = AntiDistractState.onboarded()
        let anyTime = TestDate.make(
            year: 2026, month: 3, day: 3, hour: 9, minute: 0, calendar: calendar
        )
        XCTAssertFalse(
            ProtectedTimeRecorder.hasStaleOpenInterval(state: state, now: anyTime, calendar: calendar)
        )
    }
}
