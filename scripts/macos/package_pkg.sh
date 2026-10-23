#!/bin/bash
set -euo pipefail
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_DIR="$SCRIPTS_DIR/../.."
RELEASE_DIR="$REPOSITORY_DIR/Release"
CACHE_DIR="$REPOSITORY_DIR/.buildtool/standalone"
PKG_ASSETS_DIR="$SCRIPTS_DIR/pkg"
PKG_IDENTIFIER=com.pwdft.kssolv
DELIVERY="${PKG_RUNTIME_DELIVERY:-auto}"
if [[ $# -gt 0 ]]; then
    [[ $# == 2 && "$1" == --runtime-delivery ]] || { echo 'Usage: package_pkg.sh [--runtime-delivery auto|web|installer|none]' >&2; exit 1; }
    DELIVERY="$2"
fi
case "$DELIVERY" in auto|web|installer|none) ;; *) echo 'Invalid Runtime delivery mode.' >&2; exit 1 ;; esac
fail() { echo "错误: $*" >&2; exit 1; }
timestamp_at_least() {
    # macOS Bash compares -nt at whole-second precision; Compiler can write
    # the executable and its metadata within the same second.
    python3 - "$1" "$2" <<'PY'
from pathlib import Path
import sys
sys.exit(0 if Path(sys.argv[1]).stat().st_mtime_ns >= Path(sys.argv[2]).stat().st_mtime_ns else 1)
PY
}
METADATA="$CACHE_DIR/build/runtime-metadata.json"
[[ -f "$METADATA" ]] || fail 'Missing runtime-metadata.json. Run buildInstaller() first.'
RUNTIME_RELEASE=$(/usr/bin/plutil -extract RuntimeRelease raw -o - "$METADATA")
STARTUP_PROTOCOL=$(/usr/bin/plutil -extract StartupProtocolVersion raw -o - "$METADATA")
BUILD_VERSION=$(/usr/bin/plutil -extract ApplicationVersion raw -o - "$METADATA")
BUILD_ARCH=$(/usr/bin/plutil -extract Architecture raw -o - "$METADATA")
VERSION=$(sed -nE "s/^[[:space:]]*Version[[:space:]]+string[[:space:]]*=[[:space:]]*'([^']+)'.*/\1/p" "$REPOSITORY_DIR/KSSOLV_Toolbox.m" | head -n 1)
[[ -n "$VERSION" && "$STARTUP_PROTOCOL" == 1 && "$BUILD_VERSION" == "$VERSION" && "$BUILD_ARCH" == maca64 ]] || fail '基础构建版本、架构或启动协议不匹配'
[[ "$RUNTIME_RELEASE" =~ ^R[0-9]{4}[ab]$ ]] || fail '无效的 RuntimeRelease'
[[ -z "${MATLAB_RUNTIME_RELEASE:-}" || "$MATLAB_RUNTIME_RELEASE" == "$RUNTIME_RELEASE" ]] || fail 'Runtime 版本与基础构建不一致'
/usr/bin/xcrun --find swiftc >/dev/null 2>&1 || fail '请安装 Xcode Command Line Tools'
command -v python3 >/dev/null || fail '打包需要 Python 3；安装后的应用和安装脚本不依赖 Python'
INSTALLER_APP="$CACHE_DIR/base-installer/KSSOLV_Toolbox_V$VERSION.app"
BUNDLE_ZIP="$INSTALLER_APP/Contents/Resources/bundle.zip"
[[ -f "$BUNDLE_ZIP" ]] && timestamp_at_least "$BUNDLE_ZIP" "$METADATA" || fail '基础安装器缺失或早于编译元数据，请运行 buildInstaller()'
for asset in preinstall postinstall prewarm.sh prepare-runtime runtime-common.sh com.gleamoe.kssolv.prewarm.plist; do
    [[ -f "$PKG_ASSETS_DIR/$asset" ]] || fail "找不到 PKG 资源: $asset"
done

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kssolv-pkg.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT
APP_PAYLOAD="$WORK_DIR/application"
SUPPORT_PAYLOAD="$WORK_DIR/support"
APP_SCRIPTS="$WORK_DIR/app-scripts"
SUPPORT_SCRIPTS="$WORK_DIR/support-scripts"
PACKAGES="$WORK_DIR/packages"
RESOURCES="$WORK_DIR/resources"
mkdir -p "$APP_PAYLOAD" "$APP_SCRIPTS" "$SUPPORT_SCRIPTS" "$PACKAGES" "$RESOURCES" "$WORK_DIR/extracted"
python3 "$SCRIPTS_DIR/stage_runtime_payload.py" "$CACHE_DIR/build" "$INSTALLER_APP" "$SUPPORT_SCRIPTS" --delivery "$DELIVERY" > "$WORK_DIR/runtime-staging.json"
REQUIREMENTS="$SUPPORT_SCRIPTS/runtime-requirements.plist"
DELIVERY=$(/usr/libexec/PlistBuddy -c 'Print :RuntimeDelivery' "$REQUIREMENTS")
OUTPUT_PKG="${PKG_OUTPUT_PATH:-$RELEASE_DIR/KSSOLV_Toolbox_V${VERSION}.pkg}"
mkdir -p "$(dirname "$OUTPUT_PKG")"

ditto -x -k "$BUNDLE_ZIP" "$WORK_DIR/extracted"
ORIGINAL="$WORK_DIR/extracted/application/KSSOLV_Toolbox.app"
RUNNER="$WORK_DIR/extracted/application/run_KSSOLV_Toolbox.sh"
[[ -d "$ORIGINAL" && -x "$RUNNER" ]] || fail '基础安装器缺少 Compiler 应用或 runner'
timestamp_at_least "$METADATA" "$ORIGINAL/Contents/MacOS/KSSOLV_Toolbox" || fail '编译元数据已过期'
/bin/bash "$SCRIPTS_DIR/build_startup_app.sh" "$ORIGINAL" "$RUNNER" "$APP_PAYLOAD/KSSOLV Toolbox.app" "$RUNTIME_RELEASE" "$VERSION"
cp "$REQUIREMENTS" "$APP_PAYLOAD/KSSOLV Toolbox.app/Contents/Resources/runtime-requirements.plist"

SUPPORT="$SUPPORT_PAYLOAD/Library/Application Support/KSSOLV Toolbox"
mkdir -p "$SUPPORT" "$SUPPORT_PAYLOAD/Library/LaunchAgents"
cp "$PKG_ASSETS_DIR/prewarm.sh" "$PKG_ASSETS_DIR/runtime-common.sh" "$SUPPORT/"
cp "$REQUIREMENTS" "$SUPPORT/"
/usr/bin/sed -i '' "s/@MATLAB_RUNTIME_RELEASE@/$RUNTIME_RELEASE/g" "$SUPPORT/prewarm.sh"
cp "$PKG_ASSETS_DIR/com.gleamoe.kssolv.prewarm.plist" "$SUPPORT_PAYLOAD/Library/LaunchAgents/"
cp "$PKG_ASSETS_DIR/runtime-common.sh" "$SUPPORT_SCRIPTS/"
if [[ "$DELIVERY" == none ]]; then
    # A payload-free component conveys the native Runtime folder selection in
    # $2. Support files still install at /Library, never inside that Runtime.
    RUNTIME_SCRIPTS="$WORK_DIR/runtime-scripts"
    mkdir -p "$RUNTIME_SCRIPTS"
    cp "$PKG_ASSETS_DIR/prepare-runtime" "$RUNTIME_SCRIPTS/preinstall"
    cp "$PKG_ASSETS_DIR/runtime-common.sh" "$REQUIREMENTS" "$RUNTIME_SCRIPTS/"
    chmod 0755 "$RUNTIME_SCRIPTS/preinstall"
    pkgbuild --nopayload --scripts "$RUNTIME_SCRIPTS" --identifier "$PKG_IDENTIFIER.runtime-selection" \
        --version "$VERSION" --install-location / "$PACKAGES/KSSOLVRuntime.pkg"
else
    cp "$PKG_ASSETS_DIR/prepare-runtime" "$SUPPORT_SCRIPTS/preinstall"
    chmod 0755 "$SUPPORT_SCRIPTS/preinstall"
fi
cp "$PKG_ASSETS_DIR/preinstall" "$APP_SCRIPTS/preinstall"
cp "$PKG_ASSETS_DIR/postinstall" "$APP_SCRIPTS/finalize-install.sh"
cp "$PKG_ASSETS_DIR/runtime-common.sh" "$REQUIREMENTS" "$APP_SCRIPTS/"
chmod 0755 "$APP_SCRIPTS/preinstall" "$APP_SCRIPTS/finalize-install.sh" "$SUPPORT/"*.sh
chmod 0644 "$SUPPORT_PAYLOAD/Library/LaunchAgents/"*.plist
for tree in "$APP_PAYLOAD" "$SUPPORT_PAYLOAD" "$SUPPORT_SCRIPTS"; do
    chmod -R u+w "$tree"
    find "$tree" \( -name '._*' -o -name .DS_Store \) -delete
    xattr -cr "$tree"
done

COMPONENTS="$WORK_DIR/components.plist"
pkgbuild --analyze --root "$APP_PAYLOAD" "$COMPONENTS"
index=0
outer=''
while bundle=$(/usr/libexec/PlistBuddy -c "Print :$index:RootRelativeBundlePath" "$COMPONENTS" 2>/dev/null); do
    /usr/libexec/PlistBuddy -c "Set :$index:BundleIsRelocatable false" "$COMPONENTS"
    /usr/libexec/PlistBuddy -c "Set :$index:BundleIsVersionChecked false" "$COMPONENTS"
    /usr/libexec/PlistBuddy -c "Set :$index:BundleOverwriteAction upgrade" "$COMPONENTS"
    if [[ "$bundle" == 'KSSOLV Toolbox.app' ]]; then
        outer="$index"
        /usr/libexec/PlistBuddy -c "Set :$index:BundleHasStrictIdentifier false" "$COMPONENTS"
    fi
    index=$((index + 1))
done
[[ -n "$outer" ]] || fail '找不到外层应用组件'
/usr/libexec/PlistBuddy -c "Add :$outer:BundlePostInstallScriptPath string finalize-install.sh" "$COMPONENTS"
/usr/libexec/PlistBuddy -c "Add :$outer:BundleInstallScriptTimeout integer 1200" "$COMPONENTS"
pkgbuild --root "$SUPPORT_PAYLOAD" --scripts "$SUPPORT_SCRIPTS" --identifier "$PKG_IDENTIFIER.support" --version "$VERSION" --install-location / "$WORK_DIR/support.pkg"
# A first download can exceed PackageKit's default 600-second script timeout.
pkgutil --expand "$WORK_DIR/support.pkg" "$WORK_DIR/support-expanded"
python3 - "$WORK_DIR/support-expanded/PackageInfo" <<'PY'
import sys,xml.etree.ElementTree as ET
p=sys.argv[1]; tree=ET.parse(p)
preinstall=tree.getroot().find('scripts/preinstall')
if preinstall is not None:
    preinstall.set('timeout','7200')
tree.write(p,encoding='utf-8',xml_declaration=True)
PY
pkgutil --flatten "$WORK_DIR/support-expanded" "$PACKAGES/KSSOLVSupport.pkg"
pkgbuild --root "$APP_PAYLOAD" --component-plist "$COMPONENTS" --scripts "$APP_SCRIPTS" --identifier "$PKG_IDENTIFIER" --version "$VERSION" --install-location /Applications "$PACKAGES/KSSOLVApplication.pkg"

python3 "$SCRIPTS_DIR/write_pkg_distribution.py" "$RESOURCES" "$WORK_DIR/Distribution" "$REQUIREMENTS" "$VERSION" "$REPOSITORY_DIR/LICENSE"
productbuild --distribution "$WORK_DIR/Distribution" --package-path "$PACKAGES" --resources "$RESOURCES" "$WORK_DIR/final.pkg"
mv -f "$WORK_DIR/final.pkg" "$OUTPUT_PKG"
source "$SCRIPTS_DIR/write_release_checksums.sh"
write_release_checksums "$OUTPUT_PKG"
echo "已生成原生 PKG ($DELIVERY): $OUTPUT_PKG"
echo "下一步: $SCRIPTS_DIR/sign_and_notarize_app.sh --pkg \"$OUTPUT_PKG\""
