#!/bin/bash

# menu-bar-executor Release 打包脚本
# 用法: ./release.sh <version>
# 示例: ./release.sh 1.1.0

set -e

VERSION=${1:-""}
PROJECT_NAME="menu-bar-executor"
SCHEME="MenuBarExecutor"
APP_NAME="MenuBarExecutor"
CONFIG="Release"
PLIST="Resources/Info.plist"

# 检查版本号参数
if [ -z "$VERSION" ]; then
    echo "❌ 请提供版本号"
    echo "用法: ./release.sh <version>"
    echo "示例: ./release.sh 1.1.0"
    exit 1
fi

# 更新 Info.plist 版本号
echo "📝 更新版本号到 ${VERSION}..."
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "$PLIST"

# 更新构建号
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Scripts"
if [ -f "$SCRIPTS_DIR/update_build_number.sh" ]; then
    "$SCRIPTS_DIR/update_build_number.sh"
else
    # 如果脚本不存在，使用日期格式
    BUILD_NUMBER=$(date +"%Y%m%d01")
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "$PLIST"
    echo "Build number updated to ${BUILD_NUMBER}"
fi

# 拉取最新 tag，确保版本信息最新
echo "🔄 拉取最新标签..."
git fetch --tags

# 生成发布说明
generate_release_notes() {
    local last_tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null) || last_tag="0.0.0"

    # 使用 awk 单次调用解析提交信息，替代多次 sed
    git log ${last_tag}..HEAD --pretty=format:"%s" 2>/dev/null | awk -F': ' '{
        split($1, a, "(")
        type = a[1]
        msg = $2
        if (type == "feat") print "Added " msg
        else if (type == "fix") print "Fixed " msg
        else if (type == "style" || type == "perf") print "Improved " msg
    }'
}

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
APP_PATH="${BUILD_DIR}/${APP_NAME}.app"

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
zip -r ${APP_NAME}-${VERSION}.zip ${APP_NAME}.app
cd ..

# 生成并保存发布说明
echo ""
echo "📝 生成发布说明..."
RELEASE_NOTES=$(generate_release_notes)
echo "${RELEASE_NOTES}"
echo "${RELEASE_NOTES}" > "./${RELEASE_DIR}/RELEASE_NOTES.md"

echo ""
echo "✅ 完成！"
echo "📁 输出文件:"
echo "   - Release/${APP_NAME}-${VERSION}.zip"
echo "   - Release/RELEASE_NOTES.md"
echo ""
echo "下一步："
echo "1. 提交版本更新："
echo "   git add Resources/Info.plist && git commit -m \"chore: bump version to ${VERSION}\""
echo "2. 创建标签："
echo "   git tag v${VERSION}"
echo "3. 推送："
echo "   git push && git push --tags"
echo "4. 访问 GitHub Releases 创建新 Release"
echo "5. 上传 Release/${APP_NAME}-${VERSION}.zip"
echo "6. 复制 Release/RELEASE_NOTES.md 内容到 Release Description"
