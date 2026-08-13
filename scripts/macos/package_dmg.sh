#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$SCRIPTS_DIR/../../Release/StandaloneDesktopApp"
DEV_ID="Developer ID Application: Liu Yang (T3ML58STY8)"
NOTARY_PROFILE="AC_PASSWORD"

fail() {
    echo "错误: $*" >&2
    exit 1
}

[[ -d "$RELEASE_DIR" ]] || fail "找不到发布目录: $RELEASE_DIR"
cd "$RELEASE_DIR"

shopt -s nullglob
APP_CANDIDATES=(KSSOLV_Toolbox_V*.app)
shopt -u nullglob
(( ${#APP_CANDIDATES[@]} == 1 )) || \
    fail "发布目录中应当恰好有一个 KSSOLV_Toolbox_V*.app，实际找到 ${#APP_CANDIDATES[@]} 个"

APP_NAME="${APP_CANDIDATES[0]}"
APP_BASENAME="${APP_NAME%.app}"
DMG_NAME="${APP_BASENAME}.dmg"
VOL_NAME="$APP_BASENAME"
DMG_INSTALLER_NAME="Install KSSOLV Toolbox.app"

echo "=== 开始 DMG 打包流程 ==="
echo "目标应用: $APP_NAME"
echo "输出文件: $DMG_NAME"

codesign --verify --deep --strict --verbose=2 "$APP_NAME"
xcrun stapler validate "$APP_NAME"

if ! command -v create-dmg >/dev/null 2>&1; then
    fail "未安装 create-dmg，请先执行: brew install create-dmg"
fi

STAGING_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kssolv-dmg.XXXXXX")
cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

# 这是会下载 Runtime 并释放真正应用的一次性安装器，不是可拖入
# Applications 直接运行的应用。将它以明确的安装器名称放在只读 DMG
# 中，用户直接双击即可，安装完毕后不会在 /Applications 留下这一层。
# ditto 能保留 app bundle 的符号链接、权限和扩展属性。
ditto "$APP_NAME" "$STAGING_DIR/$DMG_INSTALLER_NAME"
codesign --verify --deep --strict --verbose=2 \
    "$STAGING_DIR/$DMG_INSTALLER_NAME"
rm -f "$DMG_NAME"

create-dmg \
    --volname "$VOL_NAME" \
    --window-pos 400 280 \
    --window-size 520 340 \
    --icon-size 112 \
    --text-size 12 \
    --icon "$DMG_INSTALLER_NAME" 260 145 \
    --hide-extension "$DMG_INSTALLER_NAME" \
    "$DMG_NAME" \
    "$STAGING_DIR"

[[ -f "$DMG_NAME" ]] || fail "create-dmg 未生成目标文件: $DMG_NAME"

echo "=== 签名并公证 DMG ==="
codesign --force --sign "$DEV_ID" --timestamp --verbose \
    "$DMG_NAME"
codesign --verify --verbose=2 "$DMG_NAME"

xcrun notarytool submit "$DMG_NAME" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

xcrun stapler staple "$DMG_NAME"
xcrun stapler validate "$DMG_NAME"
spctl --assess --type open --context context:primary-signature \
    --verbose=2 "$DMG_NAME"

echo "全部完成！最终文件: $(pwd)/$DMG_NAME"
