# Cinavault Server Premium Edition (iOS)

This repository contains the iOS track of Cinavault Server Premium Edition.

## What is included

- Native iOS SwiftUI project scaffold (generated via XcodeGen on macOS)
- iOS-style Cinavault demo UI preserving core sections and menu structure
- PWA demo package for iPhone test installs (Add to Home Screen)
- Build artifact pipeline with numbered builds and per-build notes

## Build and test rules

- Every iOS build package is saved to:
  - Desktop: `C:\Users\johng\OneDrive\Documents\Desktop\John\cinavault ios builds`
  - Repo: `ios/builds/`
- Every build has a matching note file.
- Build numbers auto-increment (`v1`, `v2`, ...).

## Create iOS demo package on Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\build_ios_demo.ps1
```

## Native iOS compile (macOS required)

```bash
brew install xcodegen
cd ios/CinavaultServerPremiumEdition
xcodegen generate
open CinavaultServerPremiumEdition.xcodeproj
```

## Current limitation

A real installable `.ipa` for iPhone requires Apple signing + macOS/Xcode build or cloud signing.
This repo includes the full source scaffold and a working iPhone-installable PWA demo for immediate validation.
