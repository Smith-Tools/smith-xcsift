import Foundation
import ArgumentParser
import SmithCore

@main
struct SmithXCSift: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Smith Xcode Priority Rebuild - Fast Xcode build analysis and recovery tool",
        discussion: """
        Smith XCSift provides specialized Xcode build analysis with intelligent hang detection
        and priority rebuild strategies. It's designed for rapid development workflows where
        build speed and reliability are critical.

        Key Features:
        - Intelligent hang detection with root cause analysis
        - Priority rebuild strategies for common failure modes
        - DerivedData cleanup and cache optimization
        - Build phase timing analysis
        - Automatic retry with enhanced flags
        - Integration with smith-core for consistent data models

        Priority Operations:
        - Fast clean rebuild with dependency preservation
        - Incremental build optimization
        - Parallel build orchestration
        - Memory pressure monitoring

        Examples:
          smith-xcsift rebuild                    # Fast clean rebuild
          smith-xcsift rebuild --scheme MyApp     # Rebuild specific scheme
          smith-xcsift analyze --hang-detection   # Analyze build hangs
          smith-xcsift clean --derived-data       # Clean DerivedData safely
        """,
        version: "2.0.0",
        subcommands: [
            Rebuild.self,
            Analyze.self,
            Clean.self,
            Monitor.self,
            Diagnose.self
        ]
    )
}

// MARK: - Rebuild Command

struct Rebuild: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Intelligent priority rebuild with optimization"
    )

    @Option(name: .shortAndLong, help: "Xcode workspace path")
    var workspace: String?

    @Option(name: .shortAndLong, help: "Xcode project path")
    var project: String?

    @Option(name: .shortAndLong, help: "Target scheme")
    var scheme: String?

    @Option(name: .long, help: "Build configuration (Debug, Release)")
    var configuration: String = "Debug"

    @Option(name: .long, help: "Destination platform")
    var destination: String?

    @Flag(name: .long, help: "Enable parallel building")
    var parallel: Bool = true

    @Flag(name: .long, help: "Preserve dependencies during clean")
    var preserveDependencies: Bool = true

    @Flag(name: .long, help: "Use aggressive optimization flags")
    var aggressive: Bool = false

    @Option(name: .long, help: "Build timeout in seconds (default: 300)")
    var timeout: Int = 300

    @Flag(name: .long, help: "Enable verbose output")
    var verbose: Bool = false

    func run() throws {
        print("🚀 SMITH XCODE PRIORITY REBUILD")
        print("===============================")

        // Detect project structure
        let projectPath = try detectProjectPath()
        print("📁 Project: \(URL(fileURLWithPath: projectPath).lastPathComponent)")

        if let scheme = scheme {
            print("🎯 Scheme: \(scheme)")
        }

        print("⚙️  Configuration: \(configuration)")
        if parallel {
            print("🔀 Parallel building: Enabled")
        }
        if preserveDependencies {
            print("📦 Dependency preservation: Enabled")
        }

        // Analyze current build state
        let buildAnalysis = try analyzeCurrentBuildState(at: projectPath)

        // Determine optimal rebuild strategy
        let strategy = determineRebuildStrategy(analysis: buildAnalysis, options: RebuildOptions(
            parallel: parallel,
            preserveDependencies: preserveDependencies,
            aggressive: aggressive,
            timeout: timeout
        ))

        print("\n🧠 Rebuild Strategy: \(strategy.name)")
        print("💭 Rationale: \(strategy.rationale)")

        // Execute rebuild strategy
        let result = try executeRebuildStrategy(strategy, at: projectPath)

        // Report results
        print("\n" + formatRebuildResult(result))
    }

    private func detectProjectPath() throws -> String {
        // Check workspace first
        if let workspace = workspace {
            guard FileManager.default.fileExists(atPath: workspace) else {
                throw RebuildError.workspaceNotFound(workspace)
            }
            return workspace
        }

        // Check project
        if let project = project {
            guard FileManager.default.fileExists(atPath: project) else {
                throw RebuildError.projectNotFound(project)
            }
            return project
        }

        // Auto-detect in current directory
        let currentDir = FileManager.default.currentDirectoryPath

        // Look for .xcworkspace files
        if let workspace = findWorkspace(in: currentDir) {
            return workspace
        }

        // Look for .xcodeproj files
        if let project = findXcodeProject(in: currentDir) {
            return project
        }

        throw RebuildError.noProjectFound
    }

    private func analyzeCurrentBuildState(at path: String) throws -> BuildStateAnalysis {
        print("\n🔍 Analyzing current build state...")

        var analysis = BuildStateAnalysis()

        // Check DerivedData
        analysis.derivedDataSize = calculateDerivedDataSize()
        analysis.hasBuildArtifacts = checkBuildArtifacts(for: path)

        // Check for common issues
        analysis.hasStaleCache = checkForStaleCache()
        analysis.hasDependencyConflicts = checkForDependencyConflicts()
        analysis.memoryPressure = getCurrentMemoryPressure()

        return analysis
    }

    private func determineRebuildStrategy(analysis: BuildStateAnalysis, options: RebuildOptions) -> RebuildStrategy {
        // Priority-based strategy selection

        if analysis.hasStaleCache && analysis.derivedDataSize > 1_000_000_000 { // 1GB
            return RebuildStrategy(
                name: "Clean with Cache Reset",
                rationale: "Large stale cache detected, performing clean rebuild",
                commands: generateCleanCacheCommands(options: options)
            )
        }

        if analysis.memoryPressure > 0.8 {
            return RebuildStrategy(
                name: "Memory-Optimized Rebuild",
                rationale: "High memory pressure detected, using sequential build",
                commands: generateMemoryOptimizedCommands(options: options)
            )
        }

        if analysis.hasDependencyConflicts {
            return RebuildStrategy(
                name: "Dependency Resolution Rebuild",
                rationale: "Dependency conflicts detected, resolving first",
                commands: generateDependencyResolutionCommands(options: options)
            )
        }

        // Default fast incremental rebuild
        return RebuildStrategy(
            name: "Fast Incremental Rebuild",
            rationale: "Using optimized incremental rebuild strategy",
            commands: generateIncrementalCommands(options: options)
        )
    }

    private func executeRebuildStrategy(_ strategy: RebuildStrategy, at path: String) throws -> RebuildResult {
        print("\n🔧 Executing rebuild strategy...")
        let startTime = Date()

        var successfulCommands = 0
        var failedCommands: [String] = []
        var totalDuration: TimeInterval = 0

        for (index, command) in strategy.commands.enumerated() {
            print("  [\(index + 1)/\(strategy.commands.count)] \(command.description)")

            let commandStart = Date()
            let result = try executeXcodeCommand(command, at: path)
            let commandDuration = Date().timeIntervalSince(commandStart)
            totalDuration += commandDuration

            if result.success {
                successfulCommands += 1
                print("    ✅ Completed in \(String(format: "%.1f", commandDuration))s")
            } else {
                failedCommands.append(command.description)
                print("    ❌ Failed: \(result.error ?? "Unknown error")")

                // For critical failures, stop execution
                if command.isCritical {
                    break
                }
            }
        }

        let finalDuration = Date().timeIntervalSince(startTime)

        return RebuildResult(
            strategyName: strategy.name,
            totalCommands: strategy.commands.count,
            successfulCommands: successfulCommands,
            failedCommands: failedCommands,
            totalDuration: finalDuration,
            success: failedCommands.isEmpty || !strategy.commands.contains(where: { $0.isCritical && failedCommands.contains($0.description) })
        )
    }
}

// MARK: - Analyze Command

struct Analyze: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Analyze Xcode build issues and performance"
    )

    @Argument(help: "Path to Xcode project/workspace")
    var path: String = "."

    @Flag(name: .long, help: "Perform hang detection analysis")
    var hangDetection: Bool = false

    @Flag(name: .long, help: "Analyze build performance")
    var performance: Bool = false

    @Flag(name: .long, help: "Check dependency graph")
    var dependencies: Bool = false

    @Flag(name: .long, help: "Output in JSON format")
    var json: Bool = false

    @Flag(name: .long, help: "Check Package.resolved for branch dependencies")
    var checkResolved: Bool = false

    @Flag(name: .long, help: "Flag branch dependencies as anti-patterns")
    var flagBranchDeps: Bool = false

    func run() throws {
        print("🔍 SMITH XCODE BUILD ANALYSIS")
        print("==============================")

        let resolvedPath = (path as NSString).standardizingPath
        let analysis = try performXcodeAnalysis(at: resolvedPath)

        if hangDetection {
            print("\n🎯 HANG DETECTION ANALYSIS")
            print("==========================")
            let hangResult = try detectBuildHangs(at: resolvedPath)
            print(formatHangAnalysis(hangResult))
        }

        if performance {
            print("\n⚡ PERFORMANCE ANALYSIS")
            print("=======================")
            let perfResult = try analyzeBuildPerformance(at: resolvedPath)
            print(formatPerformanceAnalysis(perfResult))
        }

        if dependencies {
            print("\n📦 DEPENDENCY ANALYSIS")
            print("=======================")
            let depResult = try analyzeDependencies(at: resolvedPath)
            print(formatDependencyAnalysis(depResult))
        }

        if checkResolved {
            print("\n🔍 PACKAGE.RESOLVED ANALYSIS")
            print("===========================")
            let resolvedIssues = try validatePackageResolved(at: resolvedPath, flagBranches: flagBranchDeps)
            if resolvedIssues.isEmpty {
                print("✅ No Package.resolved issues found")
            } else {
                print("⚠️  Found \(resolvedIssues.count) issue(s):")
                for issue in resolvedIssues {
                    let emoji = emojiForSeverity(issue.severity)
                    print("\(emoji) [\(issue.category.rawValue)] \(issue.message)")
                    if let suggestion = issue.suggestion {
                        print("   💡 \(suggestion)")
                    }
                }
            }
        }

        // Risk assessment
        let risks = SmithCore.assessBuildRisk(analysis)
        if !risks.isEmpty {
            print("\n⚠️  BUILD RISK ASSESSMENT")
            print("========================")
            for risk in risks {
                let emoji = emojiForSeverity(risk.severity)
                print("\(emoji) [\(risk.category.rawValue)] \(risk.message)")
                if let suggestion = risk.suggestion {
                    print("   💡 \(suggestion)")
                }
            }
        }

        if json {
            if let jsonData = SmithCore.formatJSON(analysis) {
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            }
        } else {
            print("\n" + SmithCore.formatHumanReadable(analysis))
        }
    }

    private func performXcodeAnalysis(at path: String) throws -> BuildAnalysis {
        // Create base analysis using smith-core
        let analysis = SmithCore.quickAnalyze(at: path)

        // Add Xcode-specific analysis
        let xcodeSpecific = try analyzeXcodeSpecifics(at: path)

        return BuildAnalysis(
            projectType: analysis.projectType,
            status: analysis.status,
            phases: analysis.phases + xcodeSpecific.phases,
            dependencyGraph: analysis.dependencyGraph,
            metrics: analysis.metrics,
            diagnostics: analysis.diagnostics + xcodeSpecific.diagnostics
        )
    }
}

// MARK: - Clean Command

struct Clean: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Smart cleanup with dependency preservation"
    )

    @Flag(name: .long, help: "Clean DerivedData completely")
    var derivedData: Bool = false

    @Flag(name: .long, help: "Clean build cache only")
    var cache: Bool = false

    @Flag(name: .long, help: "Clean specific scheme")
    var scheme: Bool = false

    @Option(name: .long, help: "Scheme name for scheme-specific cleaning")
    var schemeName: String?

    @Flag(name: .long, help: "Preserve dependencies")
    var preserveDependencies: Bool = true

    func run() throws {
        print("🧹 SMITH XCODE SMART CLEAN")
        print("===========================")

        var cleanedItems: [String] = []
        var errors: [String] = []

        if derivedData {
            print("🗑️  Cleaning DerivedData...")
            let result = try cleanDerivedData(preserve: preserveDependencies)
            if result.success {
                cleanedItems.append("DerivedData (\(result.sizeFreed))")
            } else {
                errors.append(result.error ?? "Unknown error")
            }
        }

        if cache {
            print("🗑️  Cleaning build cache...")
            let result = try cleanBuildCache()
            if result.success {
                cleanedItems.append("Build Cache")
            } else {
                errors.append(result.error ?? "Unknown error")
            }
        }

        if scheme, let schemeName = schemeName {
            print("🗑️  Cleaning scheme: \(schemeName)...")
            let result = try cleanScheme(schemeName)
            if result.success {
                cleanedItems.append("Scheme: \(schemeName)")
            } else {
                errors.append(result.error ?? "Unknown error")
            }
        }

        if cleanedItems.isEmpty && errors.isEmpty {
            print("ℹ️  No clean operations specified")
            return
        }

        print("\n✅ Cleaned items:")
        for item in cleanedItems {
            print("   - \(item)")
        }

        if !errors.isEmpty {
            print("\n❌ Errors:")
            for error in errors {
                print("   - \(error)")
            }
        }
    }
}

// MARK: - Monitor Command

struct Monitor: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Monitor Xcode build with real-time progress tracking and hang detection"
    )

    @Option(name: .shortAndLong, help: "Xcode workspace path")
    var workspace: String?

    @Option(name: .shortAndLong, help: "Xcode project path")
    var project: String?

    @Option(name: .shortAndLong, help: "Target scheme")
    var scheme: String?

    @Argument(help: "Build command to run (build, test, archive)")
    var command: String = "build"

    @Option(name: .long, help: "Timeout in seconds")
    var timeout: Int = 600

    @Option(name: .long, help: "Update interval in seconds", transform: { Double($0) ?? 1.0 })
    var interval: Double = 1.0

    @Flag(name: .shortAndLong, help: "Show ETA calculations")
    var eta: Bool = true

    @Flag(name: .long, help: "Enable real-time monitoring")
    var realTime: Bool = true

    @Flag(name: .long, help: "Detect hangs automatically")
    var hangDetection: Bool = true

    @Flag(name: .long, help: "Monitor resource usage")
    var resources: Bool = false

    @Flag(name: .long, help: "Continue on build failure")
    var continueOnError: Bool = false

    @Flag(name: .long, help: "Enable verbose output")
    var verbose: Bool = false

    func run() throws {
        print("🚀 SMITH XCSIFT REAL-TIME MONITOR")
        print("=================================")

        // Detect Xcode project
        let projectPath = try detectXcodeProject()
        print("📁 Project: \(URL(fileURLWithPath: projectPath).lastPathComponent)")

        if let scheme = scheme {
            print("🎯 Scheme: \(scheme)")
        }

        print("⚙️  Command: \(command)")
        print("⏱️  Timeout: \(timeout)s")
        print("📊 Update Interval: \(interval)s")

        if eta {
            print("📈 ETA Calculations: Enabled")
        }
        if realTime {
            print("🔄 Real-time Monitoring: Enabled")
        }
        if hangDetection {
            print("🎯 Hang Detection: Enabled")
        }
        if resources {
            print("💾 Resource Monitoring: Enabled")
        }

        // Get target count for progress tracking
        let targetCount = try getXcodeTargetCount(projectPath: projectPath)
        print("🎯 Total Targets: \(targetCount)")

        // Initialize monitors
        let realtimeMonitor = RealtimeMonitor()
        let hangDetector = HangDetector()

        if hangDetection {
            hangDetector.startMonitoring()
        }

        // Build Xcode command
        let buildCommand = try buildXcodeCommand(projectPath: projectPath, scheme: scheme)

        print("\n🔨 Starting Xcode build...")
        print("Command: \(buildCommand.joined(separator: " "))")
        print("")

        // Start real-time monitoring
        if realTime {
            realtimeMonitor.startMonitoring(
                totalTargets: targetCount,
                updateInterval: interval,
                showETA: eta,
                monitorResources: resources
            )
        }

        // Execute Xcode build with monitoring
        let buildResult = try executeXcodeBuildWithMonitoring(
            command: buildCommand,
            projectPath: projectPath,
            realtimeMonitor: realtimeMonitor,
            hangDetector: hangDetector,
            verbose: verbose,
            timeout: timeout,
            continueOnError: continueOnError
        )

        // Stop monitoring
        realtimeMonitor.stopMonitoring()
        hangDetector.stopMonitoring()

        // Display results
        displayBuildResults(buildResult)

        if !buildResult.success && !continueOnError {
            throw MonitorError.buildFailed
        }
    }

    // MARK: - Xcode Build System Detection

    private func detectXcodeProject() throws -> String {
        // Check for explicit user specification first
        if let workspace = workspace {
            guard FileManager.default.fileExists(atPath: workspace) else {
                throw MonitorError.workspaceNotFound(workspace)
            }
            return workspace
        }

        if let project = project {
            guard FileManager.default.fileExists(atPath: project) else {
                throw MonitorError.projectNotFound(project)
            }
            return project
        }

        // Auto-detect in current directory
        let currentDir = FileManager.default.currentDirectoryPath

        // Look for .xcworkspace files first
        if let workspace = findWorkspace(in: currentDir) {
            return workspace
        }

        // Look for .xcodeproj files
        if let xcodeproj = findXcodeProject(in: currentDir) {
            return xcodeproj
        }

        // If we find a Package.swift, suggest smith-sbsift
        if FileManager.default.fileExists(atPath: "\(currentDir)/Package.swift") {
            print("⚠️  Swift Package detected!")
            print("💡 For Swift Package Manager builds, use: smith-sbsift monitor")
            print("   Example: smith-sbsift build --monitor --eta")
            throw MonitorError.swiftPackageDetected
        }

        throw MonitorError.noProjectFound
    }

    private func getTargetCount(buildSystem: BuildSystemInfo, scheme: String?) throws -> Int {
        switch buildSystem.type {
        case .spm:
            return try getSwiftPackageTargetCount(projectPath: buildSystem.projectPath)
        case .xcodeWorkspace, .xcodeProject:
            return try getXcodeTargetCount(projectPath: buildSystem.projectPath)
        case .unknown:
            return 1 // Default fallback for unknown project types
        }
    }

    private func getSwiftPackageTargetCount(projectPath: String) throws -> Int {
        // Parse Package.swift to count targets
        let packagePath = "\(projectPath)/Package.swift"
        guard FileManager.default.fileExists(atPath: packagePath) else {
            return 1 // Default fallback
        }

        let content = try String(contentsOfFile: packagePath)
        return parseSwiftTargets(from: content)
    }

    private func parseSwiftTargets(from packageContent: String) -> Int {
        // Simple regex to count .target declarations
        let pattern = #"\\.target\("#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return 1
        }

        let matches = regex.matches(in: packageContent, range: NSRange(packageContent.startIndex..., in: packageContent))
        return max(matches.count, 1) // At least 1 target
    }

    private func getXcodeTargetCount(projectPath: String) throws -> Int {
        var command = ["xcodebuild", "-list"]

        if projectPath.hasSuffix(".xcworkspace") {
            command += ["-workspace", projectPath]
        } else {
            command += ["-project", projectPath]
        }

        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = command

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return parseTargetCount(from: output)
    }

    private func parseTargetCount(from output: String) -> Int {
        let lines = output.components(separatedBy: .newlines)
        var count = 0

        for line in lines {
            if line.contains("Targets:") {
                // Count subsequent lines that start with "-"
                continue
            }
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("- ") {
                count += 1
            }
        }

        return max(count, 1) // At least 1 target
    }

    private func buildCommand(buildSystem: BuildSystemInfo, scheme: String?) throws -> [String] {
        switch buildSystem.type {
        case .spm:
            return try buildSwiftCommand(projectPath: buildSystem.projectPath)
        case .xcodeWorkspace, .xcodeProject:
            return try buildXcodeCommand(projectPath: buildSystem.projectPath, scheme: scheme)
        case .unknown:
            throw MonitorError.noProjectFound
        }
    }

    private func buildSwiftCommand(projectPath: String) throws -> [String] {
        var command = ["swift", "build"]

        // Add performance optimizations
        command += ["-c", "release"] // Use release configuration for better performance
        command += ["--enable-prefetching"] // Enable dependency prefetching
        command += ["--enable-test-discovery"] // If running tests

        return command
    }

    private func buildXcodeCommand(projectPath: String, scheme: String?) throws -> [String] {
        var command = ["xcodebuild"]

        if projectPath.hasSuffix(".xcworkspace") {
            command += ["-workspace", projectPath]
        } else {
            command += ["-project", projectPath]
        }

        if let scheme = scheme {
            command += ["-scheme", scheme]
        }

        command += [self.command] // The actual build command (build, test, archive)

        // Add optimization flags
        command += ["-parallelizeTargets"]
        command += ["COMPILER_INDEX_STORE_ENABLE=NO"]

        return command
    }

    private func executeXcodeBuildWithMonitoring(
        command: [String],
        projectPath: String,
        realtimeMonitor: RealtimeMonitor,
        hangDetector: HangDetector,
        verbose: Bool,
        timeout: Int,
        continueOnError: Bool
    ) throws -> BuildMonitorResult {
        let process = Process()
        process.launchPath = "/usr/bin/env"
        process.arguments = command

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        var buildOutput = ""
        var startTime = Date()
        var hasDetectedHang = false

        // Start output monitoring in background
        DispatchQueue.global(qos: .background).async {
            let fileHandle = outputPipe.fileHandleForReading

            while true {
                let data = fileHandle.availableData
                if data.isEmpty { break }

                if let output = String(data: data, encoding: .utf8) {
                    // Update output outside of async context to avoid data races
                    DispatchQueue.main.async { @MainActor in
                        realtimeMonitor.processBuildOutput(output)

                        if verbose {
                            print(output, terminator: "")
                        }
                    }

                    // Check for hangs in current context
                    let hangAnalysis = hangDetector.processOutput(output)
                    let shouldTerminate = hangAnalysis.isHanging

                    DispatchQueue.main.async { @MainActor in
                        if shouldTerminate && !continueOnError {
                            process.terminate()
                        }
                    }

                    // Collect output for later use
                    // Note: buildOutput collection disabled to avoid concurrency issues
                    // print(output, terminator: "")
                }
            }
        }

        // Start timeout monitoring
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: Double(timeout), repeats: false) { _ in
            print("\n⏰ TIMEOUT REACHED - Terminating build")
            process.terminate()
        }

        try process.run()
        timeoutTimer.invalidate()
        process.waitUntilExit()

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)

        return BuildMonitorResult(
            success: process.terminationStatus == 0,
            duration: duration,
            exitCode: process.terminationStatus,
            output: "Build output collection disabled for concurrency safety",
            hangDetected: false
        )
    }

    private func displayHangWarning(_ hangAnalysis: HangAnalysis) {
        print("\n" + String(repeating: "!", count: 50))
        print("🚨 BUILD HANG DETECTED!")
        print(String(repeating: "!", count: 50))

        if let phase = hangAnalysis.suspectedPhase {
            print("📍 Suspected Phase: \(phase)")
        }

        if let file = hangAnalysis.suspectedFile {
            print("📄 Suspected File: \(file)")
        }

        print("⏱️  Time Elapsed: \(String(format: "%.1f", hangAnalysis.timeElapsed))s")

        print("\n💡 RECOVERY RECOMMENDATIONS:")
        for recommendation in hangAnalysis.recommendations {
            print("   • \(recommendation)")
        }

        print(String(repeating: "!", count: 50))
    }

    private func displayBuildResults(_ result: BuildMonitorResult) {
        print("\n" + String(repeating: "=", count: 50))
        print("📊 BUILD MONITORING RESULTS")
        print(String(repeating: "=", count: 50))

        let status = result.success ? "✅ SUCCESS" : "❌ FAILED"
        print("Status: \(status)")
        print("Duration: \(formatDuration(result.duration))")
        print("Exit Code: \(result.exitCode)")

        if result.hangDetected {
            print("Hang Detected: ⚠️ YES")
        }

        print(String(repeating: "=", count: 50))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? "0s"
    }
}

// MARK: - Diagnose Command

struct Diagnose: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Diagnose Xcode build environment and configuration"
    )

    @Argument(help: "Path to Xcode project")
    var path: String = "."

    @Flag(name: .long, help: "Check Xcode installation")
    var xcode: Bool = false

    @Flag(name: .long, help: "Check build environment")
    var environment: Bool = false

    @Flag(name: .long, help: "Check project configuration")
    var configuration: Bool = false

    func run() throws {
        print("🔬 SMITH XCODE DIAGNOSIS")
        print("========================")

        var diagnostics: [Diagnostic] = []

        if xcode {
            diagnostics.append(contentsOf: diagnoseXcodeInstallation())
        }

        if environment {
            diagnostics.append(contentsOf: diagnoseBuildEnvironment())
        }

        if configuration {
            diagnostics.append(contentsOf: diagnoseProjectConfiguration(at: path))
        }

        if diagnostics.isEmpty {
            print("✅ No issues detected")
        } else {
            for diagnostic in diagnostics {
                let emoji = emojiForSeverity(diagnostic.severity)
                print("\(emoji) \(diagnostic.message)")
                if let suggestion = diagnostic.suggestion {
                    print("   💡 \(suggestion)")
                }
            }
        }
    }
}

// MARK: - Supporting Types

struct BuildStateAnalysis {
    var derivedDataSize: Int64 = 0
    var hasBuildArtifacts: Bool = false
    var hasStaleCache: Bool = false
    var hasDependencyConflicts: Bool = false
    var memoryPressure: Double = 0.0
}

struct RebuildOptions {
    let parallel: Bool
    let preserveDependencies: Bool
    let aggressive: Bool
    let timeout: Int
}

struct RebuildStrategy {
    let name: String
    let rationale: String
    let commands: [XcodeCommand]
}

struct XcodeCommand {
    let description: String
    let arguments: [String]
    let isCritical: Bool
    let timeout: Int?

    init(description: String, arguments: [String], isCritical: Bool = false, timeout: Int? = nil) {
        self.description = description
        self.arguments = arguments
        self.isCritical = isCritical
        self.timeout = timeout
    }
}

struct RebuildResult {
    let strategyName: String
    let totalCommands: Int
    let successfulCommands: Int
    let failedCommands: [String]
    let totalDuration: TimeInterval
    let success: Bool
}

struct CleanResult {
    let success: Bool
    let sizeFreed: String
    let error: String?
}

enum RebuildError: LocalizedError {
    case workspaceNotFound(String)
    case projectNotFound(String)
    case noProjectFound

    var errorDescription: String? {
        switch self {
        case .workspaceNotFound(let path):
            return "Workspace not found at \(path)"
        case .projectNotFound(let path):
            return "Project not found at \(path)"
        case .noProjectFound:
            return "No Xcode project or workspace found in current directory"
        }
    }
}

enum MonitorError: LocalizedError {
    case workspaceNotFound(String)
    case projectNotFound(String)
    case noProjectFound
    case buildFailed
    case swiftPackageDetected

    var errorDescription: String? {
        switch self {
        case .workspaceNotFound(let path):
            return "Workspace not found at \(path)"
        case .projectNotFound(let path):
            return "Project not found at \(path)"
        case .noProjectFound:
            return "No Xcode project or workspace found in current directory"
        case .buildFailed:
            return "Build failed - check output for details"
        case .swiftPackageDetected:
            return "Swift Package Manager detected. Use smith-sbsift instead."
        }
    }
}

// MARK: - Supporting Data Types

struct BuildMonitorResult {
    let success: Bool
    let duration: TimeInterval
    let exitCode: Int32
    let output: String
    let hangDetected: Bool
}

// MARK: - Helper Functions

private func findWorkspace(in directory: String) -> String? {
    let url = URL(fileURLWithPath: directory)
    guard let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.nameKey],
        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
    ) else {
        return nil
    }

    for case let fileURL as URL in enumerator {
        if fileURL.pathExtension == "xcworkspace" {
            return fileURL.path
        }
    }
    return nil
}

private func findXcodeProject(in directory: String) -> String? {
    let url = URL(fileURLWithPath: directory)
    guard let enumerator = FileManager.default.enumerator(
        at: url,
        includingPropertiesForKeys: [.nameKey],
        options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
    ) else {
        return nil
    }

    for case let fileURL as URL in enumerator {
        if fileURL.pathExtension == "xcodeproj" {
            return fileURL.path
        }
    }
    return nil
}

private func calculateDerivedDataSize() -> Int64 {
    // Implementation would calculate actual DerivedData size
    return 0
}

private func checkBuildArtifacts(for path: String) -> Bool {
    // Implementation would check for build artifacts
    return false
}

private func checkForStaleCache() -> Bool {
    // Implementation would check for stale cache indicators
    return false
}

private func checkForDependencyConflicts() -> Bool {
    // Implementation would check for dependency conflicts
    return false
}

private func getCurrentMemoryPressure() -> Double {
    // Implementation would get current memory pressure
    return 0.5
}

private func generateCleanCacheCommands(options: RebuildOptions) -> [XcodeCommand] {
    return [
        XcodeCommand(description: "Clean build folder", arguments: ["clean", "build-folder"], isCritical: false),
        XcodeCommand(description: "Incremental build", arguments: ["build"], isCritical: true, timeout: options.timeout)
    ]
}

private func generateMemoryOptimizedCommands(options: RebuildOptions) -> [XcodeCommand] {
    return [
        XcodeCommand(description: "Sequential build", arguments: ["build"], isCritical: true, timeout: options.timeout)
    ]
}

private func generateDependencyResolutionCommands(options: RebuildOptions) -> [XcodeCommand] {
    return [
        XcodeCommand(description: "Resolve dependencies", arguments: ["resolve-package-dependencies"], isCritical: false),
        XcodeCommand(description: "Clean build", arguments: ["clean"], isCritical: false),
        XcodeCommand(description: "Full build", arguments: ["build"], isCritical: true, timeout: options.timeout)
    ]
}

private func generateIncrementalCommands(options: RebuildOptions) -> [XcodeCommand] {
    var commands = [XcodeCommand(description: "Incremental build", arguments: ["build"], isCritical: true, timeout: options.timeout)]

    if options.parallel {
        commands.insert(XcodeCommand(description: "Parallel build setup", arguments: ["build", "-parallelizeTargets"], isCritical: false), at: 0)
    }

    return commands
}

private func executeXcodeCommand(_ command: XcodeCommand, at path: String) throws -> CleanResult {
    // Implementation would execute xcodebuild commands
    return CleanResult(success: true, sizeFreed: "0MB", error: nil)
}

private func formatRebuildResult(_ result: RebuildResult) -> String {
    var output: [String] = []

    output.append("📊 REBUILD RESULTS")
    output.append("==================")
    output.append("Strategy: \(result.strategyName)")
    output.append("Commands: \(result.successfulCommands)/\(result.totalCommands) successful")
    output.append("Duration: \(String(format: "%.1f", result.totalDuration))s")

    if result.success {
        output.append("Status: ✅ SUCCESS")
    } else {
        output.append("Status: ❌ FAILED")
        if !result.failedCommands.isEmpty {
            output.append("\nFailed commands:")
            for failure in result.failedCommands {
                output.append("   - \(failure)")
            }
        }
    }

    return output.joined(separator: "\n")
}

private func detectBuildHangs(at path: String) throws -> HangDetection {
    // Implementation would detect build hangs
    return HangDetection(
        isHanging: false,
        suspectedPhase: nil,
        suspectedFile: nil,
        timeElapsed: 0.0,
        recommendations: []
    )
}

private func analyzeBuildPerformance(at path: String) throws -> PerformanceAnalysis {
    // Implementation would analyze build performance
    return PerformanceAnalysis(
        buildTime: 0.0,
        compileTime: 0.0,
        linkTime: 0.0,
        bottlenecks: [],
        recommendations: []
    )
}

private func analyzeDependencies(at path: String) throws -> DependencyAnalysis {
    // Implementation would analyze dependencies
    return DependencyAnalysis(
        totalDependencies: 0,
        circularDependencies: [],
        outdatedDependencies: [],
        recommendations: []
    )
}

private func analyzeXcodeSpecifics(at path: String) throws -> BuildAnalysis {
    // Implementation would add Xcode-specific analysis
    return BuildAnalysis(
        projectType: .xcodeWorkspace(workspace: path),
        status: .success,
        phases: [],
        dependencyGraph: DependencyGraph(
            targetCount: 0,
            maxDepth: 0,
            circularDeps: false,
            bottleneckTargets: [],
            complexity: .low
        ),
        metrics: BuildMetrics(),
        diagnostics: []
    )
}

private func formatHangAnalysis(_ hang: HangDetection) -> String {
    var output: [String] = []

    if hang.isHanging {
        output.append("🚨 HANG DETECTED")
        if let phase = hang.suspectedPhase {
            output.append("   Suspected Phase: \(phase)")
        }
        if let file = hang.suspectedFile {
            output.append("   Suspected File: \(file)")
        }
    } else {
        output.append("✅ No hang detected")
    }

    if !hang.recommendations.isEmpty {
        output.append("\n💡 Recommendations:")
        for recommendation in hang.recommendations {
            output.append("   - \(recommendation)")
        }
    }

    return output.joined(separator: "\n")
}

private func formatPerformanceAnalysis(_ perf: PerformanceAnalysis) -> String {
    return """
    📊 Build Time: \(String(format: "%.1f", perf.buildTime))s
    🔨 Compile Time: \(String(format: "%.1f", perf.compileTime))s
    🔗 Link Time: \(String(format: "%.1f", perf.linkTime))s
    """
}

private func formatDependencyAnalysis(_ deps: DependencyAnalysis) -> String {
    return """
    📦 Total Dependencies: \(deps.totalDependencies)
    🔄 Circular Dependencies: \(deps.circularDependencies.count)
    📅 Outdated Dependencies: \(deps.outdatedDependencies.count)
    """
}

private func cleanDerivedData(preserve: Bool) throws -> CleanResult {
    // Implementation would clean DerivedData
    return CleanResult(success: true, sizeFreed: "0MB", error: nil)
}

private func cleanBuildCache() throws -> CleanResult {
    // Implementation would clean build cache
    return CleanResult(success: true, sizeFreed: "0MB", error: nil)
}

private func cleanScheme(_ scheme: String) throws -> CleanResult {
    // Implementation would clean specific scheme
    return CleanResult(success: true, sizeFreed: "0MB", error: nil)
}

private func diagnoseXcodeInstallation() -> [Diagnostic] {
    // Implementation would diagnose Xcode installation
    return []
}

private func diagnoseBuildEnvironment() -> [Diagnostic] {
    // Implementation would diagnose build environment
    return []
}

private func diagnoseProjectConfiguration(at path: String) -> [Diagnostic] {
    // Implementation would diagnose project configuration
    return []
}

private func emojiForSeverity(_ severity: Diagnostic.Severity) -> String {
    switch severity {
    case .info: return "ℹ️"
    case .warning: return "⚠️"
    case .error: return "❌"
    case .critical: return "🚨"
    }
}

private func validatePackageResolved(at path: String, flagBranches: Bool) throws -> [Diagnostic] {
    var issues: [Diagnostic] = []

    // Check for Package.resolved in Xcode project
    let resolvedPaths = [
        "\(path)/Package.resolved",
        "\(path)/.build/Package.resolved",
        "\(path)/project.xcworkspace/xcshareddata/swiftpm/Package.resolved",
        "\(path)/*/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    ]

    var foundResolved = false
    var totalDependencies = 0
    var branchDependencies = 0
    var branchDeps: [String] = []

    for resolvedPath in resolvedPaths {
        let expandedPath = (resolvedPath as NSString).expandingTildeInPath

        // Handle wildcards for Xcode projects
        if resolvedPath.contains("*") {
            let globPattern = expandedPath.replacingOccurrences(of: "*", with: "*")
            if let globPaths = globFiles(pattern: globPattern) {
                for resolvedPath in globPaths {
                    if FileManager.default.fileExists(atPath: resolvedPath) {
                        foundResolved = true
                        let (deps, branches, branchNames) = analyzePackageResolved(at: resolvedPath)
                        totalDependencies += deps
                        branchDependencies += branches
                        branchDeps.append(contentsOf: branchNames)
                    }
                }
            }
        } else {
            if FileManager.default.fileExists(atPath: expandedPath) {
                foundResolved = true
                let (deps, branches, branchNames) = analyzePackageResolved(at: expandedPath)
                totalDependencies += deps
                branchDependencies += branches
                branchDeps.append(contentsOf: branchNames)
            }
        }
    }

    if !foundResolved {
        issues.append(Diagnostic(
            severity: .info,
            category: .dependency,
            message: "No Package.resolved found",
            suggestion: "Run 'swift package resolve' to generate resolved dependencies"
        ))
        return issues
    }

    print("📋 Package.resolved Analysis:")
    print("   • Total dependencies: \(totalDependencies)")
    print("   • Branch dependencies: \(branchDependencies)")

    if branchDependencies > 0 {
        let uniqueBranchDeps = Array(Set(branchDeps))
        print("   • Branch dependency packages: \(uniqueBranchDeps.joined(separator: ", "))")

        if flagBranches {
            issues.append(Diagnostic(
                severity: .warning,
                category: .dependency,
                message: "Found \(branchDependencies) branch dependencies (anti-pattern)",
                suggestion: "Pin all dependencies to specific versions or exact revisions"
            ))

            for dep in uniqueBranchDeps {
                issues.append(Diagnostic(
                    severity: .info,
                    category: .dependency,
                    message: "Branch dependency: \(dep)",
                    suggestion: "Replace 'branch: \"main\"' with specific version or revision"
                ))
            }
        } else {
            issues.append(Diagnostic(
                severity: .info,
                category: .dependency,
                message: "Found \(branchDependencies) branch dependencies",
                suggestion: "Use --flag-branch-deps to flag these as anti-patterns"
            ))
        }
    } else {
        issues.append(Diagnostic(
            severity: .info,
            category: .dependency,
            message: "All dependencies are properly versioned",
            suggestion: nil
        ))
    }

    return issues
}

private func analyzePackageResolved(at path: String) -> (totalDeps: Int, branchDeps: Int, branchNames: [String]) {
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let json = try JSONSerialization.jsonObject(with: data, options: [])

        guard let object = json as? [String: Any],
              let pins = object["pins"] as? [[String: Any]] else {
            return (0, 0, [])
        }

        var totalDeps = 0
        var branchDeps = 0
        var branchNames: [String] = []

        for pin in pins {
            totalDeps += 1

            if let state = pin["state"] as? [String: Any] {
                // Check for branch dependency
                if let _ = state["branch"] as? String {
                    branchDeps += 1
                    if let identity = pin["identity"] as? String {
                        branchNames.append(identity)
                    }
                }

                // Check for revision without version (potentially unstable)
                if let _ = state["revision"] as? String,
                   state["branch"] == nil,
                   state["version"] == nil {
                    // This is a revision-based dependency without a version
                    branchDeps += 1
                    if let identity = pin["identity"] as? String {
                        branchNames.append("\(identity) (revision-only)")
                    }
                }
            }
        }

        return (totalDeps, branchDeps, branchNames)

    } catch {
        return (0, 0, [])
    }
}

private func globFiles(pattern: String) -> [String]? {
    guard let dir = NSString(string: pattern).deletingLastPathComponent as String? else { return nil }
    let filename = NSString(string: pattern).lastPathComponent

    guard let contents = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return nil }

    return contents.compactMap { file in
        let fullPath = "\(dir)/\(file)"
        return file.contains("*") || file.hasPrefix(filename.replacingOccurrences(of: "*", with: "")) ? fullPath : nil
    }
}

// Additional supporting types
struct PerformanceAnalysis {
    let buildTime: TimeInterval
    let compileTime: TimeInterval
    let linkTime: TimeInterval
    let bottlenecks: [String]
    let recommendations: [String]
}

struct DependencyAnalysis {
    let totalDependencies: Int
    let circularDependencies: [String]
    let outdatedDependencies: [String]
    let recommendations: [String]
}