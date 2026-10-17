#!/bin/bash
# Run on Apple Silicon macOS with Xcode Command Line Tools. No MATLAB is required.
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
WORK=$(mktemp -d "${TMPDIR:-/tmp}/kssolv-startup-test.XXXXXX")
GROUP=''
HOST_PID=''
cleanup() {
    if [[ -n "$HOST_PID" ]]; then kill "$HOST_PID" 2>/dev/null || true; fi
    if [[ -z "$GROUP" && -f "$WORK/runtime.pid" ]]; then GROUP=$(cat "$WORK/runtime.pid"); fi
    if [[ -n "$GROUP" ]]; then
        kill -KILL -- "-$GROUP" 2>/dev/null || true
        rm -f "$HOME/Library/Caches/KSSOLV Toolbox/dock/$GROUP.json"
    fi
    rm -rf "$WORK"
}
trap cleanup EXIT
wait_for_running() {
    # The fixture's visible notification precedes the host's next poll. Do not
    # terminate it until the host has actually installed its session monitors.
    local startup_log="$HOME/Library/Logs/KSSOLV Toolbox/startup.log"
    for ((i=0; i<100; i++)); do
        if awk -v group="$GROUP" '
            / runtime-started pid=/ { active = ($NF == "pid=" group) }
            active && / session-running$/ { ready = 1; exit }
            END { exit !ready }
        ' "$startup_log"; then return; fi
        sleep 0.1
    done
    echo 'Startup host did not complete the running-session transition' >&2
    return 1
}
mkdir -p "$WORK/original.app/Contents/MacOS" "$WORK/original.app/Contents/Resources" \
    "$WORK/runtime/runtime/maca64" "$WORK/runtime/bin/maca64/Frameworks" "$WORK/runtime/bin/maca64/matlabwindowhelper.app"
cat > "$WORK/fake.c" <<'EOF'
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
extern char **environ;
int main(void) {
    char executable[4096];
    const char *source = getenv("KSSOLV_STARTUP_TEST_APP");
    if (!source || snprintf(executable, sizeof(executable), "%s/Contents/MacOS/MATLABWindow", source) >= sizeof(executable)) return 12;
    char *arguments[] = {executable, NULL};
    const char *entry = getenv("KSSOLV_STARTUP_TEST_EXEC");
    if (entry && strcmp(entry, "execve") == 0) execve(executable, arguments, environ);
    else if (entry && strcmp(entry, "execv") == 0) execv(executable, arguments);
    else execvp(executable, arguments);
    return errno;
}
EOF
xcrun clang -target arm64-apple-macos12.0 "$WORK/fake.c" -o "$WORK/original.app/Contents/MacOS/KSSOLV_Toolbox"
cat > "$WORK/original.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>KSSOLV_Toolbox</string>
<key>CFBundleIdentifier</key><string>com.pwdft.kssolv.fixture</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
EOF
cat > "$WORK/runner.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "${2:-}" == '--prewarm' ]]; then
    [[ -z "${KSSOLV_STARTUP_SIGNAL:-}" && "${#KSSOLV_STARTUP_NONCE}" == 36 && "${KSSOLV_DOCK_BRIDGE:-}" == 1 ]]
fi
echo "$$" > "$KSSOLV_STARTUP_TEST_PID"
sleep 0.2
exec "$(dirname "$0")/KSSOLV_Toolbox.app/Contents/MacOS/KSSOLV_Toolbox"
EOF
mkdir -p "$WORK/MATLABWindow.app/Contents/MacOS"
cat > "$WORK/MATLABWindow.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MATLABWindow</string>
<key>CFBundleIdentifier</key><string>org.cef.MATLABWindow</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>LSUIElement</key><true/>
</dict></plist>
EOF
xcrun clang -fobjc-arc -fblocks -target arm64-apple-macos12.0 -framework AppKit -framework ApplicationServices \
    "$SCRIPTS_DIR/launcher/tests/DockBridgeFixture.m" -o "$WORK/MATLABWindow.app/Contents/MacOS/MATLABWindow"
ln -s "$WORK/MATLABWindow.app" "$WORK/runtime/bin/maca64/MATLABWindow.app"
KSSOLV_WINDOW_APP_SOURCE="$WORK/MATLABWindow.app" /bin/bash "$SCRIPTS_DIR/build_startup_app.sh" "$WORK/original.app" "$WORK/runner.sh" \
    "$WORK/KSSOLV Toolbox.app" R2026b 0.0.1
HOST="$WORK/KSSOLV Toolbox.app/Contents/MacOS/KSSOLV_Toolbox"
# Keep installer configuration inside the fixture. Runtime content validation is
# covered separately against both inert trees and a real installed Runtime.
mkdir -p "$WORK/support"
sed "s|SUPPORT='/Library/Application Support/KSSOLV Toolbox'|SUPPORT='$WORK/support'|" \
    "$SCRIPTS_DIR/pkg/prewarm.sh" > "$WORK/prewarm.sh"
cat > "$WORK/support/runtime-common.sh" <<'EOF'
kssolv_plist() { return 1; }
kssolv_find_runtime() { [[ -d "$KSSOLV_RUNTIME_ROOT/runtime/maca64" ]] && echo "$KSSOLV_RUNTIME_ROOT"; }
EOF
cp "$SCRIPTS_DIR/launcher/run_KSSOLV_Toolbox.sh" "$WORK/run_KSSOLV_Toolbox.sh"
chmod 0755 "$WORK/run_KSSOLV_Toolbox.sh"
KSSOLV_STARTUP_TEST_PREWARM="$WORK/prewarm-background" KSSOLV_STARTUP_TEST_PID="$WORK/prewarm.pid" \
    KSSOLV_STARTUP_TEST_APP="$WORK/runtime/bin/maca64/MATLABWindow.app" KSSOLV_STARTUP_TEST_CACHE="$WORK/window-cache-path" \
    KSSOLV_STARTUP_SIGNAL=stale KSSOLV_STARTUP_NONCE=stale \
    "$WORK/run_KSSOLV_Toolbox.sh" "$WORK/runtime" --prewarm > "$WORK/prewarm.log" 2>&1 &
PREWARM_PID=$!
wait "$PREWARM_PID"
[[ -f "$WORK/prewarm-background" ]]
[[ ! -e "$HOME/Library/Caches/KSSOLV Toolbox/dock/$PREWARM_PID.json" ]]
grep -qx KSSOLV_UI_PREWARM_OK "$WORK/prewarm.log"
grep -q prewarm-foreground-suppressed "$WORK/prewarm.log"
grep -q prewarm-regular-policy-suppressed "$WORK/prewarm.log"
grep -q prewarm-window-order-suppressed "$WORK/prewarm.log"
grep -q prewarm-order-front-regardless-suppressed "$WORK/prewarm.log"
if grep -q transfer-requested "$WORK/prewarm.log"; then echo 'Prewarm requested a foreground Dock handoff' >&2; exit 1; fi
# Exercise the actual installer watchdog with a held native CEF, not a stub that
# returns the marker without creating any application process.
KSSOLV_APP_ROOT="$WORK" KSSOLV_RUNTIME_ROOT="$WORK/runtime" KSSOLV_PREWARM_SKIP_UNLOAD=1 \
    KSSOLV_PREWARM_TIMEOUT=2 KSSOLV_STARTUP_TEST_PREWARM="$WORK/prewarm-timeout" \
    KSSOLV_STARTUP_TEST_PREWARM_HOLD=1 KSSOLV_STARTUP_TEST_PID="$WORK/prewarm-timeout.pid" \
    KSSOLV_STARTUP_TEST_APP="$WORK/runtime/bin/maca64/MATLABWindow.app" KSSOLV_STARTUP_TEST_CACHE="$WORK/window-cache-path" \
    /bin/bash "$WORK/prewarm.sh" > "$WORK/prewarm-timeout.log" 2>&1 &
PREWARM_SCRIPT=$!
if wait "$PREWARM_SCRIPT"; then echo 'Prewarm timeout incorrectly succeeded' >&2; exit 1; fi
[[ -f "$WORK/prewarm-timeout" ]]
grep -q 'timed out after 2s' "$WORK/prewarm-timeout.log"
PREWARM_CHILD=$(cat "$WORK/prewarm-timeout.pid")
if kill -0 "$PREWARM_CHILD" 2>/dev/null; then echo 'Prewarm timeout leaked CEF' >&2; exit 1; fi
KSSOLV_STARTUP_TEST_PREWARM="$WORK/prewarm-fail" KSSOLV_STARTUP_TEST_PREWARM_FAIL=1 KSSOLV_STARTUP_TEST_PID="$WORK/prewarm.pid" \
    KSSOLV_STARTUP_TEST_APP="$WORK/runtime/bin/maca64/MATLABWindow.app" KSSOLV_STARTUP_TEST_CACHE="$WORK/window-cache-path" \
    "$WORK/run_KSSOLV_Toolbox.sh" "$WORK/runtime" --prewarm > "$WORK/prewarm-fail.log" 2>&1 &
PREWARM_PID=$!
PREWARM_STATUS=0
wait "$PREWARM_PID" || PREWARM_STATUS=$?
[[ "$PREWARM_STATUS" == 23 ]]
[[ ! -e "$HOME/Library/Caches/KSSOLV Toolbox/dock/$PREWARM_PID.json" ]]
KSSOLV_APP_ROOT="$WORK" KSSOLV_RUNTIME_ROOT="$WORK/runtime" KSSOLV_PREWARM_SKIP_UNLOAD=1 \
    KSSOLV_PREWARM_TIMEOUT=15 KSSOLV_STARTUP_TEST_PREWARM="$WORK/prewarm-host-death" \
    KSSOLV_STARTUP_TEST_PREWARM_HOLD=1 KSSOLV_STARTUP_TEST_PID="$WORK/prewarm-death.pid" \
    KSSOLV_STARTUP_TEST_APP="$WORK/runtime/bin/maca64/MATLABWindow.app" KSSOLV_STARTUP_TEST_CACHE="$WORK/window-cache-path" \
    /bin/bash "$WORK/prewarm.sh" > "$WORK/prewarm-host-death.log" 2>&1 &
PREWARM_SCRIPT=$!
for ((i=0; i<100; i++)); do
    if [[ -f "$WORK/prewarm-host-death" ]]; then break; fi
    sleep 0.1
done
[[ -f "$WORK/prewarm-host-death" ]]
PREWARM_CHILD=$(cat "$WORK/prewarm-death.pid")
PREWARM_GROUP=$(ps -o pgid= -p "$PREWARM_CHILD" | tr -d ' ')
kill -KILL "$PREWARM_GROUP"
if wait "$PREWARM_SCRIPT"; then echo 'Prewarm host death incorrectly succeeded' >&2; exit 1; fi
if kill -0 "$PREWARM_CHILD" 2>/dev/null; then echo 'Prewarm host death leaked CEF' >&2; exit 1; fi
# SIGKILL cannot execute the supervisor's file cleanup. A stale registration is
# inert because the bridge validates its live host; remove this fixture's entry.
rm -f "$HOME/Library/Caches/KSSOLV Toolbox/dock/$PREWARM_GROUP.json"
KSSOLV_RUNTIME_ROOT="$WORK/runtime" KSSOLV_STARTUP_TEST_PID="$WORK/runtime.pid" \
    KSSOLV_STARTUP_TEST_APP="$WORK/runtime/bin/maca64/MATLABWindow.app" KSSOLV_STARTUP_TEST_CACHE="$WORK/window-cache-path" KSSOLV_STARTUP_TEST_VISIBLE="$WORK/visible" "$HOST" &
HOST_PID=$!
for ((i=0; i<200; i++)); do
    if [[ -f "$WORK/visible" ]]; then break; fi
    sleep 0.1
done
[[ -f "$WORK/visible" ]] || { echo 'Dock bridge handshake timed out' >&2; exit 1; }
GROUP=$(cat "$WORK/runtime.pid")
wait_for_running
kill -0 "$HOST_PID" # Startup host remains alive as accessory after ownership transfer.
lsappinfo info -app "$HOST_PID" | grep -q 'type="UIElement"'
lsappinfo info -app "$GROUP" | grep -q 'type="Foreground"'
kill -TERM "$GROUP"
for ((i=0; i<100; i++)); do
    if ! kill -0 "$HOST_PID" 2>/dev/null; then break; fi
    sleep 0.1
done
if kill -0 "$HOST_PID" 2>/dev/null; then echo 'Host did not exit with Runtime' >&2; exit 1; fi
wait "$HOST_PID"
HOST_PID=''
GROUP=''
rm "$WORK/runtime.pid"
KSSOLV_RUNTIME_ROOT="$WORK/runtime" KSSOLV_STARTUP_TEST_PID="$WORK/runtime.pid" \
    KSSOLV_STARTUP_TEST_APP="$WORK/runtime/bin/maca64/MATLABWindow.app" KSSOLV_STARTUP_TEST_CACHE="$WORK/window-cache-path" KSSOLV_STARTUP_TEST_VISIBLE="$WORK/visible-close" \
    KSSOLV_STARTUP_TEST_CLOSE="$WORK/close" KSSOLV_STARTUP_TEST_EXEC=execv "$HOST" &
HOST_PID=$!
for ((i=0; i<200; i++)); do
    if [[ -f "$WORK/visible-close" ]]; then break; fi
    sleep 0.1
done
[[ -f "$WORK/visible-close" ]] || { echo 'Close fixture timed out' >&2; exit 1; }
GROUP=$(cat "$WORK/runtime.pid")
wait_for_running
touch "$WORK/close"
for ((i=0; i<100; i++)); do
    if ! kill -0 "$HOST_PID" 2>/dev/null; then break; fi
    sleep 0.1
done
[[ -f "$(cat "$WORK/window-cache-path")/Contents/Resources/KssolvBrand.icns" ]]
[[ -f "$WORK/close.passed" ]] || { echo 'Native close/cancel fixture failed' >&2; exit 1; }
if kill -0 "$HOST_PID" 2>/dev/null; then echo 'Host did not exit after native close' >&2; exit 1; fi
wait "$HOST_PID"
HOST_PID=''
GROUP=''
rm "$WORK/runtime.pid"
KSSOLV_RUNTIME_ROOT="$WORK/runtime" KSSOLV_STARTUP_TEST_PID="$WORK/runtime.pid" \
    KSSOLV_STARTUP_TEST_APP="$WORK/runtime/bin/maca64/MATLABWindow.app" KSSOLV_STARTUP_TEST_CACHE="$WORK/window-cache-path" KSSOLV_STARTUP_TEST_VISIBLE="$WORK/visible-recovery" KSSOLV_STARTUP_TEST_EXEC=execve "$HOST" &
HOST_PID=$!
for ((i=0; i<200; i++)); do
    if [[ -f "$WORK/visible-recovery" ]]; then break; fi
    sleep 0.1
done
[[ -f "$WORK/visible-recovery" ]] || { echo 'Recovery fixture timed out' >&2; exit 1; }
GROUP=$(cat "$WORK/runtime.pid")
wait_for_running
kill -KILL "$HOST_PID"
wait "$HOST_PID" 2>/dev/null || true
HOST_PID=''
recovered=false
for ((i=0; i<100; i++)); do
    if lsappinfo info -app "$GROUP" | grep -q 'type="Foreground"'; then recovered=true; break; fi
    sleep 0.1
done
[[ "$recovered" == true ]] || { echo 'Window did not recover its Dock presence after host death' >&2; exit 1; }
[[ -f "$WORK/original.app/Contents/MacOS/KSSOLV_Toolbox" ]]
echo 'MACOS_STARTUP_HOST_TESTS_SUCCESS (initial Toolbox window suppressed, diagnostic panels allowed, serial Dock handoff, cancel/settings preserve Dock, native quit after committed close, Runtime exit, host-death survival, background prewarm policy/window suppression, timeout cleanup and exit status; no JVM)'
