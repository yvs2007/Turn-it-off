import Foundation

/// How a proposed blocklist change compares to the stored one.
/// Computed in the app layer by diffing opaque token sets, so Domain never sees tokens.
public struct BlocklistChange: Equatable, Sendable {
    public let addedCount: Int
    public let removedCount: Int

    public init(addedCount: Int, removedCount: Int) {
        self.addedCount = max(addedCount, 0)
        self.removedCount = max(removedCount, 0)
    }

    public static let none = BlocklistChange(addedCount: 0, removedCount: 0)

    /// True when the change only ever adds restrictions.
    public var isStricterOrEqual: Bool { removedCount == 0 }
}

public enum EditLockDecision: Equatable, Sendable {
    case allowed
    case rejected(reason: EditLockReason)

    public var isAllowed: Bool { self == .allowed }
}

public enum EditLockReason: Equatable, Sendable {
    case windowActive(endTime: TimeOfDay?)
    case wouldRemoveApps(endTime: TimeOfDay?)
    case scheduleInvalid(ScheduleValidationError)

    /// One short sentence for the UI.
    public var userFacingMessage: String {
        switch self {
        case .windowActive(let endTime):
            if let endTime {
                return "Locked until \(endTime.formatted), while blocking is active."
            }
            return "Locked while blocking is active."
        case .wouldRemoveApps(let endTime):
            if let endTime {
                return "Apps can't be removed until \(endTime.formatted)."
            }
            return "Apps can't be removed while blocking is active."
        case .scheduleInvalid(let error):
            return error.userFacingMessage
        }
    }
}

/// The edit-lock rules. The same `isWindowActive` input is used by the UI and by the
/// validation path, so a button's enabled state and the rule behind it can't drift apart.
public enum EditLockPolicy {
    /// Blocklist edits: locked only against loosening. Adding apps stays legal because
    /// stricter is always fine.
    public static func decideBlocklistChange(
        _ change: BlocklistChange,
        isWindowActive: Bool,
        windowEnd: TimeOfDay?
    ) -> EditLockDecision {
        guard isWindowActive, !change.isStricterOrEqual else { return .allowed }
        return .rejected(reason: .wouldRemoveApps(endTime: windowEnd))
    }

    /// Schedule edits: fully locked during an active window, since any change could
    /// shorten or cancel the window the user already committed to.
    public static func decideScheduleChange(
        from currentSchedule: BlockSchedule,
        to proposedSchedule: BlockSchedule,
        isWindowActive: Bool,
        windowEnd: TimeOfDay?
    ) -> EditLockDecision {
        if let validationError = validationError(for: proposedSchedule) {
            return .rejected(reason: .scheduleInvalid(validationError))
        }
        if proposedSchedule == currentSchedule { return .allowed }
        if isWindowActive { return .rejected(reason: .windowActive(endTime: windowEnd)) }
        return .allowed
    }

    /// Whether the main screen's secondary actions should be tappable.
    /// The spec locks both while a window is running.
    public static func canOpenEditors(isWindowActive: Bool) -> Bool { !isWindowActive }

    private static func validationError(for schedule: BlockSchedule) -> ScheduleValidationError? {
        do {
            try schedule.validate()
            return nil
        } catch let error as ScheduleValidationError {
            return error
        } catch {
            return .startEqualsEnd
        }
    }
}
