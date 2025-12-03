import Foundation
import SmithBuildAnalysis
import SmithOutputFormatter

/// RealtimeMonitor provides intelligent build progress tracking using shared infrastructure
public class RealtimeMonitor: @unchecked Sendable {

    private var sharedMonitor: SharedMonitor?
    
    public init() {}
    
    // MARK: - Public Interface
    
    public func startMonitoring(
        totalTargets: Int,
        updateInterval: TimeInterval = 1.0,
        showETA: Bool = true,
        monitorResources: Bool = false
    ) {
        // Configure shared monitor with XCSift-specific settings
        let monitorConfig = SharedMonitor.MonitorConfig(
            toolType: .xcodebuild,
            enableETA: showETA,
            enableResources: monitorResources,
            enableHangDetection: false, // XCSift specific: disable hang detection for faster builds
            verbose: false
        )
        
        sharedMonitor = SharedMonitor(config: monitorConfig)

        let output = SmithCLIOutput()
        output.section("REAL-TIME BUILD MONITORING")
        output.info("Total Targets: \(totalTargets)")
        output.info("Update Interval: \(Int(updateInterval))s")
        if showETA {
            output.info("ETA Calculations: Enabled")
        }
        if monitorResources {
            output.info("Resource Monitoring: Enabled")
        }
    }

    public func processBuildOutput(_ output: String) {
        sharedMonitor?.processOutput(output, toolType: .xcodebuild)
    }

    public func stopMonitoring() {
        sharedMonitor?.stopMonitoring()

        // Display final summary
        let output = SmithCLIOutput()
        output.section("BUILD MONITORING COMPLETE")
        output.success("Build monitoring complete")
    }

    public func getCurrentProgress() -> ProgressInfo {
        guard let monitor = sharedMonitor else {
            return ProgressInfo(
                currentTarget: nil,
                completedTargets: 0,
                totalTargets: 0,
                progressPercentage: 0.0,
                currentPhase: "Starting",
                completedFiles: 0,
                totalFiles: 0,
                estimatedTimeRemaining: nil,
                resourceUsage: nil
            )
        }
        
        let progress = monitor.getCurrentProgress()
        return ProgressInfo(
            currentTarget: progress.currentItem,
            completedTargets: progress.completedItems,
            totalTargets: progress.totalItems,
            progressPercentage: progress.progressPercentage * 100.0,
            currentPhase: progress.currentPhase,
            completedFiles: progress.completedFiles,
            totalFiles: progress.totalFiles,
            estimatedTimeRemaining: progress.estimatedTimeRemaining,
            resourceUsage: progress.resourceUsage
        )
    }
}

// MARK: - Compatibility Layer

public struct ProgressInfo {
    public let currentTarget: String?
    public let completedTargets: Int
    public let totalTargets: Int
    public let progressPercentage: Double
    public let currentPhase: String
    public let completedFiles: Int
    public let totalFiles: Int
    public let estimatedTimeRemaining: TimeInterval?
    public let resourceUsage: SmithBuildAnalysis.ResourceInfo?
}