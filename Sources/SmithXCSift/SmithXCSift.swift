import Foundation
import ArgumentParser
import SmithBuildAnalysis
import SmithOutputFormatter
import SmithErrorHandling
import SmithProgress

@main
struct SmithXCSift: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Smith Xcode Build Output Parser - Token-efficient build analysis",
        discussion: """
        Smith XCSift converts verbose xcodebuild output into structured, token-efficient
        formats designed for Claude agents and modern development workflows.

        Key Features:
        - Context-efficient output for AI agents (60% token reduction)
        - Error and warning extraction with file/line information
        - Build status detection and timing analysis
        - Multiple output formats (JSON, compact, detailed)
        - Auto-parse when input is piped (AI-ergonomic design)

        Examples:
          xcodebuild build -scheme MyApp 2>&1 | smith-xcsift
          smith-xcsift analyze
          smith-xcsift validate
          smith-xcsift parse --format json (explicit parse)
        """,
        version: "3.0.0",
        subcommands: [
            Analyze.self,
            Parse.self,
            Validate.self
        ]
    )

    func run() throws {
        // Check if input is being piped - if so, auto-run parse with defaults
        if isatty(STDIN_FILENO) != 0 {
            // No piped input - show help using SmithOutputFormatter
            let output = SmithCLIOutput()
            output.warning("No input detected. Use subcommands or pipe xcodebuild output.")
            output.info("Usage:")
            output.info("xcodebuild build -scheme MyApp 2>&1 | smith-xcsift")
            output.info("smith-xcsift analyze")
            output.info("smith-xcsift validate")
            throw ExitCode.failure
        } else {
            // Input is piped - auto-run parse with default settings for AI ergonomics
            let input = FileHandle.standardInput.readDataToEndOfFile()
            let output = String(data: input, encoding: .utf8) ?? ""

            guard !output.isEmpty else {
                let error = ResourceError(
                    code: "SMITH_RES_001",
                    message: "No input received",
                    technicalDetails: "Stdin was empty or contained no data",
                    suggestedActions: ["Verify xcodebuild is producing output", "Check build command syntax"],
                    isFatal: true
                )
                print(error.jsonString)
                throw ExitCode.failure
            }

            // ADD: Progress tracking
            let progress = SmithProgress()
            progress.start(title: "Processing Build Output")

            let result = try parseXcodeBuildOutput(output)

            // ADD: Finish progress
            progress.finish(
                success: result.status != .failed,
                finalMessage: "Processed \(result.diagnostics.count) diagnostics"
            )

            try outputMinimal(result)
        }
    }

    // Helper function to parse output (moved from Parse struct)
    private func parseXcodeBuildOutput(_ output: String) throws -> XcodeBuildResult {
        var diagnostics: [XcodeDiagnostic] = []
        var buildMetrics = XcodeBuildMetrics()
        var status: BuildStatus = .unknown
        var timing = BuildTiming()

        // Split output into lines for analysis
        let lines = output.components(separatedBy: .newlines)

        // Track build timing
        var buildStartTime: Date?

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Detect build start
            if trimmedLine.contains("BUILD START") || trimmedLine.contains("xcodebuild") {
                buildStartTime = Date()
                timing.startTime = buildStartTime
            }

            // Detect build status
            if trimmedLine.contains("BUILD SUCCEEDED") {
                status = .success
                timing.endTime = Date()
                if let start = buildStartTime {
                    timing.totalDuration = Date().timeIntervalSince(start)
                }
            } else if trimmedLine.contains("BUILD FAILED") || trimmedLine.contains("error:") {
                status = .failed
                timing.endTime = Date()
                if let start = buildStartTime {
                    timing.totalDuration = Date().timeIntervalSince(start)
                }
            }


            // Parse errors
            if trimmedLine.contains(": error: ") {
                let diagnostic = parseError(from: trimmedLine, lineNumber: index + 1)
                diagnostics.append(diagnostic)
                buildMetrics.errorCount += 1
            }

            // Parse warnings
            if trimmedLine.contains(": warning: ") {
                let diagnostic = parseWarning(from: trimmedLine, lineNumber: index + 1)
                diagnostics.append(diagnostic)
                buildMetrics.warningCount += 1
            }

            // Parse file compilation
            if trimmedLine.contains("Compiling") && trimmedLine.hasSuffix(".swift") {
                let filename = extractFilename(from: trimmedLine)
                buildMetrics.compiledFiles.append(filename)
            }
        }

        // Determine final status if not explicitly found
        if status == .unknown {
            status = buildMetrics.errorCount == 0 ? .success : .failed
        }

        return XcodeBuildResult(
            status: status,
            diagnostics: diagnostics,
            metrics: buildMetrics,
            timing: timing
        )
    }

    // Helper functions (moved from Parse struct)
    private func parseError(from line: String, lineNumber: Int) -> XcodeDiagnostic {
        return parseXcodeDiagnostic(from: line, severity: .error, lineNumber: lineNumber)
    }

    private func parseWarning(from line: String, lineNumber: Int) -> XcodeDiagnostic {
        return parseXcodeDiagnostic(from: line, severity: .warning, lineNumber: lineNumber)
    }

    private func parseXcodeDiagnostic(from line: String, severity: DiagnosticSeverity, lineNumber: Int) -> XcodeDiagnostic {
        let components = line.components(separatedBy: ": ")
        let location = components[0].trimmingCharacters(in: .whitespaces)
        let messageComponents = components.count > 1 ? Array(components[1...]) : [String]()

        return XcodeDiagnostic(
            severity: severity,
            category: .build,
            message: messageComponents.joined(separator: ": "),
            location: location,
            lineNumber: lineNumber
        )
    }

    private func extractFilename(from line: String) -> String {
        let components = line.components(separatedBy: " ")
        if let lastComponent = components.last, lastComponent.hasSuffix(".swift") {
            return lastComponent
        }
        return "unknown.swift"
    }

    private func outputMinimal(_ result: XcodeBuildResult) throws {
        let duration = String(format: "%.1fs", result.timing.totalDuration)
        let output = SmithCLIOutput()
        let status = result.status == .success ? "SUCCESS" : "FAILED"
        output.success("\(status) | ERRORS: \(result.metrics.errorCount) | WARNINGS: \(result.metrics.warningCount) | FILES: \(result.metrics.compiledFiles.count) | \(duration)")
    }
}

// MARK: - Parse Command (Pipe Processor)

struct Parse: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Parse xcodebuild output from stdin",
        discussion: """
        Parses xcodebuild build output from stdin and converts it to structured,
        token-efficient formats optimized for AI agent consumption.

        Usage: xcodebuild build -scheme MyApp 2>&1 | smith-xcsift parse
        """
    )

    @Option(name: .shortAndLong, help: "Output format (json, compact, summary, detailed)")
    var format: OutputFormat = .json

    @Flag(name: .shortAndLong, help: "Include raw output for debugging")
    var verbose = false

    @Flag(name: .long, help: "Compact output mode (60-70% size reduction)")
    var compact = false

    @Flag(name: .long, help: "Minimal output mode (85%+ size reduction)")
    var minimal = false

    @Option(name: .long, help: "Minimum issue severity to include (info, warning, error)")
    var severity: String = "info"

    @Flag(name: .long, help: "Include build timing metrics")
    var timing = false

    @Flag(name: .long, help: "Include file-specific analysis")
    var files = false

    func run() throws {
        // Check if input is being piped
        if isatty(STDIN_FILENO) != 0 {
            let output = SmithCLIOutput()
            output.warning("smith-xcsift parse: No input detected. Pipe xcodebuild output.")
            output.info("Usage: xcodebuild build -scheme MyApp 2>&1 | smith-xcsift parse")
            throw ExitCode.failure
        }

        let input = FileHandle.standardInput.readDataToEndOfFile()
        let output = String(data: input, encoding: .utf8) ?? ""

        guard !output.isEmpty else {
            let error = ResourceError(
                code: "SMITH_RES_001",
                message: "No input received",
                technicalDetails: "Stdin was empty or contained no data",
                suggestedActions: ["Verify xcodebuild is producing output", "Check build command syntax"],
                isFatal: true
            )
            print(error.jsonString)
            throw ExitCode.failure
        }

        // ADD: Progress tracking
        let progress = SmithProgress()
        progress.start(title: "Parsing Xcode Build Output")

        // Parse and format output using smith-xcsift logic
        let result = try parseXcodeBuildOutput(output)

        // ADD: Finish progress
        progress.finish(
            success: result.status != .failed,
            finalMessage: "Parse complete"
        )

        switch format {
        case .json:
            if minimal {
                try outputMinimal(result)
            } else if compact {
                try outputCompact(result)
            } else {
                try outputJSON(result)
            }
        case .compact:
            try outputCompact(result)
        case .summary:
            try outputSummary(result)
        case .detailed:
            try outputDetailed(result)
        }
    }

    private func parseXcodeBuildOutput(_ output: String) throws -> XcodeBuildResult {
        var diagnostics: [XcodeDiagnostic] = []
        var buildMetrics = XcodeBuildMetrics()
        var status: BuildStatus = .unknown
        var timing = BuildTiming()

        // Split output into lines for analysis
        let lines = output.components(separatedBy: .newlines)

        // Track build timing
        var buildStartTime: Date?

        for (index, line) in lines.enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)

            // Detect build start
            if trimmedLine.contains("BUILD START") || trimmedLine.contains("xcodebuild") {
                buildStartTime = Date()
                timing.startTime = buildStartTime
            }

            // Detect build status
            if trimmedLine.contains("BUILD SUCCEEDED") {
                status = .success
                timing.endTime = Date()
                if let start = buildStartTime {
                    timing.totalDuration = Date().timeIntervalSince(start)
                }
            } else if trimmedLine.contains("BUILD FAILED") || trimmedLine.contains("error:") {
                status = .failed
                timing.endTime = Date()
                if let start = buildStartTime {
                    timing.totalDuration = Date().timeIntervalSince(start)
                }
            }

            
            // Parse errors
            if trimmedLine.contains(": error: ") {
                let diagnostic = parseError(from: trimmedLine, lineNumber: index + 1)
                if shouldInclude(diagnostic, severity: severity) {
                    diagnostics.append(diagnostic)
                }
                buildMetrics.errorCount += 1
            }

            // Parse warnings
            if trimmedLine.contains(": warning: ") {
                let diagnostic = parseWarning(from: trimmedLine, lineNumber: index + 1)
                if shouldInclude(diagnostic, severity: severity) {
                    diagnostics.append(diagnostic)
                }
                buildMetrics.warningCount += 1
            }

            // Parse file compilation
            if trimmedLine.contains("Compiling") && trimmedLine.hasSuffix(".swift") {
                let filename = extractFilename(from: trimmedLine)
                buildMetrics.compiledFiles.append(filename)
            }
        }

        // Determine final status if not explicitly found
        if status == .unknown {
            status = buildMetrics.errorCount == 0 ? .success : .failed
        }

        return XcodeBuildResult(
            status: status,
            diagnostics: diagnostics,
            metrics: buildMetrics,
            timing: timing
        )
    }

    private func parseError(from line: String, lineNumber: Int) -> XcodeDiagnostic {
        return parseXcodeDiagnostic(from: line, severity: .error, lineNumber: lineNumber)
    }

    private func parseWarning(from line: String, lineNumber: Int) -> XcodeDiagnostic {
        return parseXcodeDiagnostic(from: line, severity: .warning, lineNumber: lineNumber)
    }

    private func parseXcodeDiagnostic(from line: String, severity: DiagnosticSeverity, lineNumber: Int) -> XcodeDiagnostic {
        let components = line.components(separatedBy: ": ")
        let location = components[0].trimmingCharacters(in: .whitespaces)
        let messageComponents = components.count > 1 ? Array(components[1...]) : [String]()

        return XcodeDiagnostic(
            severity: severity,
            category: .build,
            message: messageComponents.joined(separator: ": "),
            location: location,
            lineNumber: lineNumber
        )
    }

    private func extractPhase(from line: String) -> String {
        // Extract phase name from build output
        if let range = line.range(of: "=== ") {
            return String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Unknown"
    }

    private func extractFilename(from line: String) -> String {
        let components = line.components(separatedBy: " ")
        if let lastComponent = components.last, lastComponent.hasSuffix(".swift") {
            return lastComponent
        }
        return "unknown.swift"
    }

    private func shouldInclude(_ diagnostic: XcodeDiagnostic, severity: String) -> Bool {
        let severityLevels: [DiagnosticSeverity] = [.info, .warning, .error]
        guard let minSeverityIndex = severityLevels.firstIndex(of: DiagnosticSeverity(rawValue: severity) ?? .info),
              let diagnosticIndex = severityLevels.firstIndex(of: diagnostic.severity) else {
            return true
        }
        return diagnosticIndex >= minSeverityIndex
    }

    private func outputJSON(_ result: XcodeBuildResult) throws {
        let json = try JSONEncoder().encode(result)
        if let jsonString = String(data: json, encoding: .utf8) {
            print(jsonString)
        }
    }

    private func outputCompact(_ result: XcodeBuildResult) throws {
        let compactResult = CompactXcodeResult(
            status: result.status,
            errors: result.metrics.errorCount,
            warnings: result.metrics.warningCount,
            files: result.metrics.compiledFiles.count,
            duration: result.timing.totalDuration
        )
        let json = try JSONEncoder().encode(compactResult)
        if let jsonString = String(data: json, encoding: .utf8) {
            print(jsonString)
        }
    }

    private func outputMinimal(_ result: XcodeBuildResult) throws {
        let duration = String(format: "%.1fs", result.timing.totalDuration)
        let output = SmithCLIOutput()
        let status = result.status == .success ? "SUCCESS" : "FAILED"
        output.success("\(status) | ERRORS: \(result.metrics.errorCount) | WARNINGS: \(result.metrics.warningCount) | FILES: \(result.metrics.compiledFiles.count) | \(duration)")
    }

    private func outputSummary(_ result: XcodeBuildResult) throws {
        print("BUILD \(result.status.rawValue.uppercased())")
        print("ERRORS \(result.metrics.errorCount)")
        print("WARNINGS \(result.metrics.warningCount)")
        print("FILES COMPILED \(result.metrics.compiledFiles.count)")
        print("DURATION \(String(format: "%.1f", result.timing.totalDuration))s")

        if !result.diagnostics.isEmpty {
            print("DIAGNOSTICS")
            for diagnostic in result.diagnostics.prefix(10) { // Limit output
                let emoji = emojiForDiagnosticSeverity(diagnostic.severity)
                print("\(emoji) \(diagnostic.location): \(diagnostic.message)")
            }
            if result.diagnostics.count > 10 {
                print("... and \(result.diagnostics.count - 10) more")
            }
        }
    }

    private func outputDetailed(_ result: XcodeBuildResult) throws {
        print("XCODE BUILD ANALYSIS")
        print("====================")
        print("Status: \(result.status.rawValue)")
        print("Duration: \(String(format: "%.2f", result.timing.totalDuration))s")
        print("Errors: \(result.metrics.errorCount)")
        print("Warnings: \(result.metrics.warningCount)")
        print("Files Compiled: \(result.metrics.compiledFiles.count)")

        if !result.diagnostics.isEmpty {
            print("\nDIAGNOSTICS (\(result.diagnostics.count))")
            print("------------")
            for diagnostic in result.diagnostics {
                let emoji = emojiForDiagnosticSeverity(diagnostic.severity)
                print("\(emoji) [\(diagnostic.severity.rawValue.uppercased())] \(diagnostic.location)")
                print("   \(diagnostic.message)")
                print()
            }
        }
    }

    private func emojiForDiagnosticSeverity(_ severity: DiagnosticSeverity) -> String {
        switch severity {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

// MARK: - Analyze Command

struct Analyze: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Analyze Xcode project without building"
    )

    @Argument(help: "Path to Xcode project/workspace (default: current directory)")
    var path: String = "."

    @Flag(name: .long, help: "Output in JSON format")
    var json = false

    @Flag(name: .long, help: "Include detailed diagnostics")
    var detailed = false

    func run() throws {
        let resolvedPath = (path as NSString).standardizingPath

        // ADD: Progress tracking with phases
        let progress = SmithProgress()
        progress.start(title: "Analyzing Xcode Project")

        progress.update(current: 1, total: 4, phase: "Detection", message: "Detecting project type")
        let projectType = ProjectDetector.detectProjectType(at: resolvedPath)

        progress.update(current: 2, total: 4, phase: "Analysis", message: "Running analysis")
        let analysis = SmithCore.quickAnalyze(at: resolvedPath)

        progress.update(current: 3, total: 4, phase: "Metrics", message: "Gathering metrics")

        if detailed {
            progress.update(current: 4, total: 4, phase: "Formatting", message: "Formatting detailed output")
            print("\n📊 DETAILED METRICS")
            print("===================")
            print("Source Files: \(analysis.metrics.fileCount ?? 0)")
            print("Dependencies: \(analysis.dependencyGraph.targetCount)")
            print("Max Depth: \(analysis.dependencyGraph.maxDepth)")
            print("Circular Dependencies: \(analysis.dependencyGraph.circularDeps ? "Yes" : "No")")
        }

        if json {
            progress.update(current: 4, total: 4, phase: "JSON", message: "Generating JSON output")
            if let jsonData = SmithCore.formatJSON(analysis) {
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            }
        }

        progress.finish(success: true, finalMessage: "Analysis complete")

        print("🔍 SMITH XCODE PROJECT ANALYSIS")
        print("===============================")
        print("📁 Project: \(URL(fileURLWithPath: resolvedPath).lastPathComponent)")
        print("🏗️  Type: \(formatProjectType(projectType))")

        if detailed {
            print("\n📊 DETAILED METRICS")
            print("===================")
            print("Source Files: \(analysis.metrics.fileCount ?? 0)")
            print("Dependencies: \(analysis.dependencyGraph.targetCount)")
            print("Max Depth: \(analysis.dependencyGraph.maxDepth)")
            print("Circular Dependencies: \(analysis.dependencyGraph.circularDeps ? "Yes" : "No")")
        }

        if json {
            if let jsonData = SmithCore.formatJSON(analysis) {
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print(jsonString)
                }
            }
        }
    }
}

// MARK: - Validate Command

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Validate Xcode project configuration"
    )

    @Argument(help: "Path to Xcode project/workspace (default: current directory)")
    var path: String = "."

    @Flag(name: .long, help: "Perform deep validation")
    var deep = false

    func run() throws {
        let resolvedPath = (path as NSString).standardizingPath

        // ADD: Progress tracking
        let progress = SmithProgress()
        progress.start(title: "Validating Xcode Project")

        progress.update(current: 1, total: 3, phase: "Detection", message: "Detecting configuration")
        let projectType = ProjectDetector.detectProjectType(at: resolvedPath)

        progress.update(current: 2, total: 3, phase: "Analysis", message: "Analyzing structure")
        let analysis = SmithCore.quickAnalyze(at: resolvedPath)

        progress.update(current: 3, total: 3, phase: "Assessment", message: "Assessing risks")
        let issues = SmithCore.assessBuildRisk(analysis)

        progress.finish(success: issues.isEmpty, finalMessage: "Validation complete")

        print("✅ SMITH XCODE PROJECT VALIDATION")
        print("===============================")
        print("📊 Project Type: \(formatProjectType(projectType))")

        if issues.isEmpty {
            print("✅ Project configuration looks good")
        } else {
            print("⚠️  Found \(issues.count) issue(s):")
            for issue in issues {
                let emoji = emojiForSmithCoreDiagnosticSeverity(issue.severity)
                print("\(emoji) [\(String(describing: issue.category))] \(issue.message)")
                if let suggestion = issue.suggestion {
                    print("   💡 \(suggestion)")
                }
            }
        }
    }

    private func emojiForDiagnosticSeverity(_ severity: DiagnosticSeverity) -> String {
        switch severity {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }

    private func emojiForSmithCoreDiagnosticSeverity(_ severity: Diagnostic.Severity) -> String {
        switch severity {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }
}

// MARK: - Supporting Types

enum OutputFormat: String, ExpressibleByArgument {
    case json = "json"
    case compact = "compact"
    case summary = "summary"
    case detailed = "detailed"
}

enum BuildStatus: String, Codable {
    case success = "success"
    case failed = "failed"
    case unknown = "unknown"
}

enum DiagnosticSeverity: String, Codable {
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

struct XcodeDiagnostic: Codable {
    let severity: DiagnosticSeverity
    let category: Category
    let message: String
    let location: String
    let lineNumber: Int

    enum Category: String, Codable {
        case build = "build"
        case compilation = "compilation"
        case linking = "linking"
        case dependency = "dependency"
    }
}

struct XcodeBuildMetrics: Codable {
    var errorCount: Int = 0
    var warningCount: Int = 0
    var compiledFiles: [String] = []

    init() {}
}

struct BuildTiming: Codable {
    var startTime: Date?
    var endTime: Date?
    var totalDuration: TimeInterval = 0.0

    init() {}
}

struct XcodeBuildResult: Codable {
    let status: BuildStatus
    let diagnostics: [XcodeDiagnostic]
    let metrics: XcodeBuildMetrics
    let timing: BuildTiming

    init(status: BuildStatus, diagnostics: [XcodeDiagnostic], metrics: XcodeBuildMetrics, timing: BuildTiming) {
        self.status = status
        self.diagnostics = diagnostics
        self.metrics = metrics
        self.timing = timing
    }
}

struct CompactXcodeResult: Codable {
    let status: BuildStatus
    let errors: Int
    let warnings: Int
    let files: Int
    let duration: TimeInterval
}

// MARK: - Helper Functions

private func formatProjectType(_ type: ProjectType) -> String {
    switch type {
    case .spm: return "Swift Package"
    case .xcodeProject(let project): return "Xcode Project (\(project))"
    case .xcodeWorkspace(let workspace): return "Xcode Workspace (\(workspace))"
    case .unknown: return "Unknown"
    }
}