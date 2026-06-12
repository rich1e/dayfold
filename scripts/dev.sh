#!/usr/bin/env bash
# scripts/dev.sh - Dayfold automation script
#
# Usage:
#   ./scripts/dev.sh           build + install + launch + capture runtime log
#   ./scripts/dev.sh build     build only, print filtered compile log
#   ./scripts/dev.sh log       capture runtime log of running app (no rebuild)
#   ./scripts/dev.sh clean     clean build artifacts
#
# Options (env vars):
#   LOG_DURATION=30  seconds to capture runtime log (default: 20)

set -euo pipefail

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)/dayfold"
PROJECT="$PROJECT_DIR/dayfold.xcodeproj"
SCHEME="dayfold"
BUNDLE_ID="com.Yuqi.dayfold"
SIMULATOR_NAME="iPhone 16 Pro"
BUILD_LOG="/tmp/dayfold_build.log"
RUNTIME_LOG="/tmp/dayfold_runtime.log"
LOG_DURATION="${LOG_DURATION:-20}"

# Known-ignorable log patterns (see docs/XCODE_KNOWN_LOGS.md)
IGNORE_PATTERN='CA Event|account info cache|SLHighlightDisambiguation'
IGNORE_PATTERN+="|assistantHeight|NSLayoutConstraint|UIKBCompatInputView"
IGNORE_PATTERN+="|SystemInputAssistantView|_UIRemoteKeyboardPlaceholderView"
IGNORE_PATTERN+="|134400|CKAccountStatusNoAccount"
IGNORE_PATTERN+="|mirroring.*setup|mirroring.*recover|mirroring.*failed"
IGNORE_PATTERN+="|LocalAuthentication.*-7|Biometry is not enrolled|No identities are enrolled"
IGNORE_PATTERN+="|AXRuntimeNotifications|AX Safe category|getpwuid_r|Skipping migration"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()  { echo -e "${CYAN}>> $*${RESET}"; }
ok()   { echo -e "${GREEN}[OK] $*${RESET}"; }
warn() { echo -e "${YELLOW}[WARN] $*${RESET}"; }
err()  { echo -e "${RED}[ERR] $*${RESET}"; }
sep()  { echo -e "${BOLD}----------------------------------------------------------------------${RESET}"; }

# ---------------------------------------------------------------------------
# Get booted simulator UDID (boot if needed)
# ---------------------------------------------------------------------------
get_simulator_udid() {
    local udid
    udid=$(xcrun simctl list devices booted 2>/dev/null \
        | grep "$SIMULATOR_NAME" | head -1 \
        | grep -oE '[A-F0-9-]{36}')

    if [[ -z "$udid" ]]; then
        udid=$(xcrun simctl list devices available 2>/dev/null \
            | grep "$SIMULATOR_NAME" | head -1 \
            | grep -oE '[A-F0-9-]{36}')
        if [[ -z "$udid" ]]; then
            err "Simulator not found: $SIMULATOR_NAME"
            exit 1
        fi
        log "Booting simulator $SIMULATOR_NAME ($udid) ..."
        open -a Simulator
        xcrun simctl boot "$udid" 2>/dev/null || true
        sleep 3
    fi
    echo "$udid"
}

# ---------------------------------------------------------------------------
# Build
# ---------------------------------------------------------------------------
cmd_build() {
    sep
    log "Building scheme=$SCHEME for simulator=$SIMULATOR_NAME ..."
    sep

    local destination="platform=iOS Simulator,name=$SIMULATOR_NAME"

    set +e
    xcodebuild \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$destination" \
        -configuration Debug \
        build 2>&1 | tee "$BUILD_LOG"
    local exit_code=${PIPESTATUS[0]}
    set -e

    sep
    echo ""
    log "=== Build log analysis ==="
    echo ""

    # Errors from app source files only
    local errors
    errors=$(grep -E '^.+\.swift:[0-9]+:[0-9]+: error:' "$BUILD_LOG" 2>/dev/null || true)
    if [[ -n "$errors" ]]; then
        err "Compile errors:"
        echo "$errors"
        echo ""
    fi

    # Warnings from app source files (exclude DerivedData / Xcode internals)
    local warnings
    warnings=$(grep -E '^.+\.swift:[0-9]+:[0-9]+: warning:' "$BUILD_LOG" 2>/dev/null \
        | grep -v '/DerivedData/' | grep -v 'Xcode.app' || true)
    if [[ -n "$warnings" ]]; then
        warn "Compile warnings (app code):"
        echo "$warnings"
        echo ""
    fi

    if [[ $exit_code -eq 0 ]]; then
        ok "BUILD SUCCEEDED"
        echo ""
        log "Full build log saved to: $BUILD_LOG"
        echo ""
        log "To analyse with Claude, paste output of:"
        echo "  grep -E 'error:|warning:' $BUILD_LOG"
    else
        err "BUILD FAILED (exit $exit_code)"
        echo ""
        err "--- Error summary (paste to Claude) ---"
        sep
        grep -E 'error:|Build input file cannot be found|linker command failed' "$BUILD_LOG" \
            | grep -v '^$' | head -50 || true
        sep
        exit "$exit_code"
    fi
}

# ---------------------------------------------------------------------------
# Install and launch app
# ---------------------------------------------------------------------------
cmd_launch() {
    local udid="$1"

    local app_path
    app_path=$(find ~/Library/Developer/Xcode/DerivedData -name "dayfold.app" \
        -path "*/Debug-iphonesimulator/*" 2>/dev/null \
        | sort | tail -1)

    if [[ -z "$app_path" ]]; then
        err "No .app build artifact found. Run build first."
        exit 1
    fi

    log "Installing app to simulator ($udid) ..."
    xcrun simctl install "$udid" "$app_path"
    ok "Installed: $app_path"

    log "Terminating old process ..."
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
    sleep 0.5

    log "Launching $BUNDLE_ID ..."
    xcrun simctl launch "$udid" "$BUNDLE_ID"
    ok "App launched"
}

# ---------------------------------------------------------------------------
# Capture and filter runtime logs
# ---------------------------------------------------------------------------
cmd_log() {
    local udid="$1"

    sep
    log "Capturing runtime logs for ${LOG_DURATION}s ..."
    log "Raw log -> $RUNTIME_LOG"
    sep
    echo ""

    xcrun simctl spawn "$udid" log stream \
        --predicate 'process == "dayfold" OR processImagePath CONTAINS "dayfold"' \
        --level debug > "$RUNTIME_LOG" 2>/dev/null &
    local log_pid=$!

    sleep "$LOG_DURATION"
    kill "$log_pid" 2>/dev/null || true
    wait "$log_pid" 2>/dev/null || true

    local total_lines
    total_lines=$(wc -l < "$RUNTIME_LOG" | tr -d ' ')
    ok "Captured $total_lines lines"
    echo ""

    log "=== Runtime log analysis (known noise excluded) ==="
    echo ""

    # Unknown errors / faults / warnings
    local filtered
    filtered=$(grep -E '\s+(Error|Fault|Warning)\s+' "$RUNTIME_LOG" \
        | grep -vE "$IGNORE_PATTERN" || true)

    if [[ -z "$filtered" ]]; then
        ok "No unknown Error / Fault / Warning found"
    else
        warn "Unexpected log entries -- paste to Claude for analysis:"
        sep
        echo "$filtered"
        sep
    fi

    echo ""

    # App's own print() output (filter out system frameworks)
    local app_prints
    app_prints=$(grep 'dayfold:' "$RUNTIME_LOG" \
        | grep -vE '\((CoreData|LocalAuthentication|UIAccessibility|BaseBoard|FrontBoardServices|CoreServices|CoreLocation)\)' \
        | grep -vE "$IGNORE_PATTERN" \
        | grep -vE '\s+(Debug|Info)\s+' \
        | head -30 || true)

    if [[ -n "$app_prints" ]]; then
        log "App print() output:"
        echo "$app_prints"
        echo ""
    fi

    sep
    log "Full log: $RUNTIME_LOG"
    log "To show all filtered logs:"
    echo "  grep -E '(Error|Fault|Warning)' $RUNTIME_LOG | grep -vE 'IGNORE_PATTERN'"
    echo ""
    log "To paste to Claude (all unknown entries):"
    echo "  cat $RUNTIME_LOG | grep -vE '$IGNORE_PATTERN' | grep -vE '(Debug|Info)' | head -80"
}

# ---------------------------------------------------------------------------
# Clean
# ---------------------------------------------------------------------------
cmd_clean() {
    log "Cleaning build artifacts ..."
    xcodebuild -project "$PROJECT" -scheme "$SCHEME" clean 2>&1 | tail -3
    rm -f "$BUILD_LOG" "$RUNTIME_LOG"
    ok "Clean done"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    local cmd="${1:-all}"

    case "$cmd" in
        build)
            cmd_build
            ;;
        log)
            local udid
            udid=$(get_simulator_udid)
            cmd_log "$udid"
            ;;
        clean)
            cmd_clean
            ;;
        all|*)
            cmd_build
            echo ""
            local udid
            udid=$(get_simulator_udid)
            cmd_launch "$udid"
            echo ""
            log "Waiting 3s for app init ..."
            sleep 3
            cmd_log "$udid"
            ;;
    esac
}

main "$@"
