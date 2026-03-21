#!/bin/bash
# 自动更新 CFBundleVersion 为当前日期+序号
# 用法: ./Scripts/update_build_number.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
PLIST="$PROJECT_DIR/Resources/Info.plist"

if [ ! -f "$PLIST" ]; then
    echo "Error: Info.plist not found at $PLIST"
    exit 1
fi

TODAY=$(date +"%Y%m%d")
CURRENT_BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST" 2>/dev/null || echo "0")

# 提取今天的序号
if [[ "$CURRENT_BUILD" == "$TODAY"* ]]; then
    SEQ=${CURRENT_BUILD:8}
    SEQ=$((10#$SEQ + 1))
else
    SEQ=1
fi

NEW_BUILD="${TODAY}$(printf '%02d' $SEQ)"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $NEW_BUILD" "$PLIST"
echo "Build number updated to $NEW_BUILD"