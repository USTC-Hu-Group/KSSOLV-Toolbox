#!/bin/bash
set -e

cd ../Release/StandaloneDesktopApp/

# 获取 .app 文件名，并设置相关变量
APP_NAME=$(find . -name "KSSOLV_Toolbox_V*.app" -maxdepth 1 -print | head -n 1)
APP_NAME=${APP_NAME#./}
FINAL_ZIP_NAME="${APP_NAME%.app}.zip"
RESOURCES_PATH="${APP_NAME}/Contents/Resources"
DEV_ID="Developer ID Application: Liu Yang (T3ML58STY8)"

# 解压缩 bundle.zip，并清理 ._ 文件
cd "$RESOURCES_PATH"
if [ -f "bundle.zip" ]; then
    mkdir -p bundle
    unzip -o -q bundle.zip -d bundle/
    find . \( -name '._*' -or -name '.DS_Store' \) -delete
fi

# 签名 bundle 文件夹内 .app 文件夹下的动态库文件
INTERNAL_APP_PATH="bundle/application/KSSOLV_Toolbox.app"
find "$INTERNAL_APP_PATH" -type f \( -name "*.dylib" -o -name "*.so" -o -name "*.mexmaca64" \) \
    -exec codesign --force --options runtime --timestamp -s "$DEV_ID" -v {} +

# 签名 bundle 文件夹里的 .app 文件夹
if [ -d "$INTERNAL_APP_PATH" ]; then
    codesign --deep --force --options runtime --timestamp \
      -s "$DEV_ID" \
      -v "$INTERNAL_APP_PATH"
fi

# 重新打包为 bundle.zip
rm bundle.zip
zip -r -q bundle.zip bundle
rm -rf bundle

# 返回到 StandaloneDesktopApp 目录，签名整个安装包
cd ../../..
codesign --deep --force --options runtime --timestamp \
  --sign "$DEV_ID" \
  "$APP_NAME"

# 将安装包打包为 .zip 文件
ditto -c -k --keepParent "$APP_NAME" "$FINAL_ZIP_NAME"

# 上传 .zip 文件进行公证
xcrun notarytool submit "$FINAL_ZIP_NAME" \
  --keychain-profile "AC_PASSWORD" \
  --wait
  
# 将公证票据附加到 app 文件
rm "$FINAL_ZIP_NAME"
xcrun stapler staple "$APP_NAME"
xcrun stapler validate "$APP_NAME"

echo "--- 全部流程完成！ ---"
