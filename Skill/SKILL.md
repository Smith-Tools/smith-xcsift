---
name: smith-xcsift
description: Xcode build output parsing and error analysis. Automatically triggers for:
             Xcode errors, iOS builds, macOS builds, build failures, xcodebuild diagnostics
allowed-tools: [Bash, Read]
executables: ["~/.local/bin/smith-xcsift", ".build/arm64-apple-macosx/release/smith-xcsift", "smith-xcsift"]
---

# Xcode Build Output Analysis

Parses Xcode build output to extract errors, warnings, and build diagnostics with token-efficient compression.

## Automatic Usage

This skill activates when users ask about:
- "Xcode build failed"
- "Analyze build output"
- "What's causing the build error"
- "iOS/macOS build diagnostics"
- "Xcode compiler errors"

## Commands

**Parse xcodebuild output** (token-optimized):
```bash
xcodebuild build -scheme MyApp 2>&1 | smith-xcsift parse
# Returns: JSON with errors, warnings, timing (60% token reduction)

# With specific format
xcodebuild build 2>&1 | smith-xcsift parse --format json
xcodebuild build 2>&1 | smith-xcsift parse --format summary
xcodebuild build 2>&1 | smith-xcsift parse --format compact
xcodebuild build 2>&1 | smith-xcsift parse --format detailed
```

**Analyze project without building**:
```bash
smith-xcsift analyze
# Returns: Project structure and configuration analysis
```

**Validate project configuration**:
```bash
smith-xcsift validate
# Returns: Configuration validation report
```

## Output Modes

- **json**: Full structured JSON with all details
- **summary**: Minimal format for quick review
- **compact**: Token-efficient compact JSON
- **detailed**: Complete diagnostic information

## Output Structure

Returns JSON containing:

- **buildStatus**: success/failure
- **errors**: File/line information with error messages
- **warnings**: Categorized warnings
- **timing**: Build duration and phase timing
- **diagnostics**: Additional diagnostic information

## Integration with Smith Tools

Works with the Smith Tools ecosystem:

- **smith-sbsift** - Swift package build analysis
- **smith-spmsift** - Swift Package Manager analysis
- **smith-validation** - Architectural validation

## Features

- Token-efficient parsing: 60% reduction vs raw output
- Error/warning extraction with file/line numbers
- Build status detection with timing metrics
- Multiple output formats for different use cases
- Smith Core integration for consistent data models
- AI agent optimization for Claude consumption

## Performance

- Parse time: <500ms for typical builds
- Token savings: 60% reduction vs raw build output
- Output size: Minimal while preserving diagnostic info
- Memory: Efficient streaming processing

## Best For

- Xcode workspace projects
- iOS/macOS application builds
- Build diagnostics and debugging
- CI/CD pipeline integration
- Error triage and analysis

---

**smith-xcsift** - Making Xcode build output AI-friendly

Last Updated: November 26, 2025
