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
