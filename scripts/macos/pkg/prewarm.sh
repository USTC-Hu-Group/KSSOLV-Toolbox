#!/bin/bash
set -u

LABEL="com.gleamoe.kssolv.prewarm"
RUNTIME_RELEASE="@MATLAB_RUNTIME_RELEASE@"
SUPPORT='/Library/Application Support/KSSOLV Toolbox'
source "$SUPPORT/runtime-common.sh"
APP_PATH=$(kssolv_plist "$SUPPORT/application.plist" ApplicationPath || true)
APP_PATH="${APP_PATH:-/Applications/KSSOLV Toolbox.app}"
if [[ -n "${KSSOLV_APP_ROOT:-}" ]]; then APP_PATH="$KSSOLV_APP_ROOT/KSSOLV Toolbox.app"; fi
RUNNER="$APP_PATH/Contents/MacOS/KSSOLV_Toolbox"
TIMEOUT="${KSSOLV_PREWARM_TIMEOUT:-900}"

fail() {
    echo "KSSOLV prewarm: $*" >&2
    exit 1
}
[[ "$TIMEOUT" =~ ^[1-9][0-9]*$ ]] || fail "invalid timeout: $TIMEOUT"

# LaunchAgent 必须在实际用户会话中运行；不要为 root/loginwindow 创建
# MATLAB Runtime 用户配置。
USER_ID=$(/usr/bin/id -u)
if [[ "$USER_ID" -eq 0 ]]; then
    fail "must run as the application user, not root"
fi

if [[ ! -d "$APP_PATH" || ! -x "$RUNNER" ]]; then
    fail "application or Runtime launcher is missing: $APP_PATH"
fi

RUNTIME_ROOT=$(kssolv_find_runtime "$SUPPORT/runtime-requirements.plist" || true)
[[ -n "$RUNTIME_ROOT" ]] || fail "MATLAB Runtime $RUNTIME_RELEASE is not installed or is incomplete"

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kssolv-prewarm.XXXXXX")
OUTPUT_LOG="$WORK_DIR/output.log"
TIMEOUT_FLAG="$WORK_DIR/timed-out"
RUNNER_PID=""
WATCHDOG_PID=""
stop_prewarm_group() {
    # The native prewarm supervisor creates a group with its own PID, before
    # spawning Runtime/CEF. Stop that session only, never another MATLAB launch.
    if ! kill -TERM -- "-$RUNNER_PID" 2>/dev/null; then
        # The executable may fail or stall before creating its private group.
        /usr/bin/pkill -KILL -P "$RUNNER_PID" 2>/dev/null || true
        kill -KILL "$RUNNER_PID" 2>/dev/null || true
        return
    fi
    for ((attempt=0; attempt<40; attempt++)); do
        if ! kill -0 -- "-$RUNNER_PID" 2>/dev/null; then return; fi
        sleep 0.1
    done
    kill -KILL -- "-$RUNNER_PID" 2>/dev/null || true
}
stop_watchdog() {
    if [[ -n "$WATCHDOG_PID" ]]; then
        /usr/bin/pkill -TERM -P "$WATCHDOG_PID" 2>/dev/null || true
        kill "$WATCHDOG_PID" 2>/dev/null || true
        wait "$WATCHDOG_PID" 2>/dev/null || true
        WATCHDOG_PID=""
    fi
}
cleanup() {
    stop_watchdog
    if [[ -n "$RUNNER_PID" ]]; then
        stop_prewarm_group
        wait "$RUNNER_PID" 2>/dev/null || true
    fi
    /bin/rm "$OUTPUT_LOG"
    [[ ! -e "$TIMEOUT_FLAG" ]] || /bin/rm "$TIMEOUT_FLAG"
    /bin/rmdir "$WORK_DIR"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

KSSOLV_RUNTIME_ROOT="$RUNTIME_ROOT" "$RUNNER" --prewarm >"$OUTPUT_LOG" 2>&1 &
RUNNER_PID=$!
(
    sleep "$TIMEOUT"
    touch "$TIMEOUT_FLAG"
    stop_prewarm_group
) 2>/dev/null &
WATCHDOG_PID=$!

STATUS=0
wait "$RUNNER_PID" 2>/dev/null || STATUS=$?
# A killed supervisor cannot run its defer block. Reap any surviving members
# of its dedicated group before accepting success or reporting failure.
if kill -0 -- "-$RUNNER_PID" 2>/dev/null; then stop_prewarm_group; fi
RUNNER_PID=""
stop_watchdog
if [[ -e "$TIMEOUT_FLAG" ]]; then
    cat "$OUTPUT_LOG" >&2
    fail "timed out after ${TIMEOUT}s"
fi
if [[ "$STATUS" -ne 0 ]] || \
    ! /usr/bin/grep -qx 'KSSOLV_UI_PREWARM_OK' "$OUTPUT_LOG"; then
    cat "$OUTPUT_LOG" >&2
    fail "Runtime and application UI initialization did not complete (exit $STATUS)"
fi
cat "$OUTPUT_LOG"

# 预热成功后，本次安装在当前用户中只运行一次。下一次升级的
# postinstall 会重新 enable 同一 label，以适配新的应用 UUID。
if [[ "${KSSOLV_PREWARM_SKIP_UNLOAD:-0}" != "1" ]]; then
    /bin/launchctl disable "gui/$USER_ID/$LABEL" >/dev/null 2>&1 || true
    /bin/launchctl bootout "gui/$USER_ID/$LABEL" >/dev/null 2>&1 || true
fi
exit 0
