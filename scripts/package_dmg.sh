#!/bin/bash
set -e

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPTS_DIR"/../Release/StandaloneDesktopApp/

# 查找经 sign_and_notarize_app.sh 脚本得到的 .app 文件
APP_FULL_PATH=$(find . -name "KSSOLV_Toolbox_V*.app" -maxdepth 1 -print | head -n 1)
APP_NAME=${APP_FULL_PATH#./}
APP_BASENAME="${APP_NAME%.app}"

# 定义 DMG 输出名称和挂载时的卷标名称
DMG_NAME="${APP_BASENAME}.dmg"
VOL_NAME="${APP_BASENAME}"

# 开发者 ID 与 Keychain Profile
DEV_ID="Developer ID Application: Liu Yang (T3ML58STY8)"
NOTARY_PROFILE="AC_PASSWORD"

echo "=== 开始 DMG 打包流程 ==="
echo "目标应用: $APP_NAME"
echo "输出文件: $DMG_NAME"

# 准备构建目录
STAGING_DIR="./dmg_staging"
rm -rf "$STAGING_DIR" "$DMG_NAME"
mkdir -p "$STAGING_DIR"

# 复制已签名的 App 到构建目录
cp -R "$APP_NAME" "$STAGING_DIR/"

# 生成 DMG 文件 (使用 create-dmg)
if ! command -v create-dmg &> /dev/null; then
    brew install create-dmg
fi
create-dmg \
  --volname "$VOL_NAME" \
  --window-pos 400 280 \
  --window-size 400 300 \
  --icon-size 100 \
  --text-size 12 \
  --icon "$APP_NAME" 200 110 \
  --hide-extension "$APP_NAME" \
  "$DMG_NAME" \
  "$STAGING_DIR/"
rm -rf "$STAGING_DIR"

# 签名 DMG 文件
codesign --sign "$DEV_ID" \
  --timestamp \
  --options runtime \
  -v "$DMG_NAME"

# 公证 DMG 文件
if xcrun notarytool submit "$DMG_NAME" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait; then

  echo "DMG 公证成功"

  # 装订票据 (Staple) 到 DMG
  xcrun stapler staple "$DMG_NAME"
  
  # 验证装订结果
  spctl -a -t open --context context:primary-signature -v "$DMG_NAME"
  echo "全部完成！最终文件: $(pwd)/$DMG_NAME"
else
  echo "DMG 公证失败"
  exit 1
fi
