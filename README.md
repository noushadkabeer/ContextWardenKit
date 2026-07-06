# ContextWardenKit

Native macOS AI workload monitoring for Apple Silicon. Powers ContextWarden.

## Overview
ContextWardenKit provides a suite of engines for monitoring system memory, CPU/GPU usage, and thermal states specifically optimized for AI workloads on Apple Silicon.

## Requirements
- macOS 13.0+
- Apple Silicon (M1/M2/M3) recommended

## Installation
Add the package dependency to your `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/contextwarden/ContextWardenKit.git", from: "1.0.0")
]
```

## Usage
```swift
import ContextWardenKit
```

## APIs Intentionally Not Used
To ensure maximum user privacy and system security, ContextWardenKit explicitly avoids using:
- Network requests (completely offline)
- Private Apple APIs
- Accessibility APIs (unless strictly required by user intent)
- Screen recording or keystroke logging

## License
MIT License. See LICENSE for details.
