import XCTest
@testable import AntiDistractDomain

final class TreeGrowthTests: XCTestCase {
    func testStageAtEveryThreshold() {
        let expectations: [(hours: Double, stageIndex: Int, stageName: String)] = [
            (0, 1, "Seed"),
            (3, 2, "Sprout"),
            (10, 3, "Sapling"),
            (25, 4, "Young"),
            (60, 5, "Mature"),
            (120, 6, "Ancient")
        ]
        for expectation in expectations {
            let growth = TreeGrowth(protectedHours: expectation.hours)
            XCTAssertEqual(growth.stage.index, expectation.stageIndex, "at \(expectation.hours)h")
            XCTAssertEqual(growth.stage.name, expectation.stageName, "at \(expectation.hours)h")
        }
    }

    func testStageJustBelowEachThreshold() {
        XCTAssertEqual(TreeGrowth(protectedHours: 2.99).stage.index, 1)
        XCTAssertEqual(TreeGrowth(protectedHours: 9.99).stage.index, 2)
        XCTAssertEqual(TreeGrowth(protectedHours: 24.99).stage.index, 3)
        XCTAssertEqual(TreeGrowth(protectedHours: 59.99).stage.index, 4)
        XCTAssertEqual(TreeGrowth(protectedHours: 119.99).stage.index, 5)
    }

    func testBeyondMaximumStaysAtFinalStage() {
        let growth = TreeGrowth(protectedHours: 10_000)
        XCTAssertEqual(growth.stage.index, 6)
        XCTAssertNil(growth.nextStage)
        XCTAssertNil(growth.remainingHoursUntilNextStage)
        XCTAssertTrue(growth.isFullyGrown)
        XCTAssertEqual(growth.visualProgress, 1, accuracy: 0.0001)
        XCTAssertEqual(growth.visualScale, 1, accuracy: 0.0001)
        XCTAssertEqual(growth.progressWithinStage, 1, accuracy: 0.0001)
    }

    func testNegativeHoursClampToZero() {
        let growth = TreeGrowth(protectedHours: -50)
        XCTAssertEqual(growth.protectedHours, 0)
        XCTAssertEqual(growth.stage.index, 1)
        XCTAssertEqual(growth.visualProgress, 0, accuracy: 0.0001)
        XCTAssertEqual(growth.visualScale, GrowthConfiguration.minimumVisualScale, accuracy: 0.0001)
    }

    func testRemainingHoursUntilNextStage() {
        XCTAssertEqual(TreeGrowth(protectedHours: 0).remainingHoursUntilNextStage ?? -1, 3, accuracy: 0.0001)
        XCTAssertEqual(TreeGrowth(protectedHours: 1.5).remainingHoursUntilNextStage ?? -1, 1.5, accuracy: 0.0001)
        // Exactly at a threshold, the next stage is the following one.
        XCTAssertEqual(TreeGrowth(protectedHours: 3).remainingHoursUntilNextStage ?? -1, 7, accuracy: 0.0001)
        XCTAssertEqual(TreeGrowth(protectedHours: 60).remainingHoursUntilNextStage ?? -1, 60, accuracy: 0.0001)
    }

    func testProgressWithinStage() {
        XCTAssertEqual(TreeGrowth(protectedHours: 0).progressWithinStage, 0, accuracy: 0.0001)
        // Halfway between 3 and 10 is 6.5.
        XCTAssertEqual(TreeGrowth(protectedHours: 6.5).progressWithinStage, 0.5, accuracy: 0.0001)
        XCTAssertEqual(TreeGrowth(protectedHours: 3).progressWithinStage, 0, accuracy: 0.0001)
        XCTAssertEqual(TreeGrowth(protectedHours: 120).progressWithinStage, 1, accuracy: 0.0001)
    }

    func testVisualProgressIsLogShapedAndBounded() {
        let maximumHours = GrowthConfiguration.maximumHours
        XCTAssertEqual(TreeGrowth(protectedHours: 0).visualProgress, 0, accuracy: 0.0001)
        XCTAssertEqual(TreeGrowth(protectedHours: maximumHours).visualProgress, 1, accuracy: 0.0001)

        let expectedAtTen = log(1 + 10) / log(1 + maximumHours)
        XCTAssertEqual(TreeGrowth(protectedHours: 10).visualProgress, expectedAtTen, accuracy: 0.0001)

        // Log shape: the first half of the hours delivers well over half the visual growth.
        let halfwayProgress = TreeGrowth(protectedHours: maximumHours / 2).visualProgress
        XCTAssertGreaterThan(halfwayProgress, 0.8)
        XCTAssertLessThan(halfwayProgress, 1)
    }

    func testVisualProgressIsMonotonic() {
        var previousProgress = -1.0
        for hours in stride(from: 0.0, through: 140.0, by: 0.5) {
            let progress = TreeGrowth(protectedHours: hours).visualProgress
            XCTAssertGreaterThanOrEqual(progress, previousProgress, "at \(hours)h")
            XCTAssertGreaterThanOrEqual(progress, 0)
            XCTAssertLessThanOrEqual(progress, 1)
            previousProgress = progress
        }
    }

    func testVisualScaleNeverCollapsesToZero() {
        for hours in stride(from: 0.0, through: 120.0, by: 1.0) {
            let scale = TreeGrowth(protectedHours: hours).visualScale
            XCTAssertGreaterThanOrEqual(scale, GrowthConfiguration.minimumVisualScale)
            XCTAssertLessThanOrEqual(scale, 1.0001)
        }
    }

    func testStageThresholdsAreOrderedAndStartAtZero() {
        let stages = GrowthConfiguration.stages
        XCTAssertEqual(stages.count, 6)
        XCTAssertEqual(stages.first?.thresholdHours, 0)
        for (index, stage) in stages.enumerated() {
            XCTAssertEqual(stage.index, index + 1)
            if index > 0 {
                XCTAssertGreaterThan(stage.thresholdHours, stages[index - 1].thresholdHours)
            }
        }
    }

    func testTreeTypeMetadataIsComplete() {
        for treeType in TreeType.allCases {
            XCTAssertFalse(treeType.displayName.isEmpty)
            XCTAssertFalse(treeType.shortDescription.isEmpty)
        }
        XCTAssertEqual(TreeType.allCases.count, 3)
    }
}
