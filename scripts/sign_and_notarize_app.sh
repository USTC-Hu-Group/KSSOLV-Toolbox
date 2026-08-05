#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
RELEASE_DIR="$SCRIPTS_DIR/../Release/StandaloneDesktopApp"
DEV_ID="Developer ID Application: Liu Yang (T3ML58STY8)"
NOTARY_PROFILE="AC_PASSWORD"
ENTITLEMENTS="$SCRIPTS_DIR/entitlements.plist"

fail() {
    echo "错误: $*" >&2
    exit 1
}

sign_macho_files() {
    local root="$1"
    local skip_matlab_launchers="${2:-false}"
    local path
    local description

    while IFS= read -r -d '' path; do
        # dSYM 中的 Mach-O 是调试信息，不是待分发的可执行代码。
        [[ "$path" == *.dSYM/* ]] && continue
        if [[ "$skip_matlab_launchers" == true ]]; then
            case "$path" in
                "$root/Contents/MacOS/applauncher"|\
                "$root/Contents/MacOS/KSSOLV_Toolbox"|\
                "$root/Contents/MacOS/prelaunch") continue ;;
            esac
        fi

        description=$(file -b "$path")
        [[ "$description" == *Mach-O* ]] || continue

        echo "签名 Mach-O: $path"
        if [[ "$description" == *executable* ]]; then
            codesign --force --options runtime --timestamp \
                --entitlements "$ENTITLEMENTS" \
                --sign "$DEV_ID" "$path"
        else
            codesign --force --options runtime --timestamp \
                --sign "$DEV_ID" "$path"
        fi
    done < <(find "$root" -type f -print0)
}

sign_matlab_app() {
    local app_path="$1"
    local launcher

    # MathWorks 要求先签 MEX/其他嵌套代码，然后依次签 applauncher、
    # 主程序和 prelaunch，最后再签 app bundle。
    sign_macho_files "$app_path" true
    for launcher in applauncher KSSOLV_Toolbox prelaunch; do
        [[ -f "$app_path/Contents/MacOS/$launcher" ]] || \
            fail "内部应用缺少启动器: $launcher"
        echo "签名 MATLAB 启动器: $launcher"
        codesign --force --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" \
            --sign "$DEV_ID" "$app_path/Contents/MacOS/$launcher"
    done

    codesign --force --options runtime --timestamp \
        --entitlements "$ENTITLEMENTS" \
        --sign "$DEV_ID" "$app_path"
}

[[ -d "$RELEASE_DIR" ]] || fail "找不到发布目录: $RELEASE_DIR"
[[ -f "$ENTITLEMENTS" ]] || fail "找不到 entitlements 文件: $ENTITLEMENTS"

cd "$RELEASE_DIR"
shopt -s nullglob
APP_CANDIDATES=(KSSOLV_Toolbox_V*.app)
shopt -u nullglob
(( ${#APP_CANDIDATES[@]} == 1 )) || \
    fail "发布目录中应当恰好有一个 KSSOLV_Toolbox_V*.app，实际找到 ${#APP_CANDIDATES[@]} 个"

APP_NAME="${APP_CANDIDATES[0]}"
FINAL_ZIP_NAME="${APP_NAME%.app}.zip"
RESOURCES_PATH="$APP_NAME/Contents/Resources"
BUNDLE_ZIP="$RESOURCES_PATH/bundle.zip"

[[ -f "$BUNDLE_ZIP" ]] || fail "找不到内部应用归档: $BUNDLE_ZIP"

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kssolv-sign.XXXXXX")
BUNDLE_DIR="$WORK_DIR/bundle"
SIGNED_BUNDLE_ZIP="$WORK_DIR/bundle.zip"
cleanup() {
    rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "=== 解包并签名内部应用 ==="
mkdir -p "$BUNDLE_DIR"
ditto -x -k "$BUNDLE_ZIP" "$BUNDLE_DIR"
chmod -R u+w "$BUNDLE_DIR"
find "$BUNDLE_DIR" \( -name '._*' -o -name '.DS_Store' \) -delete
xattr -cr "$BUNDLE_DIR"

INTERNAL_APP_PATH="$BUNDLE_DIR/application/KSSOLV_Toolbox.app"
[[ -d "$INTERNAL_APP_PATH" ]] || fail "bundle.zip 中找不到 application/KSSOLV_Toolbox.app"

# compiler.build 已为启动器写入正确的相对 LC_RPATH。不要用
# install_name_tool 追加绝对 Runtime 路径，否则会耗尽 Mach-O load command
# 的预留空间，并且会把产物绑定到某个本机 MATLAB Runtime 版本。
sign_matlab_app "$INTERNAL_APP_PATH"
codesign --verify --deep --strict --verbose=2 "$INTERNAL_APP_PATH"

ditto -c -k --norsrc "$BUNDLE_DIR" "$SIGNED_BUNDLE_ZIP"
unzip -tq "$SIGNED_BUNDLE_ZIP"

# 只有内部签名和新归档都验证成功后，才替换安装器中的 bundle.zip。
mv -f "$SIGNED_BUNDLE_ZIP" "$BUNDLE_ZIP"
# 清理旧脚本失败时可能遗留的解包目录；该目录不属于安装器产物。
rm -rf "$RESOURCES_PATH/bundle"
chmod -R u+w "$APP_NAME"
find "$APP_NAME" \( -name '._*' -o -name '.DS_Store' \) -delete
xattr -cr "$APP_NAME"

echo "=== 签名外层安装器 ==="
sign_macho_files "$APP_NAME"
codesign --force --options runtime --timestamp \
    --entitlements "$ENTITLEMENTS" \
    --sign "$DEV_ID" "$APP_NAME"
codesign --verify --deep --strict --verbose=2 "$APP_NAME"

echo "=== 提交 ZIP 公证 ==="
rm -f "$FINAL_ZIP_NAME"
ditto -c -k --keepParent "$APP_NAME" "$FINAL_ZIP_NAME"
xcrun notarytool submit "$FINAL_ZIP_NAME" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait

xcrun stapler staple "$APP_NAME"
xcrun stapler validate "$APP_NAME"
spctl --assess --type execute --verbose=2 "$APP_NAME"

echo "全部流程完成: $(pwd)/$APP_NAME"
