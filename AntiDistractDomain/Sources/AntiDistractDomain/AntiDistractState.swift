import Foundation

public enum ScreenTimeAuthorizationState: String, Codable, Hashable, Sendable {
    case notDetermined
    case approved
    case denied
}

/// Everything the app and its extensions persist. Encoded as JSON in the App Group.
public struct AntiDistractState: Codable, Equatable, Sendable {
    public var hasCompletedOnboarding: Bool
    public var treeType: TreeType
    public var schedule: BlockSchedule
    /// `FamilyActivitySelection` encoded by the app layer. Domain treats it as opaque bytes;
    /// the app never learns which apps these are.
    public var encodedActivitySelection: Data?
    /// Number of selected apps/categories/web domains, used for diffing and empty checks.
    public var selectedItemCount: Int
    public var ledger: ProtectedHoursLedger
    public var authorizationState: ScreenTimeAuthorizationState
    /// Written by the monitor extension at `intervalDidStart` / `intervalDidEnd`.
    public var monitorReportsActiveWindow: Bool
    public var currentIntervalStart: Date?
    public var currentIntervalActivityName: String?
    /// Total at the last time the main screen animated, so growth animates only on increase.
    public var lastSeenProtectedHours: Double

    public init(
        hasCompletedOnboarding: Bool = false,
        treeType: TreeType = .oak,
        schedule: BlockSchedule = .default,
        encodedActivitySelection: Data? = nil,
        selectedItemCount: Int = 0,
        ledger: ProtectedHoursLedger = ProtectedHoursLedger(),
        authorizationState: ScreenTimeAuthorizationState = .notDetermined,
        monitorReportsActiveWindow: Bool = false,
        currentIntervalStart: Date? = nil,
        currentIntervalActivityName: String? = nil,
        lastSeenProtectedHours: Double = 0
    ) {
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.treeType = treeType
        self.schedule = schedule
        self.encodedActivitySelection = encodedActivitySelection
        self.selectedItemCount = selectedItemCount
        self.ledger = ledger
        self.authorizationState = authorizationState
        self.monitorReportsActiveWindow = monitorReportsActiveWindow
        self.currentIntervalStart = currentIntervalStart
        self.currentIntervalActivityName = currentIntervalActivityName
        self.lastSeenProtectedHours = lastSeenProtectedHours
    }

    public static let initial = AntiDistractState()

    public var hasSelectedApps: Bool { selectedItemCount > 0 && encodedActivitySelection != nil }

    public var growth: TreeGrowth { ledger.growth }

    /// Decoding tolerates older files that lack newer keys.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        treeType = try container.decodeIfPresent(TreeType.self, forKey: .treeType) ?? .oak
        schedule = try container.decodeIfPresent(BlockSchedule.self, forKey: .schedule) ?? .default
        encodedActivitySelection = try container.decodeIfPresent(Data.self, forKey: .encodedActivitySelection)
        selectedItemCount = try container.decodeIfPresent(Int.self, forKey: .selectedItemCount) ?? 0
        ledger = try container.decodeIfPresent(ProtectedHoursLedger.self, forKey: .ledger) ?? ProtectedHoursLedger()
        authorizationState = try container.decodeIfPresent(
            ScreenTimeAuthorizationState.self,
            forKey: .authorizationState
        ) ?? .notDetermined
        monitorReportsActiveWindow = try container.decodeIfPresent(
            Bool.self,
            forKey: .monitorReportsActiveWindow
        ) ?? false
        currentIntervalStart = try container.decodeIfPresent(Date.self, forKey: .currentIntervalStart)
        currentIntervalActivityName = try container.decodeIfPresent(
            String.self,
            forKey: .currentIntervalActivityName
        )
        lastSeenProtectedHours = try container.decodeIfPresent(Double.self, forKey: .lastSeenProtectedHours) ?? 0
    }
}
