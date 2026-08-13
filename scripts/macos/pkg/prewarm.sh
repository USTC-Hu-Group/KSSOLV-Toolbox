#!/bin/bash
set -u

LABEL="com.gleamoe.kssolv.prewarm"
RUNTIME_RELEASE="@MATLAB_RUNTIME_RELEASE@"
APP_ROOT="${KSSOLV_APP_ROOT:-/Applications/KSSOLV_Toolbox/application}"
APP_PATH="$APP_ROOT/KSSOLV_Toolbox.app"
RUNNER="$APP_ROOT/run_KSSOLV_Toolbox.sh"

# LaunchAgent 必须在实际用户会话中运行；不要为 root/loginwindow 创建
# MATLAB Runtime 用户配置。
USER_ID=$(/usr/bin/id -u)
if [[ "$USER_ID" -eq 0 ]]; then
    exit 1
fi

if [[ ! -d "$APP_PATH" || ! -x "$RUNNER" ]]; then
    exit 1
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

# Runtime 可能由安装器并行下载。保持 LaunchAgent 启用，由 StartInterval
# 在 Runtime 就绪后重试。
if [[ -z "$RUNTIME_ROOT" ]]; then
    exit 1
fi

if ! "$RUNNER" "$RUNTIME_ROOT" --prewarm >/dev/null 2>&1; then
    exit 1
fi

# 预热成功后，本次安装在当前用户中只运行一次。下一次升级的
# postinstall 会重新 enable 同一 label，以适配新的应用 UUID。
if [[ "${KSSOLV_PREWARM_SKIP_UNLOAD:-0}" != "1" ]]; then
    /bin/launchctl disable "gui/$USER_ID/$LABEL" >/dev/null 2>&1 || true
    /bin/launchctl bootout "gui/$USER_ID/$LABEL" >/dev/null 2>&1 || true
fi
exit 0
