#!/usr/bin/env bash
# 드리프트 검사가 실제로 드리프트를 잡는지 검사한다.
# "검사가 있다"는 것만으로는 부족하다 — 망가진 검사는 통과하는 검사와 구별되지 않는다.
# 본진을 실제로 가져오므로 네트워크가 필요하다. 네트워크가 없으면 통과가 아니라 skip 한다.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECKER="$ROOT/scripts/check_upstream_drift.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1. 현재 사본은 핀에 대해 일치해야 한다.
set +e
python3 "$CHECKER" >"$TMP/clean.log" 2>&1
clean_rc=$?
set -e

if [ "$clean_rc" -eq 3 ]; then
  echo "skip: 본진을 가져오지 못했다(네트워크). 드리프트 검사는 CI 에서 검증된다."
  cat "$TMP/clean.log"
  exit 0
fi
if [ "$clean_rc" -ne 0 ]; then
  echo "번들 사본이 본진 핀과 일치하지 않는다" >&2
  cat "$TMP/clean.log" >&2
  exit 1
fi

# 2. 사본을 한 글자 바꾸면 검사가 깨져야 한다.
WORK="$TMP/repo"
mkdir -p "$WORK/scripts" "$WORK/skills/humanize-korean/references"
cp "$CHECKER" "$WORK/scripts/"
cp "$ROOT/UPSTREAM" "$WORK/"
cp "$ROOT/skills/humanize-korean/references/quick-rules.md" \
   "$WORK/skills/humanize-korean/references/quick-rules.md"

python3 - "$WORK/skills/humanize-korean/references/quick-rules.md" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
content = path.read_text(encoding="utf-8")
start = content.index("## A. ")
end = content.index("## 자체검증", start)
body = content[start:end]
mutated = body.replace("→", "->", 1)
if mutated == body:
    raise SystemExit("fixture 를 변형하지 못했다 — 룰북 포맷을 확인하라")
path.write_text(content[:start] + mutated + content[end:], encoding="utf-8")
PY

set +e
python3 "$WORK/scripts/check_upstream_drift.py" >"$TMP/dirty.log" 2>&1
dirty_rc=$?
set -e

if [ "$dirty_rc" -ne 1 ]; then
  echo "드리프트 검사가 변형된 사본을 통과시켰다 (exit=$dirty_rc)" >&2
  cat "$TMP/dirty.log" >&2
  exit 1
fi
grep -q "어긋났다" "$TMP/dirty.log" || {
  echo "드리프트 실패 메시지가 원인을 설명하지 않는다" >&2
  cat "$TMP/dirty.log" >&2
  exit 1
}

# 3. 룰북 구조 자체가 사라지면 드리프트(1)가 아니라 구조 이상(2)으로 구분해야 한다.
printf 'no markers here\n' > "$WORK/skills/humanize-korean/references/quick-rules.md"
set +e
python3 "$WORK/scripts/check_upstream_drift.py" >"$TMP/broken.log" 2>&1
broken_rc=$?
set -e
[ "$broken_rc" -eq 2 ] || {
  echo "구조 이상을 코드 2 로 구분하지 못했다 (exit=$broken_rc)" >&2
  cat "$TMP/broken.log" >&2
  exit 1
}

echo "drift check tests passed"
