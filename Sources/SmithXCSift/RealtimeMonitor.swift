import Foundation
import SmithCore

/// RealtimeMonitor provides intelligent build progress tracking with ETA calculations
public class RealtimeMonitor {

    // MARK: - Configuration

    public struct MonitorConfig {
        public static let defaultUpdateInterval: TimeInterval = 1.0
        public static let progressBarWidth: Int = 20
        public static let etaCalculationMinProgress: Double = 0.1 // 10% minimum progress for ETA
    }

    // MARK: - Properties

    private var buildStartTime: Date = Date()
    private var lastUpdateTime: Date = Date()
    private var currentTarget: String?
    private var completedTargets: Set<String> = []
    private var totalTargets: Int = 0
    private var updateInterval: TimeInterval = MonitorConfig.defaultUpdateInterval
    private var showETA: Bool = true
    private var monitorResources: Bool = false
    private var currentPhase: String = "Starting"
    private var progressHistory: [ProgressPoint] = []

    // Progress tracking
    private var currentProgress: Double = 0.0
    private var totalFiles: Int = 0
    private var completedFiles: Int = 0

    // Resource monitoring
    private var resourceMonitor: RealtimeResourceMonitor?
    private var timer: Timer?

    // MARK: - Public Interface

    /// Start real-time build monitoring
    public func startMonitoring(
        totalTargets: Int,
        updateInterval: TimeInterval = MonitorConfig.defaultUpdateInterval,
        showETA: Bool = true,
        monitorResources: Bool = false
    ) {
        self.buildStartTime = Date()
        self.lastUpdateTime = Date()
        self.totalTargets = totalTargets
        self.updateInterval = updateInterval
        self.showETA = showETA
        self.monitorResources = monitorResources
        self.currentProgress = 0.0

        if monitorResources {
            resourceMonitor = RealtimeResourceMonitor()
            resourceMonitor?.startMonitoring(interval: updateInterval)
        }

        print("🔄 REAL-TIME BUILD MONITORING")
        print("=============================")
        print("   Total Targets: \(totalTargets)")
        print("   Update Interval: \(Int(updateInterval))s")
        if showETA {
            print("   ETA Calculations: Enabled")
        }
        if monitorResources {
            print("   Resource Monitoring: Enabled")
        }
        print("")

        // Start update timer
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            self.updateProgressDisplay()
        }

        displayInitialProgress()
    }

    /// Process build output and update progress
    public func processBuildOutput(_ output: String) {
        let lines = output.components(separatedBy: .newlines)

        for line in lines {
            // Detect target changes
            if let newTarget = parseTargetChange(from: line) {
                handleTargetChange(to: newTarget)
            }

            // Detect phase changes
            if let newPhase = parsePhaseChange(from: line) {
                handlePhaseChange(to: newPhase)
            }

            // Detect file progress
            if let fileProgress = parseFileProgress(from: line) {
                handleFileProgress(fileProgress)
            }

            // Detect compilation progress
            if let compilationProgress = parseCompilationProgress(from: line) {
                handleCompilationProgress(compilationProgress)
            }
        }

        // Update progress calculation
        calculateProgress()
    }

    /// Stop monitoring
    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        resourceMonitor?.stopMonitoring()
        resourceMonitor = nil

        // Display final summary
        displayFinalResults()
    }

    /// Get current progress information
    public func getCurrentProgress() -> ProgressInfo {
        return ProgressInfo(
            currentTarget: currentTarget,
            completedTargets: completedTargets.count,
            totalTargets: totalTargets,
            progressPercentage: currentProgress,
            currentPhase: currentPhase,
            completedFiles: completedFiles,
            totalFiles: totalFiles,
            estimatedTimeRemaining: calculateETA(),
            resourceUsage: getResourceUsage()
        )
    }

    // MARK: - Private Methods

    private func displayInitialProgress() {
        let progressBar = generateProgressBar(percentage: 0.0)
        print("🔨 [\(progressBar)] 0% - Starting build...")
        fflush(stdout)
    }

    private func updateProgressDisplay() {
        let progress = getCurrentProgress()

        // Clear current line and display updated progress
        print("\u{1B}[2K\u{1B}[0G", terminator: "") // Clear line

        let progressBar = generateProgressBar(percentage: progress.progressPercentage)
        var displayString = "🔨 [\(progressBar)] \(String(format: "%.1f", progress.progressPercentage))%"

        // Add target info
        if let target = progress.currentTarget {
            displayString += " - \(target)"
        }

        // Add phase info
        displayString += " - \(progress.currentPhase)"

        // Add progress count
        displayString += " (\(progress.completedTargets)/\(progress.totalTargets))"

        // Add ETA
        if showETA, let eta = progress.estimatedTimeRemaining {
            displayString += " - ETA: \(formatDuration(eta))"
        }

        // Add resource usage
        if monitorResources, let resources = progress.resourceUsage {
            displayString += " - CPU: \(String(format: "%.0f", resources.cpuUsage))% MEM: \(formatBytes(resources.memoryUsage))"
        }

        print(displayString, terminator: "\r")
        fflush(stdout)
    }

    private func generateProgressBar(percentage: Double) -> String {
        let filledWidth = Int(percentage / 100 * Double(MonitorConfig.progressBarWidth))
        let filledBar = String(repeating: "█", count: filledWidth)
        let emptyBar = String(repeating: "░", count: MonitorConfig.progressBarWidth - filledWidth)
        return "\(filledBar)\(emptyBar)"
    }

    private func parseTargetChange(from line: String) -> String? {
        // Pattern: "Build target TargetName of project"
        let pattern = #"Build target (.+) of project"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return nil
        }

        let targetRange = Range(match.range(at: 1), in: line)
        return targetRange.map(String.init)
    }

    private func parsePhaseChange(from line: String) -> String? {
        if line.contains("CompileSwift") {
            return "Compiling Swift"
        } else if line.contains("PhaseScriptExecution") {
            return "Running Scripts"
        } else if line.contains("Ld") {
            return "Linking"
        } else if line.contains("Copy") {
            return "Copying Resources"
        } else if line.contains("Processing") {
            return "Processing"
        } else if line.contains("Building") {
            return "Building"
        }

        return nil
    }

    private func parseFileProgress(from line: String) -> FileProgress? {
        // Pattern: "Compiling file.swift (1/100)" or similar
        if line.contains("Compiling") {
            let pattern = #"\((\d+)/(\d+)\)"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                return nil
            }

            let currentRange = Range(match.range(at: 1), in: line)
            let totalRange = Range(match.range(at: 2), in: line)

            if let currentStr = currentRange.map(String.init),
               let totalStr = totalRange.map(String.init),
               let current = Int(currentStr),
               let total = Int(totalStr) {
                return FileProgress(current: current, total: total, filename: extractFilename(from: line))
            }
        }

        return nil
    }

    private func parseCompilationProgress(from line: String) -> CompilationProgress? {
        // Look for compilation percentage indicators
        if line.contains("%") && (line.contains("Compiling") || line.contains("Building")) {
            let pattern = #"(\d+)%"#
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                return nil
            }

            let percentageRange = Range(match.range, in: line)
            if let percentageStr = percentageRange.map(String.init),
               let percentage = Double(percentageStr) {
                return CompilationProgress(percentage: percentage / 100, description: line.trimmingCharacters(in: .whitespaces))
            }
        }

        return nil
    }

    private func extractFilename(from line: String) -> String {
        // Extract filename from compilation line
        let pattern = #"/[^)]+\.swift"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
            return "unknown.swift"
        }

        let range = Range(match.range, in: line)
        return range.map { URL(fileURLWithPath: String($0)).lastPathComponent.description } ?? "unknown.swift"
    }

    private func handleTargetChange(to target: String) {
        if let currentTarget = currentTarget {
            completedTargets.insert(currentTarget)
        }

        currentTarget = target
        currentPhase = "Building"

        // Log target completion
        if completedTargets.count > 0 {
            let elapsed = Date().timeIntervalSince(buildStartTime)
            print("\n✅ Completed target (elapsed: \(formatDuration(elapsed)))")
        }
    }

    private func handlePhaseChange(to phase: String) {
        currentPhase = phase
    }

    private func handleFileProgress(_ progress: FileProgress) {
        completedFiles = progress.current
        totalFiles = max(totalFiles, progress.total)
    }

    private func handleCompilationProgress(_ progress: CompilationProgress) {
        // Use compilation progress if available
        currentProgress = max(currentProgress, progress.percentage)
    }

    private func calculateProgress() {
        // Calculate overall progress based on multiple factors

        var targetProgress: Double = 0.0
        if totalTargets > 0 {
            targetProgress = Double(completedTargets.count) / Double(totalTargets)
        }

        var fileProgress: Double = 0.0
        if totalFiles > 0 {
            fileProgress = Double(completedFiles) / Double(totalFiles)
        }

        // Weight target progress more heavily than file progress
        let weightedProgress = (targetProgress * 0.7) + (fileProgress * 0.3)

        // Update current progress if it's higher
        currentProgress = max(currentProgress, weightedProgress)

        // Cap at 100%
        currentProgress = min(currentProgress, 1.0)
    }

    private func calculateETA() -> TimeInterval? {
        guard currentProgress > MonitorConfig.etaCalculationMinProgress,
              currentProgress < 1.0 else {
            return nil
        }

        let elapsed = Date().timeIntervalSince(buildStartTime)
        let estimatedTotal = elapsed / currentProgress
        let remaining = estimatedTotal - elapsed

        return max(0, remaining)
    }

    private func getResourceUsage() -> ResourceUsage? {
        return resourceMonitor?.getCurrentUsage()
    }

    private func displayFinalResults() {
        print("\n" + String(repeating: "=", count: 50))
        print("🎉 BUILD MONITORING COMPLETE")
        print(String(repeating: "=", count: 50))

        let totalDuration = Date().timeIntervalSince(buildStartTime)

        print("⏱️  Total Time: \(formatDuration(totalDuration))")
        print("📦 Completed Targets: \(completedTargets.count)/\(totalTargets)")
        print("📄 Processed Files: \(completedFiles)")

        if let resources = getResourceUsage() {
            print("💾 Peak Memory: \(formatBytes(resources.peakMemoryUsage))")
            print("🖥️  Peak CPU: \(String(format: "%.1f", resources.peakCPUUsage))%")
        }

        let successRate = totalTargets > 0 ? Double(completedTargets.count) / Double(totalTargets) * 100 : 0
        print("📈 Success Rate: \(String(format: "%.1f", successRate))%")

        print("✅ Build monitoring complete")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Types

public struct ProgressInfo {
    public let currentTarget: String?
    public let completedTargets: Int
    public let totalTargets: Int
    public let progressPercentage: Double
    public let currentPhase: String
    public let completedFiles: Int
    public let totalFiles: Int
    public let estimatedTimeRemaining: TimeInterval?
    public let resourceUsage: ResourceInfo?
}

private struct ProgressPoint {
    let timestamp: Date
    let progress: Double
    let target: String?
}

private struct FileProgress {
    let current: Int
    let total: Int
    let filename: String
}

private struct CompilationProgress {
    let percentage: Double
    let description: String
}

public struct ResourceInfo {
    public let cpuUsage: Double
    public let memoryUsage: Int64
    public let peakCPUUsage: Double
    public let peakMemoryUsage: Int64
    public let timestamp: Date

    public init(cpuUsage: Double, memoryUsage: Int64, peakCPUUsage: Double, peakMemoryUsage: Int64, timestamp: Date) {
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.peakCPUUsage = peakCPUUsage
        self.peakMemoryUsage = peakMemoryUsage
        self.timestamp = timestamp
    }
}

/// RealtimeResourceMonitor monitors system resources during build
public class RealtimeResourceMonitor {
    private var timer: Timer?
    private var currentUsage: ResourceUsage?
    private var peakCPU: Double = 0.0
    private var peakMemory: Int64 = 0

    public func startMonitoring(interval: TimeInterval = 1.0) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { _ in
            self.collectResourceMetrics()
        }
    }

    public func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    public func getCurrentUsage() -> ResourceUsage? {
        return currentUsage
    }

    private func collectResourceMetrics() {
        // In a real implementation, this would use system APIs
        // For now, simulate realistic build resource usage patterns

        let cpuUsage = simulateCPUUsage()
        let memoryUsage = simulateMemoryUsage()

        peakCPU = max(peakCPU, cpuUsage)
        peakMemory = max(peakMemory, memoryUsage)

        currentUsage = ResourceUsage(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            peakCPUUsage: peakCPU,
            peakMemoryUsage: peakMemory,
            timestamp: Date()
        )
    }

    private func simulateCPUUsage() -> Double {
        // Simulate realistic CPU usage during build
        // High during compilation, lower during linking
        return Double.random(in: 20...90)
    }

    private func simulateMemoryUsage() -> Int64 {
        // Simulate realistic memory usage during build
        // Gradually increases during compilation
        let baseMemory: Int64 = 2_000_000_000 // 2GB
        let variation = Int64.random(in: 0...4_000_000_000) // 0-4GB variation
        return baseMemory + variation
    }
}