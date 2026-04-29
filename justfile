_default:
    @just --list

# Compile and re-sign caps.app
build:
    ./build.sh

# Rebuild and restart the running tap (TCC grant survives)
reload: build
    launchctl kickstart -k gui/$(id -u)/dev.nymann.caps

# Restart the running tap without rebuilding
restart:
    launchctl kickstart -k gui/$(id -u)/dev.nymann.caps

# Tail caps stderr (debug logging only when CAPS_DEBUG=1)
logs:
    tail -f /tmp/caps.err

# Show what's running and the hidutil remap state
status:
    @echo "=== launchd jobs ==="
    @launchctl list | grep dev.nymann.caps || echo "  (none loaded)"
    @echo ""
    @echo "=== caps process ==="
    @ps -axww -o pid,ppid,rss,etime,command | grep "caps.app/Contents/MacOS" | grep -v grep || echo "  (not running)"
    @echo ""
    @echo "=== hidutil remap ==="
    @hidutil property --get UserKeyMapping

# Install LaunchAgents (run hidutil remap + caps at login)
install:
    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.nymann.caps.remap.plist || true
    launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/dev.nymann.caps.plist || true
    @just status

# Stop and unload everything (does not remove files)
uninstall:
    -launchctl bootout gui/$(id -u)/dev.nymann.caps
    -launchctl bootout gui/$(id -u)/dev.nymann.caps.remap
    hidutil property --set '{"UserKeyMapping":[]}'

# Run with verbose event logging in the foreground (kills the launchd-managed instance first)
debug:
    -launchctl bootout gui/$(id -u)/dev.nymann.caps
    CAPS_DEBUG=1 ./caps.app/Contents/MacOS/caps

# Tag, build, zip and publish a GitHub release. Triggers the
# bump-cask workflow which opens a PR against nymann/homebrew-tap.
release VERSION:
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ -n "$(git status --porcelain)" ]]; then
        echo "working tree dirty — commit or stash before releasing" >&2
        exit 1
    fi
    just build
    mkdir -p build
    rm -f build/caps-*.zip
    ditto -c -k --sequesterRsrc --keepParent caps.app build/caps-{{VERSION}}.zip
    git tag -a v{{VERSION}} -m "v{{VERSION}}"
    git push origin v{{VERSION}}
    gh release create v{{VERSION}} build/caps-{{VERSION}}.zip \
        --title "v{{VERSION}}" --generate-notes
