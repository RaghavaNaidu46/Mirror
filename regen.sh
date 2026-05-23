#!/usr/bin/env bash
# Regenerate the Xcode project from project.yml and patch the Debug scheme to
# disable Metal API Validation. The reactions compositor on Apple Silicon trips
# a false-positive `didModifyRange:` assertion that aborts the app in debug
# builds; xcodegen doesn't expose the scheme attribute that suppresses it, so
# we patch the .xcscheme XML directly after generation.
set -euo pipefail

cd "$(dirname "$0")"

xcodegen

scheme="HandMirror.xcodeproj/xcshareddata/xcschemes/HandMirror.xcscheme"
if ! grep -q 'enableMetalAPIValidation' "$scheme"; then
  /usr/bin/sed -i '' 's|allowLocationSimulation = "YES">|allowLocationSimulation = "YES"\
      enableGPUValidationMode = "0"\
      enableMetalAPIValidation = "No">|' "$scheme"
  echo "Patched $scheme to disable Metal API Validation."
fi
