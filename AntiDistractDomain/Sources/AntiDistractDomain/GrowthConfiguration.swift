import Foundation

public enum TreeType: String, Codable, CaseIterable, Hashable, Sendable {
    case oak
    case redwood
    case spruce

    public var displayName: String {
        switch self {
        case .oak: return "Oak"
        case .redwood: return "Redwood"
        case .spruce: return "Spruce"
        }
    }

    public var shortDescription: String {
        switch self {
        case .oak: return "Wide, round canopy"
        case .redwood: return "Very tall, narrow trunk"
        case .spruce: return "Layered triangular tiers"
        }
    }
}

public struct GrowthStage: Equatable, Hashable, Sendable {
    public let index: Int
    public let name: String
    public let thresholdHours: Double

    public init(index: Int, name: String, thresholdHours: Double) {
        self.index = index
        self.name = name
        self.thresholdHours = thresholdHours
    }
}

/// Every tunable number for growth lives here, as the spec asks.
public enum GrowthConfiguration {
    public static let stages: [GrowthStage] = [
        GrowthStage(index: 1, name: "Seed", thresholdHours: 0),
        GrowthStage(index: 2, name: "Sprout", thresholdHours: 3),
        GrowthStage(index: 3, name: "Sapling", thresholdHours: 10),
        GrowthStage(index: 4, name: "Young", thresholdHours: 25),
        GrowthStage(index: 5, name: "Mature", thresholdHours: 60),
        GrowthStage(index: 6, name: "Ancient", thresholdHours: 120)
    ]

    /// Hours at which `visualProgress` reaches 1.0 — the final stage threshold.
    public static var maximumHours: Double { stages.last?.thresholdHours ?? 120 }

    /// Smallest drawn size, so a seed is still visible rather than a dot.
    public static let minimumVisualScale: Double = 0.18

    /// Duration of the growth animation on the main screen.
    public static let growthAnimationDuration: Double = 1.5
}
