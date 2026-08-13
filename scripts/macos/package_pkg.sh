#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_DIR="$SCRIPTS_DIR/../.."
RELEASE_DIR="$REPOSITORY_DIR/Release/StandaloneDesktopApp"
PKG_ASSETS_DIR="$SCRIPTS_DIR/pkg"
PKG_IDENTIFIER="com.hanhai.kssolv-toolbox"
RUNTIME_RELEASE="${MATLAB_RUNTIME_RELEASE:-R2026b}"
INSTALLER_IDENTITY="${PKG_SIGN_IDENTITY:-Developer ID Installer: Liu Yang (T3ML58STY8)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_PASSWORD}"

fail() {
    echo "错误: $*" >&2
    exit 1
}

VERSION=$(sed -nE \
    "s/^[[:space:]]*Version[[:space:]]+string[[:space:]]*=[[:space:]]*'([^']+)'.*/\1/p" \
    "$REPOSITORY_DIR/KSSOLV_Toolbox.m" | head -n 1)
[[ -n "$VERSION" ]] || fail "无法从 KSSOLV_Toolbox.m 读取版本号"

INSTALLER_APP="$RELEASE_DIR/KSSOLV_Toolbox_V$VERSION.app"
BUNDLE_ZIP="$INSTALLER_APP/Contents/Resources/bundle.zip"
OUTPUT_PKG="${PKG_OUTPUT_PATH:-$RELEASE_DIR/KSSOLV_Toolbox_V$VERSION.pkg}"
[[ -f "$BUNDLE_ZIP" ]] || \
    fail "找不到已生成的安装器载荷: $BUNDLE_ZIP"

for asset in \
    "$PKG_ASSETS_DIR/com.gleamoe.kssolv.prewarm.plist" \
    "$PKG_ASSETS_DIR/prewarm.sh" \
    "$PKG_ASSETS_DIR/postinstall"; do
    [[ -f "$asset" ]] || fail "找不到 PKG 资源: $asset"
done

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kssolv-pkg.XXXXXX")
EXTRACT_DIR="$WORK_DIR/extracted"
PAYLOAD_ROOT="$WORK_DIR/root"
PACKAGE_SCRIPTS="$WORK_DIR/scripts"
UNSIGNED_PKG="$WORK_DIR/KSSOLV_Toolbox.pkg"
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$EXTRACT_DIR" "$PACKAGE_SCRIPTS"
ditto -x -k "$BUNDLE_ZIP" "$EXTRACT_DIR"
[[ -d "$EXTRACT_DIR/application/KSSOLV_Toolbox.app" ]] || \
    fail "bundle.zip 中找不到 application/KSSOLV_Toolbox.app"
[[ -x "$EXTRACT_DIR/application/run_KSSOLV_Toolbox.sh" ]] || \
    fail "bundle.zip 中找不到可执行的 Runtime 启动脚本"

# PKG 沿用 MathWorks 安装器的安装目录，升级会覆盖同一路径下的旧版本。
mkdir -p "$PAYLOAD_ROOT/Applications/KSSOLV_Toolbox"
ditto "$EXTRACT_DIR/application" \
    "$PAYLOAD_ROOT/Applications/KSSOLV_Toolbox/application"
if [[ -f "$EXTRACT_DIR/icon_48.png" ]]; then
    ditto "$EXTRACT_DIR/icon_48.png" \
        "$PAYLOAD_ROOT/Applications/KSSOLV_Toolbox/icon_48.png"
fi

SUPPORT_DIR="$PAYLOAD_ROOT/Library/Application Support/KSSOLV Toolbox"
LAUNCH_AGENTS_DIR="$PAYLOAD_ROOT/Library/LaunchAgents"
mkdir -p "$SUPPORT_DIR" "$LAUNCH_AGENTS_DIR"
ditto "$PKG_ASSETS_DIR/prewarm.sh" "$SUPPORT_DIR/prewarm.sh"
/usr/bin/sed -i '' \
    "s/@MATLAB_RUNTIME_RELEASE@/$RUNTIME_RELEASE/g" \
    "$SUPPORT_DIR/prewarm.sh"
chmod 0755 "$SUPPORT_DIR/prewarm.sh"
ditto "$PKG_ASSETS_DIR/com.gleamoe.kssolv.prewarm.plist" \
    "$LAUNCH_AGENTS_DIR/com.gleamoe.kssolv.prewarm.plist"
chmod 0644 "$LAUNCH_AGENTS_DIR/com.gleamoe.kssolv.prewarm.plist"

# ditto 解包带资源叉的 zip 时可能生成 AppleDouble 辅助文件。它们不属于
# 安装载荷，并且会让升级后的目录出现大量不可见的 ._* 文件。
find "$PAYLOAD_ROOT" \( -name '._*' -o -name '.DS_Store' \) -delete
xattr -cr "$PAYLOAD_ROOT"

ditto "$PKG_ASSETS_DIR/postinstall" "$PACKAGE_SCRIPTS/postinstall"
chmod 0755 "$PACKAGE_SCRIPTS/postinstall"

plutil -lint \
    "$LAUNCH_AGENTS_DIR/com.gleamoe.kssolv.prewarm.plist"
codesign --verify --deep --strict --verbose=2 \
    "$PAYLOAD_ROOT/Applications/KSSOLV_Toolbox/application/KSSOLV_Toolbox.app"

pkgbuild \
    --root "$PAYLOAD_ROOT" \
    --scripts "$PACKAGE_SCRIPTS" \
    --identifier "$PKG_IDENTIFIER" \
    --version "$VERSION" \
    --install-location / \
    "$UNSIGNED_PKG"

rm -f "$OUTPUT_PKG"
if [[ "${KSSOLV_SKIP_SIGNING:-0}" == "1" ]]; then
    mv "$UNSIGNED_PKG" "$OUTPUT_PKG"
    echo "已生成未签名测试 PKG: $OUTPUT_PKG"
    exit 0
fi

security find-identity -v -p basic | grep -Fq "$INSTALLER_IDENTITY" || \
    fail "钥匙串中找不到 PKG 签名证书: $INSTALLER_IDENTITY"
productsign --sign "$INSTALLER_IDENTITY" \
    "$UNSIGNED_PKG" "$OUTPUT_PKG"
pkgutil --check-signature "$OUTPUT_PKG"

xcrun notarytool submit "$OUTPUT_PKG" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait
xcrun stapler staple "$OUTPUT_PKG"
xcrun stapler validate "$OUTPUT_PKG"
spctl --assess --type install --verbose=2 "$OUTPUT_PKG"

echo "全部完成: $OUTPUT_PKG"
