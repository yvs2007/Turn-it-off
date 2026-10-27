import Foundation

/// Resolves "is blocking active right now" from the two sources the spec names:
/// the schedule math (same code the monitor uses) and the flag the extension writes.
///
/// Either source alone is enough to call the window active. The extension flag covers the
/// case where the app's own calendar math disagrees after a time zone change; the schedule
/// math covers an extension that has not fired yet or a flag left stale by a crash.
public struct WindowStatus: Equatable, Sendable {
    public let isActive: Bool
    public let scheduleSaysActive: Bool
    public let monitorSaysActive: Bool
    public let isGrowthPaused: Bool
    public let windowEnd: TimeOfDay?

    public init(state: AntiDistractState, now: Date, calendar: Calendar = .current) {
        let scheduleActive = state.schedule.isActive(at: now, calendar: calendar)
        let monitorActive = state.monitorReportsActiveWindow

        scheduleSaysActive = scheduleActive
        monitorSaysActive = monitorActive
        isActive = state.authorizationState == .approved && (scheduleActive || monitorActive)
        isGrowthPaused = state.authorizationState != .approved
        windowEnd = (scheduleActive || monitorActive) ? state.schedule.end : nil
    }

    public var canOpenEditors: Bool { EditLockPolicy.canOpenEditors(isWindowActive: isActive) }
}
