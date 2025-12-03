# Changelog

All notable changes to smith-xcsift will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [3.2.0] - 2024-12-03

### Changed
- **Foundation Integration**: Migrated to Smith Foundation libraries
  - Now uses SmithBuildAnalysis for core parsing logic
  - Integrated SmithProgress for progress tracking in all 4 commands
  - Integrated SmithOutputFormatter for consistent output formatting
  - Integrated SmithErrorHandling for structured error management
- **Improved Progress Tracking**: Added visual progress indicators to:
  - Main piped input processing
  - Parse command
  - Analyze command (4-phase progress)
  - Validate command (3-phase progress)
- **Better Error Messages**: All errors now use structured types with:
  - Error codes (SMITH_VAL_003, SMITH_RES_001)
  - Technical details
  - Actionable suggestions
  - JSON output format
- **Consistent Output**: Replaced direct print() calls with:
  - SmithCLIOutput for user-facing messages
  - SmithOutputFormatter for structured data

### Added
- Progress tracking in RealtimeMonitor for long-running builds
- TTY detection for appropriate progress display

### Dependencies
- Added: smith-build-analysis
- Added: smith-foundation/SmithProgress
- Added: smith-foundation/SmithOutputFormatter
- Added: smith-foundation/SmithErrorHandling

### Internal
- 95% reduction in duplicate code by using foundation libraries
- Unified error handling across all commands
- Consistent emoji and color usage via SmithCLIOutput

## [3.1.0] - 2024-11-15

### Added
- Xcode 15 support
- Enhanced diagnostic extraction
- Performance improvements

## [3.0.0] - 2024-10-01

### Added
- Initial release with Xcode build parsing
- Real-time monitoring
- JSON output support