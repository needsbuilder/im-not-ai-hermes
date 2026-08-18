#!/usr/bin/env bash
# Humanize KR (Hermes 커뮤니티 포트) — Hermes Agent 전역 설치 스크립트
# 저장소를 클론한 뒤 `./install.sh` 한 번이면 $HERMES_HOME/skills/humanize-korean 에 연결된다.
# 기본은 심링크(저장소를 갱신하면 즉시 반영). 이 저장소는 Hermes 만 다룬다 —
# Claude Code · Codex · Gemini CLI 는 본진 epoko77-ai/im-not-ai 의 install.sh 를 쓴다.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"

MODE=symlink          # symlink | copy
FORCE=0
DRYRUN=0
TS="$(date +%Y%m%d-%H%M%S)"

print_help() {
  cat <<'H'
Usage: ./install.sh [options]

  humanize-korean 스킬을 Hermes Agent 에 전역 설치한다.
  대상: $HERMES_HOME/skills/humanize-korean (기본 ~/.hermes)

Options:
  --copy          심링크 대신 복사(저장소를 지워도 유지).
                  ※ 복사본은 uninstall.sh 가 자동 삭제하지 않음(수동 삭제).
  --force         대상에 일반 파일/디렉토리가 있어도 .bak.<ts> 백업 후 덮어씀
  --dry-run       실제 변경 없이 수행할 작업만 출력
  -h, --help      이 도움말

Env overrides: HERMES_HOME(기본 ~/.hermes)

  Hermes Skills Hub 로 바로 설치하려면 클론 없이:
    hermes skills install needsbuilder/im-not-ai-hermes/skills/humanize-korean
H
}

while [ $# -gt 0 ]; do
  case "$1" in
    --copy) MODE=copy ;;
    --force) FORCE=1 ;;
    --dry-run) DRYRUN=1 ;;
    -h|--help) print_help; exit 0 ;;
    *) echo "unknown arg: $1" >&2; print_help; exit 2 ;;
  esac
  shift
done

run() { echo "+ $*"; [ "$DRYRUN" = 1 ] || "$@"; }

# rc: 0=대상 비었음(설치 진행) / 1=이미 우리 심링크(스킵) / 2=충돌(거부)
prepare_target() {
  local dest="$1" src="$2"
  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$src" ]; then
      echo "ok (already linked): $dest"; return 1
    fi
    run mv "$dest" "$dest.bak.$TS"
  elif [ -e "$dest" ]; then
    if [ "$FORCE" != 1 ]; then
      echo "refuse: $dest 가 이미 있음 (--force 로 백업 후 덮어쓰기 또는 --copy)"; return 2
    fi
    run mv "$dest" "$dest.bak.$TS"
  fi
  return 0
}

install_one() {
  local src="$1" dest="$2"
  run mkdir -p "$(dirname "$dest")"
  local rc=0
  prepare_target "$dest" "$src" || rc=$?
  [ "$rc" = 1 ] && return 0
  [ "$rc" = 2 ] && return 1
  case "$MODE" in
    symlink) run ln -s "$src" "$dest" ;;
    copy)    run cp -RL "$src" "$dest" ;;
  esac
  echo "installed: $dest"
}

# CLI 명령 또는 홈 디렉터리(앱만 설치한 사용자)로 대상 감지
has_hermes_target() { command -v hermes >/dev/null 2>&1 || [ -d "$HERMES_HOME" ]; }

if has_hermes_target; then
  echo "== Hermes Agent =="
  run mkdir -p "$HERMES_HOME/skills"
  install_one "$REPO/skills/humanize-korean" "$HERMES_HOME/skills/humanize-korean"
else
  echo "== Hermes Agent: 건너뜀 (hermes 또는 $HERMES_HOME 미감지) =="
  echo "   Hermes 를 설치했는데도 감지되지 않으면 HERMES_HOME 을 지정하라:"
  echo "   HERMES_HOME=/path/to/.hermes ./install.sh"
  exit 0
fi

echo ""
echo "완료 (mode=$MODE)."
echo "  Hermes: 새 세션에서 /humanize-korean"
echo "  제거: ./uninstall.sh"
exit 0
