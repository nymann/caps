#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

swiftc -O caps.swift -o caps.app/Contents/MacOS/caps
codesign -s "caps-dev-knj" --force --identifier dev.nymann.caps caps.app
echo "built: caps.app  ($(du -h caps.app/Contents/MacOS/caps | cut -f1))"
