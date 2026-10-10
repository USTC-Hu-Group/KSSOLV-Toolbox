#!/bin/bash
set -u

LABEL="com.gleamoe.kssolv.prewarm"
RUNTIME_RELEASE="@MATLAB_RUNTIME_RELEASE@"
APP_ROOT="${KSSOLV_APP_ROOT:-/Applications/KSSOLV_Toolbox/application}"
APP_PATH="$APP_ROOT/KSSOLV_Toolbox.app"
RUNNER="$APP_ROOT/run_KSSOLV_Toolbox.sh"
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
    fail "application or Runtime launcher is missing: $APP_ROOT"
fi

RUNTIME_ROOTS=(
    "/Applications/MATLAB/MATLAB_Runtime/$RUNTIME_RELEASE"
    "/Applications/MATLAB/MATLABRuntime/$RUNTIME_RELEASE"
    "$HOME/Applications/MATLAB/MATLAB_Runtime/$RUNTIME_RELEASE"
    "$HOME/Applications/MATLAB/MATLABRuntime/$RUNTIME_RELEASE"
)

RUNTIME_ROOT=""
if [[ -n "${KSSOLV_RUNTIME_ROOT:-}" ]]; then
    RUNTIME_ROOT="$KSSOLV_RUNTIME_ROOT"
fi
for candidate in "${RUNTIME_ROOTS[@]}"; do
    if [[ -n "$RUNTIME_ROOT" ]]; then
        break
    fi
    if [[ -d "$candidate/runtime/maca64" && \
          -d "$candidate/bin/maca64" ]]; then
        RUNTIME_ROOT="$candidate"
        break
    fi
done

# PKG 不包含 Runtime；同步安装要求它已经就绪。登录时的备用
# LaunchAgent 会在 Runtime 暂未安装时保持启用并定期重试。
[[ -n "$RUNTIME_ROOT" && -d "$RUNTIME_ROOT/runtime/maca64" && \
    -d "$RUNTIME_ROOT/bin/maca64" ]] || \
    fail "MATLAB Runtime $RUNTIME_RELEASE is not installed"

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kssolv-prewarm.XXXXXX")
OUTPUT_LOG="$WORK_DIR/output.log"
TIMEOUT_FLAG="$WORK_DIR/timed-out"
RUNNER_PID=""
WATCHDOG_PID=""
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
        /usr/bin/pkill -KILL -P "$RUNNER_PID" 2>/dev/null || true
        kill -KILL "$RUNNER_PID" 2>/dev/null || true
    fi
    /bin/rm "$OUTPUT_LOG"
    [[ ! -e "$TIMEOUT_FLAG" ]] || /bin/rm "$TIMEOUT_FLAG"
    /bin/rmdir "$WORK_DIR"
}
trap cleanup EXIT
trap 'exit 1' HUP INT TERM

"$RUNNER" "$RUNTIME_ROOT" --prewarm >"$OUTPUT_LOG" 2>&1 &
RUNNER_PID=$!
(
    sleep "$TIMEOUT"
    touch "$TIMEOUT_FLAG"
    /usr/bin/pkill -KILL -P "$RUNNER_PID" 2>/dev/null || true
    kill -KILL "$RUNNER_PID" 2>/dev/null || true
) 2>/dev/null &
WATCHDOG_PID=$!

STATUS=0
wait "$RUNNER_PID" 2>/dev/null || STATUS=$?
RUNNER_PID=""
stop_watchdog
[[ ! -e "$TIMEOUT_FLAG" ]] || fail "timed out after ${TIMEOUT}s"
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
