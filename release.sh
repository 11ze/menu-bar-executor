#!/bin/bash

# menu-bar-exector Release 打包脚本
# 用法: ./release.sh [version]

set -e

VERSION=${1:-"1.0.0"}
PROJECT_NAME="menu-bar-exector"
SCHEME="menu-bar-exector"
CONFIG="Release"

echo "📦 开始构建 ${PROJECT_NAME} v${VERSION} ..."

# 清理并构建（指定构建目录到项目目录）
echo "🔨 构建中..."
xcodebuild -project ${PROJECT_NAME}.xcodeproj \
    -scheme ${SCHEME} \
    -configuration ${CONFIG} \
    -derivedDataPath ./build \
    clean build

# 获取构建产物路径（使用指定的 derivedDataPath）
BUILD_DIR="${PROJECT_NAME}.xcodeproj/../build/Build/Products/${CONFIG}"
APP_PATH="${BUILD_DIR}/${PROJECT_NAME}.app"

if [ ! -d "${APP_PATH}" ]; then
    echo "❌ 构建失败：找不到 ${APP_PATH}"
    exit 1
fi

# 创建 Release 目录
RELEASE_DIR="Release"
rm -rf ${RELEASE_DIR}
mkdir -p ${RELEASE_DIR}

# 复制 app
echo "📂 复制应用..."
cp -R "${APP_PATH}" "./${RELEASE_DIR}/"

# 打包成 zip
echo "🗜️ 打包中..."
cd ${RELEASE_DIR}
zip -r ${PROJECT_NAME}-${VERSION}.zip ${PROJECT_NAME}.app
cd ..

echo "✅ 完成！"
echo "📁 输出文件: Release/${PROJECT_NAME}-${VERSION}.zip"
echo ""
echo "下一步："
echo "1. 访问 GitHub Releases"
echo "2. 创建新 Release (v${VERSION})"
echo "3. 上传 Release/${PROJECT_NAME}-${VERSION}.zip"
