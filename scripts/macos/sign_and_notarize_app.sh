#!/bin/bash
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
REPOSITORY_DIR="$SCRIPTS_DIR/../.."
RELEASE_DIR="$REPOSITORY_DIR/Release/StandaloneDesktopApp"
DEV_ID="${APP_SIGN_IDENTITY:-Developer ID Application: Liu Yang (T3ML58STY8)}"
INSTALLER_IDENTITY="${PKG_SIGN_IDENTITY:-Developer ID Installer: Liu Yang (T3ML58STY8)}"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_PASSWORD}"
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
    local runtime_app="$app_path/Contents/Helpers/KSSOLV_Toolbox.app"
    if [[ -d "$runtime_app" ]]; then
        # Sign nested MATLAB code first; never rewrite it after sealing its bundle.
        sign_matlab_app "$runtime_app"
        local window_app="$app_path/Contents/Helpers/KSSOLVWindow.app"
        [[ -d "$window_app" ]] || fail '缺少私有品牌窗口应用'
        sign_macho_files "$window_app"
        codesign --force --options runtime --timestamp \
            --entitlements "$ENTITLEMENTS" \
            --identifier com.pwdft.kssolv.window \
            --sign "$DEV_ID" "$window_app"
        # The scoped Dock bridge is outer-bundle code, outside the Compiler copy.
        if [[ -d "$app_path/Contents/Frameworks" ]]; then
            sign_macho_files "$app_path/Contents/Frameworks"
        fi
        codesign --force --options runtime --timestamp --sign "$DEV_ID" \
            "$app_path/Contents/MacOS/KSSOLV_Toolbox"
        codesign --force --options runtime --timestamp --sign "$DEV_ID" "$app_path"
        return
    fi
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

sign_and_notarize_pkg() {
    local input_pkg="$1"
    local package_info identifier version install_location install_kbytes number_of_files

    [[ -f "$input_pkg" && "$input_pkg" == *.pkg ]] || fail "找不到 PKG: $input_pkg"
    input_pkg="$(cd "$(dirname "$input_pkg")" && pwd)/$(basename "$input_pkg")"
    [[ -f "$ENTITLEMENTS" ]] || fail "找不到 entitlements 文件: $ENTITLEMENTS"

    WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/kssolv-sign-pkg.XXXXXX")
    trap 'rm -rf "$WORK_DIR"' EXIT
    # 保留原包的 PackageInfo 和 Scripts，避免签名时丢失 bundle 预热步骤、
    # 1200 秒超时、固定安装位置及 Runtime 版本。只重新生成签名后的载荷和 BOM。
    pkgutil --expand "$input_pkg" "$WORK_DIR/original"
    pkgutil --expand-full "$input_pkg" "$WORK_DIR/expanded"
    package_info="$WORK_DIR/original/PackageInfo"
    [[ -f "$package_info" && -d "$WORK_DIR/expanded/Payload" ]] || \
        fail "只支持 package_pkg.sh 生成的组件 PKG"
    identifier=$(/usr/bin/xmllint --xpath 'string(/pkg-info/@identifier)' "$package_info")
    version=$(/usr/bin/xmllint --xpath 'string(/pkg-info/@version)' "$package_info")
    install_location=$(/usr/bin/xmllint --xpath 'string(/pkg-info/@install-location)' "$package_info")
    [[ "$identifier" == "com.pwdft.kssolv" && -n "$version" && "$install_location" == "/" ]] || \
        fail "PKG 标识、版本或安装位置不符合 KSSOLV 安装包要求"

    local app_path="$WORK_DIR/expanded/Payload/Applications/KSSOLV_Toolbox/application/KSSOLV Toolbox.app"
    [[ -d "$app_path" ]] || fail "PKG 中找不到 KSSOLV Toolbox.app"
    chmod -R u+w "$app_path"
    xattr -cr "$app_path"
    sign_matlab_app "$app_path"
    codesign --verify --deep --strict --verbose=2 "$app_path"

    pkgbuild --root "$WORK_DIR/expanded/Payload" \
        --identifier "$identifier" --version "$version" \
        --install-location "$install_location" "$WORK_DIR/payload.pkg"
    pkgutil --expand "$WORK_DIR/payload.pkg" "$WORK_DIR/rebuilt"
    cp "$WORK_DIR/rebuilt/Payload" "$WORK_DIR/original/Payload"
    cp "$WORK_DIR/rebuilt/Bom" "$WORK_DIR/original/Bom"
    install_kbytes=$(/usr/bin/xmllint --xpath 'string(/pkg-info/payload/@installKBytes)' "$WORK_DIR/rebuilt/PackageInfo")
    number_of_files=$(/usr/bin/xmllint --xpath 'string(/pkg-info/payload/@numberOfFiles)' "$WORK_DIR/rebuilt/PackageInfo")
    [[ "$install_kbytes" =~ ^[0-9]+$ && "$number_of_files" =~ ^[0-9]+$ ]] || \
        fail "无法读取签名后载荷的大小和文件数量"
    /usr/bin/sed -E \
        -e "/<payload /s/installKBytes=\"[^\"]*\"/installKBytes=\"$install_kbytes\"/" \
        -e "/<payload /s/numberOfFiles=\"[^\"]*\"/numberOfFiles=\"$number_of_files\"/" \
        "$package_info" > "$WORK_DIR/PackageInfo"
    /usr/bin/xmllint --noout "$WORK_DIR/PackageInfo"
    mv "$WORK_DIR/PackageInfo" "$package_info"
    pkgutil --flatten "$WORK_DIR/original" "$WORK_DIR/unsigned.pkg"

    mkdir "$WORK_DIR/signed"
    local signed_pkg="$WORK_DIR/signed/$(basename "$input_pkg")"
    productsign --sign "$INSTALLER_IDENTITY" "$WORK_DIR/unsigned.pkg" "$signed_pkg"
    pkgutil --check-signature "$signed_pkg"
    local submit_args=(--keychain-profile "$NOTARY_PROFILE" --wait --output-format plist)
    if [[ "${NOTARY_S3_ACCELERATION:-1}" == "0" ]]; then
        submit_args+=(--no-s3-acceleration)
    fi
    xcrun notarytool submit "$signed_pkg" "${submit_args[@]}" > "$WORK_DIR/notary.plist"
    cat "$WORK_DIR/notary.plist"
    [[ "$(plutil -extract status raw -o - "$WORK_DIR/notary.plist")" == "Accepted" ]] || \
        fail "PKG 公证未通过"
    xcrun stapler staple "$signed_pkg"
    xcrun stapler validate "$signed_pkg"
    spctl --assess --type install --verbose=2 "$signed_pkg"
    # 全部验证成功后才替换原包；失败时保留可重试的未签名产物。
    mv -f "$signed_pkg" "$input_pkg"
    echo "PKG 签名和公证完成: $input_pkg"
}

MODE="--pkg"
if [[ $# -gt 0 ]]; then
    MODE="$1"
    shift
fi
case "$MODE" in
    --sign-app)
        [[ $# -eq 1 && -d "$1" ]] || fail "用法: $0 --sign-app 应用.app"
        APP_TO_SIGN="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
        chmod -R u+w "$APP_TO_SIGN"
        xattr -cr "$APP_TO_SIGN"
        sign_matlab_app "$APP_TO_SIGN"
        codesign --verify --deep --strict --verbose=2 "$APP_TO_SIGN"
        exit 0
        ;;
    --pkg)
        [[ $# -le 1 ]] || fail "用法: $0 [--pkg [安装包.pkg]]"
        if [[ $# -eq 1 ]]; then
            INPUT_PKG="$1"
        elif [[ -n "${PKG_OUTPUT_PATH:-}" ]]; then
            INPUT_PKG="$PKG_OUTPUT_PATH"
        else
            VERSION=$(sed -nE \
                "s/^[[:space:]]*Version[[:space:]]+string[[:space:]]*=[[:space:]]*'([^']+)'.*/\1/p" \
                "$REPOSITORY_DIR/KSSOLV_Toolbox.m" | head -n 1)
            [[ -n "$VERSION" ]] || fail "无法从 KSSOLV_Toolbox.m 读取版本号"
            INPUT_PKG="$RELEASE_DIR/KSSOLV_Toolbox_V$VERSION.pkg"
        fi
        sign_and_notarize_pkg "$INPUT_PKG"
        exit 0
        ;;
    --dmg)
        [[ $# -eq 0 ]] || fail "用法: $0 --dmg"
        ;;
    *)
        fail "用法: $0 [--pkg [安装包.pkg] | --dmg]"
        ;;
esac

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
