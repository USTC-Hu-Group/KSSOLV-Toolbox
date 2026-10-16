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
    if [[ -n "$GROUP" ]]; then kill -KILL -- "-$GROUP" 2>/dev/null || true; fi
    rm -rf "$WORK"
}
trap cleanup EXIT
mkdir -p "$WORK/original.app/Contents/MacOS" "$WORK/original.app/Contents/Resources" \
    "$WORK/runtime/runtime/maca64" "$WORK/runtime/bin/maca64"
printf 'int main(void) { return 0; }\n' > "$WORK/fake.c"
xcrun clang -target arm64-apple-macos12.0 "$WORK/fake.c" -o "$WORK/original.app/Contents/MacOS/KSSOLV_Toolbox"
cat > "$WORK/original.app/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?><plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>KSSOLV_Toolbox</string>
<key>CFBundleIdentifier</key><string>com.hanhai.kssolv.fake</string>
<key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
EOF
cat > "$WORK/runner.sh" <<'EOF'
#!/bin/bash
set -euo pipefail
if [[ "${2:-}" == '--prewarm' ]]; then
    [[ -z "${KSSOLV_STARTUP_SIGNAL:-}" && -z "${KSSOLV_STARTUP_NONCE:-}" ]]
    echo "$$" > "$KSSOLV_STARTUP_TEST_PREWARM_PID"
    echo KSSOLV_UI_PREWARM_OK
    exit 0
fi
echo "$$" > "$KSSOLV_STARTUP_TEST_PID"
signal="$KSSOLV_STARTUP_SIGNAL"
nonce="$KSSOLV_STARTUP_NONCE"
printf '{"protocol":1,"status":"shell-ready","nonce":"%s"}\n' "$nonce" > "$signal.tmp"
mv "$signal.tmp" "$signal"
for ((i=0; i<100; i++)); do
    if [[ -f "$signal.reveal" ]]; then break; fi
    sleep 0.1
done
[[ "$nonce" == "$(/usr/bin/plutil -extract nonce raw -o - "$signal.reveal")" ]]
printf '{"protocol":1,"status":"visible","nonce":"%s"}\n' "$nonce" > "$signal.tmp"
mv "$signal.tmp" "$signal"
sleep 60
EOF
/bin/bash "$SCRIPTS_DIR/build_startup_app.sh" "$WORK/original.app" "$WORK/runner.sh" \
    "$WORK/KSSOLV_Toolbox.app" R2026b 0.0.1
HOST="$WORK/KSSOLV_Toolbox.app/Contents/MacOS/KSSOLV_Toolbox"
cp "$SCRIPTS_DIR/launcher/run_KSSOLV_Toolbox.sh" "$WORK/run_KSSOLV_Toolbox.sh"
chmod 0755 "$WORK/run_KSSOLV_Toolbox.sh"
KSSOLV_STARTUP_TEST_PREWARM_PID="$WORK/prewarm.pid" KSSOLV_STARTUP_SIGNAL=stale KSSOLV_STARTUP_NONCE=stale \
    "$WORK/run_KSSOLV_Toolbox.sh" "$WORK/runtime" --prewarm > "$WORK/prewarm.log" &
PREWARM_PID=$!
wait "$PREWARM_PID"
[[ "$(cat "$WORK/prewarm.pid")" == "$PREWARM_PID" ]]
grep -qx KSSOLV_UI_PREWARM_OK "$WORK/prewarm.log"
KSSOLV_RUNTIME_ROOT="$WORK/runtime" KSSOLV_STARTUP_TEST_PID="$WORK/runtime.pid" "$HOST" &
HOST_PID=$!
for ((i=0; i<200; i++)); do
    if ! kill -0 "$HOST_PID" 2>/dev/null; then break; fi
    sleep 0.1
done
if kill -0 "$HOST_PID" 2>/dev/null; then kill "$HOST_PID"; echo 'HTML host timed out' >&2; exit 1; fi
wait "$HOST_PID"
HOST_PID=''
GROUP=$(cat "$WORK/runtime.pid")
kill -0 "$GROUP" # Runtime must survive the successful host exit.
[[ -f "$WORK/original.app/Contents/MacOS/KSSOLV_Toolbox" ]]
echo 'MACOS_STARTUP_HOST_TESTS_SUCCESS (HTML handoff, retained Runtime, prewarm bypass)'
