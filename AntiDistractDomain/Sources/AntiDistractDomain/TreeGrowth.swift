import Foundation

/// Maps cumulative protected hours onto a stage and a drawing size.
public struct TreeGrowth: Equatable, Sendable {
    public let protectedHours: Double

    public init(protectedHours: Double) {
        self.protectedHours = max(protectedHours, 0)
    }

    /// Highest stage whose threshold has been reached. Never nil: stage 1 is at 0 hours.
    public var stage: GrowthStage {
        let reached = GrowthConfiguration.stages.last { protectedHours >= $0.thresholdHours }
        return reached ?? GrowthConfiguration.stages[0]
    }

    public var nextStage: GrowthStage? {
        GrowthConfiguration.stages.first { $0.thresholdHours > protectedHours }
    }

    public var isFullyGrown: Bool { nextStage == nil }

    /// Hours left before the next stage, or nil at the final stage.
    public var remainingHoursUntilNextStage: Double? {
        guard let nextStage else { return nil }
        return max(nextStage.thresholdHours - protectedHours, 0)
    }

    /// Fraction of the way from the current stage threshold to the next one, 0…1.
    /// At the final stage this is 1.
    public var progressWithinStage: Double {
        guard let nextStage else { return 1 }
        let floorHours = stage.thresholdHours
        let span = nextStage.thresholdHours - floorHours
        guard span > 0 else { return 1 }
        return clamp((protectedHours - floorHours) / span)
    }

    /// Log-shaped overall progress used to drive visual size, 0…1.
    /// Early hours move the tree a lot, later hours progressively less.
    public var visualProgress: Double {
        let maximumHours = GrowthConfiguration.maximumHours
        guard maximumHours > 0 else { return 1 }
        let numerator = log(1 + min(protectedHours, maximumHours))
        let denominator = log(1 + maximumHours)
        guard denominator > 0 else { return 1 }
        return clamp(numerator / denominator)
    }

    /// Overall drawing scale, kept above a floor so a seed is still visible.
    public var visualScale: Double {
        let floorScale = GrowthConfiguration.minimumVisualScale
        return floorScale + (1 - floorScale) * visualProgress
    }

    private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
}
