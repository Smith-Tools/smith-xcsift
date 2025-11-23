# Smith XCSift

Smith Xcode Build Output Parser - Token-efficient build analysis for Claude agents.

## Overview

Smith XCSift converts verbose xcodebuild output into structured, token-efficient formats designed for Claude agents and modern development workflows. It provides a 60% token reduction compared to raw build output while preserving essential diagnostic information.

## Key Features

- **Token-Efficient Parsing**: Compresses verbose xcodebuild output into structured JSON
- **Multiple Output Formats**: JSON, compact, summary, and detailed modes
- **Error and Warning Extraction**: File/line information with categorized diagnostics
- **Build Status Detection**: Success/failure detection with timing metrics
- **Integration Friendly**: Optimized for AI agent consumption and CI/CD pipelines
- **Smith Core Integration**: Consistent data models and shared functionality

## Usage

```bash
# Parse xcodebuild output (primary use case)
xcodebuild build -scheme MyApp 2>&1 | smith-xcsift parse

# Token-efficient summary format
xcodebuild build -scheme MyApp 2>&1 | smith-xcsift parse --format summary

# Compact JSON for CI/CD
xcodebuild build -scheme MyApp 2>&1 | smith-xcsift parse --format compact

# Analyze project without building
smith-xcsift analyze

# Validate project configuration
smith-xcsift validate
```

## Advanced Operations

For advanced operations like rebuild, clean, monitor, and diagnose, use smith-cli:

```bash
# Advanced rebuild with optimization
smith rebuild --workspace Project.xcworkspace --scheme MyApp

# Smart cleanup with dependency preservation
smith clean --derived-data

# Real-time build monitoring
smith monitor --workspace Project.xcworkspace --scheme MyApp --eta
```

## Requirements

- macOS 13.0+
- Xcode 14.0+
- Swift 6.0+
- Smith Core framework

## Support

Part of the Smith Tools organization. Use smith-skill for intelligent routing to relevant documentation.

