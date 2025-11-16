import XCTest
@testable import SmithXCSift
import SmithCore

final class SmithXCSiftTests: XCTestCase {

    func testRebuildStrategySelection() throws {
        let analysis = BuildStateAnalysis()
        let options = RebuildOptions(
            parallel: true,
            preserveDependencies: true,
            aggressive: false,
            timeout: 300
        )

        // Test that strategy selection doesn't crash
        let strategy = determineRebuildStrategy(analysis: analysis, options: options)
        XCTAssertFalse(strategy.name.isEmpty)
        XCTAssertFalse(strategy.commands.isEmpty)
    }

    func testProjectDetection() throws {
        // This would test project detection in a real environment
        // For now, just ensure the functions exist
        XCTAssertNotNil(findWorkspace)
        XCTAssertNotNil(findXcodeProject)
    }

    func testBuildStateAnalysis() throws {
        let analysis = BuildStateAnalysis()
        XCTAssertEqual(analysis.derivedDataSize, 0)
        XCTAssertFalse(analysis.hasBuildArtifacts)
        XCTAssertFalse(analysis.hasStaleCache)
        XCTAssertFalse(analysis.hasDependencyConflicts)
        XCTAssertEqual(analysis.memoryPressure, 0.0)
    }

    func testXcodeCommandCreation() throws {
        let command = XcodeCommand(
            description: "Test Command",
            arguments: ["build", "-scheme", "Test"],
            isCritical: true,
            timeout: 300
        )

        XCTAssertEqual(command.description, "Test Command")
        XCTAssertEqual(command.arguments, ["build", "-scheme", "Test"])
        XCTAssertTrue(command.isCritical)
        XCTAssertEqual(command.timeout, 300)
    }

    func testRebuildResult() throws {
        let result = RebuildResult(
            strategyName: "Test Strategy",
            totalCommands: 5,
            successfulCommands: 4,
            failedCommands: ["Failed command"],
            totalDuration: 120.5,
            success: false
        )

        XCTAssertEqual(result.strategyName, "Test Strategy")
        XCTAssertEqual(result.totalCommands, 5)
        XCTAssertEqual(result.successfulCommands, 4)
        XCTAssertEqual(result.failedCommands.count, 1)
        XCTAssertEqual(result.totalDuration, 120.5)
        XCTAssertFalse(result.success)
    }
}