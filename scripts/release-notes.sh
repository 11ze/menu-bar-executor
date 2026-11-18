#!/usr/bin/env bash
# 生成发布说明：按提交前缀分组。
# 用法：scripts/release-notes.sh [起始提交]
# 不给参数时从最近的 tag 之后开始；仓库没有 tag 时取全部历史。
# 本地 release.sh 与 .github/workflows/release.yml 共用这一份逻辑。
set -euo pipefail

since="${1:-}"
if [ -z "$since" ]; then
  since=$(git describe --tags --abbrev=0 HEAD 2>/dev/null || true)
  # HEAD 本身带 tag 时（在 tag 上打包），从它的父提交开始。
  if [ -n "$since" ] && [ "$(git rev-parse "${since}^{commit}")" = "$(git rev-parse HEAD)" ]; then
    since=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || true)
  fi
fi

range="HEAD"
if [ -n "$since" ]; then
  range="${since}..HEAD"
fi

if [ "$(git rev-parse --is-shallow-repository 2>/dev/null || echo false)" = "true" ]; then
  echo "release-notes: 浅克隆里 git describe 会失败，说明可能只覆盖最近一次提交" >&2
fi

git log "$range" --no-merges --pretty=format:'%s' | awk '
{
  p = index($0, ": ")
  if (p == 0) next
  head = substr($0, 1, p - 1)
  msg = substr($0, p + 2)
  sub(/[(!].*/, "", head)
  if (head == "feat") print "Added " msg
  else if (head == "fix") print "Fixed " msg
  else if (head == "perf" || head == "style" || head == "refactor") print "Improved " msg
}'
