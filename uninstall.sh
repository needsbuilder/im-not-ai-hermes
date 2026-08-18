#!/usr/bin/env bash
# Humanize KR (Hermes 커뮤니티 포트) — 전역 설치 제거 스크립트
# install.sh 가 만든 "이 저장소를 가리키는 심링크"만 제거한다. 사용자가 직접 둔 파일이나
# 다른 곳을 가리키는 링크, .bak.* 백업은 건드리지 않는다. (--copy 설치본은 자동 삭제 대상 아님)
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
DRYRUN=0

case "${1:-}" in
  --dry-run) DRYRUN=1 ;;
  -h|--help) echo "Usage: ./uninstall.sh [--dry-run]"; exit 0 ;;
  "") ;;
  *) echo "unknown arg: $1" >&2; exit 2 ;;
esac

remove_if_ours() {
  local dest="$1" src="$2"
  if [ -L "$dest" ] && [ "$(readlink "$dest")" = "$src" ]; then
    echo "+ rm $dest"; [ "$DRYRUN" = 1 ] || rm "$dest"
  elif [ -e "$dest" ]; then
    echo "skip (우리 것 아님): $dest"
  fi
}

remove_if_ours "$HERMES_HOME/skills/humanize-korean" "$REPO/skills/humanize-korean"

echo "제거 완료. (.bak.* 백업·--copy 설치본은 보존)"
