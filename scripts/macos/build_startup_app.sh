#!/bin/bash
# Compose a new outer app; never modify the original Compiler app or runner.
set -euo pipefail
[[ $# == 5 ]] || { echo "Usage: $0 original.app runner.sh output.app RuntimeRelease version" >&2; exit 1; }
SOURCE_APP="$1"
RUNNER="$2"
OUTPUT_APP="$3"
RUNTIME_RELEASE="$4"
VERSION="$5"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_DIR="$(cd "$SCRIPTS_DIR/../.." && pwd)"
[[ -d "$SOURCE_APP" && -f "$RUNNER" && ! -e "$OUTPUT_APP" ]] || { echo 'Invalid startup app input/output paths.' >&2; exit 1; }
[[ "$RUNTIME_RELEASE" =~ ^R[0-9]{4}[ab]$ && "$VERSION" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]] || { echo 'Invalid startup app metadata.' >&2; exit 1; }
MAIN="$SOURCE_APP/Contents/MacOS/KSSOLV_Toolbox"
[[ -f "$MAIN" ]] || { echo 'Missing original Compiler executable.' >&2; exit 1; }
ARCHS=$(/usr/bin/lipo -archs "$MAIN")
# KSSOLV's Runtime and generated runner are currently maca64 only.
[[ "$ARCHS" == 'arm64' ]] || { echo "Unsupported MATLAB app architecture: $ARCHS" >&2; exit 1; }
mkdir -p "$OUTPUT_APP/Contents/MacOS" "$OUTPUT_APP/Contents/Helpers" "$OUTPUT_APP/Contents/Resources/startup" "$OUTPUT_APP/Contents/Resources/Runtime"
ditto "$SOURCE_APP" "$OUTPUT_APP/Contents/Helpers/KSSOLV_Toolbox.app"
# Code belongs in Helpers; the interpreted runner is sealed as a resource.
# The original runner locates the app beside itself, so retain that layout by link.
cp "$RUNNER" "$OUTPUT_APP/Contents/Resources/Runtime/run_KSSOLV_Toolbox.sh"
chmod 0755 "$OUTPUT_APP/Contents/Resources/Runtime/run_KSSOLV_Toolbox.sh"
ln -s ../../Helpers/KSSOLV_Toolbox.app "$OUTPUT_APP/Contents/Resources/Runtime/KSSOLV_Toolbox.app"
cp "$REPOSITORY_DIR/scripts/startup/index.html" "$OUTPUT_APP/Contents/Resources/startup/index.html"
cp "$REPOSITORY_DIR/+kssolv/+ui/resources/icons/companyLOGO.png" "$OUTPUT_APP/Contents/Resources/startup/company-logo.png"
cp "$REPOSITORY_DIR/scripts/startup/quantum-materials.png" "$OUTPUT_APP/Contents/Resources/startup/quantum-materials.png"
ICON=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' "$SOURCE_APP/Contents/Info.plist" 2>/dev/null || true)
if [[ -n "$ICON" && "$ICON" != */* ]]; then
    [[ -f "$SOURCE_APP/Contents/Resources/$ICON" ]] || ICON="${ICON%.icns}.icns"
    [[ ! -f "$SOURCE_APP/Contents/Resources/$ICON" ]] || cp "$SOURCE_APP/Contents/Resources/$ICON" "$OUTPUT_APP/Contents/Resources/$ICON"
else
    ICON=''
fi
cat > "$OUTPUT_APP/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>KSSOLV_Toolbox</string>
<key>CFBundleIdentifier</key><string>com.hanhai.kssolv-toolbox</string>
<key>CFBundleName</key><string>KSSOLV Toolbox</string>
<key>CFBundleDisplayName</key><string>KSSOLV Toolbox</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>$VERSION</string>
<key>CFBundleVersion</key><string>$VERSION</string>
<key>CFBundleIconFile</key><string>$ICON</string>
<key>LSMinimumSystemVersion</key><string>12.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
EOF
printf '{"protocolVersion":1,"runtimeRelease":"%s","version":"%s"}\n' "$RUNTIME_RELEASE" "$VERSION" > "$OUTPUT_APP/Contents/Resources/startup-host.json"
/usr/bin/xcrun swiftc -O -swift-version 5 -target arm64-apple-macos12.0 -framework AppKit -framework WebKit \
    "$SCRIPTS_DIR/launcher/KssolvLauncher.swift" -o "$OUTPUT_APP/Contents/MacOS/KSSOLV_Toolbox"
/usr/bin/plutil -lint "$OUTPUT_APP/Contents/Info.plist"
echo "STARTUP_APP_BUILT $OUTPUT_APP"
