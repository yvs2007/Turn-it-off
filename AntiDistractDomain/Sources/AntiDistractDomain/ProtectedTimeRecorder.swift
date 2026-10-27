import Foundation

/// The state transitions the monitor extension performs, kept here so interval crediting
/// is unit-testable without DeviceActivity.
public enum ProtectedTimeRecorder {
    /// Called at `intervalDidStart`.
    public static func beginInterval(
        in state: inout AntiDistractState,
        activityName: String,
        at date: Date
    ) {
        state.monitorReportsActiveWindow = true
        state.currentIntervalStart = date
        state.currentIntervalActivityName = activityName
    }

    /// Called at `intervalDidEnd`, and also at app launch to close out a window the
    /// extension never got to finish.
    ///
    /// Returns the credited interval, or nil when there was nothing open to close.
    @discardableResult
    public static func endInterval(
        in state: inout AntiDistractState,
        activityName: String,
        at date: Date
    ) -> ProtectedInterval? {
        defer {
            state.monitorReportsActiveWindow = false
            state.currentIntervalStart = nil
            state.currentIntervalActivityName = nil
        }

        guard let start = state.currentIntervalStart else { return nil }

        let interval = ProtectedInterval(
            activityName: activityName,
            start: start,
            end: date,
            wasAuthorized: state.authorizationState == .approved
        )
        state.ledger.credit(interval)
        return interval
    }

    /// True when the stored state claims a window is open but the schedule says it ended —
    /// for example the extension was never woken because the device was off.
    public static func hasStaleOpenInterval(
        state: AntiDistractState,
        now: Date,
        calendar: Calendar = .current
    ) -> Bool {
        guard state.monitorReportsActiveWindow, state.currentIntervalStart != nil else { return false }
        return !state.schedule.isActive(at: now, calendar: calendar)
    }
}
