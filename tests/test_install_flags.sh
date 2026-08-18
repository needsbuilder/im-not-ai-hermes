#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_HOME="$(mktemp -d)"
trap 'rm -rf "$TMP_HOME"' EXIT

MINIMAL_PATH="/usr/bin:/bin:/usr/sbin:/sbin"
SRC="$ROOT/skills/humanize-korean"

run_installer() {
  env -i HOME="$TMP_HOME" PATH="$MINIMAL_PATH" bash "$ROOT/install.sh" "$@" --dry-run
}

assert_contains() {
  local output="$1" expected="$2"
  if [[ "$output" != *"$expected"* ]]; then
    printf 'expected output to contain: %s\n' "$expected" >&2
    printf 'actual output:\n%s\n' "$output" >&2
    exit 1
  fi
}

assert_not_contains() {
  local output="$1" unexpected="$2"
  if [[ "$output" == *"$unexpected"* ]]; then
    printf 'expected output not to contain: %s\n' "$unexpected" >&2
    printf 'actual output:\n%s\n' "$output" >&2
    exit 1
  fi
}

# hermes 도, ~/.hermes 도 없으면 아무것도 설치하지 않는다.
without_target_output="$(run_installer)"
assert_contains "$without_target_output" "== Hermes Agent: 건너뜀"
assert_not_contains "$without_target_output" "+ ln -s $SRC"

# 앱만 설치한 사용자(~/.hermes 만 존재)도 감지한다.
mkdir -p "$TMP_HOME/.hermes"
detected_output="$(run_installer)"
assert_contains "$detected_output" "== Hermes Agent =="
assert_contains "$detected_output" "+ ln -s $SRC $TMP_HOME/.hermes/skills/humanize-korean"
assert_not_contains "$detected_output" "Hermes Agent: 건너뜀"

# --copy 는 심링크 대신 복사한다.
copy_output="$(run_installer --copy)"
assert_contains "$copy_output" "+ cp -RL $SRC $TMP_HOME/.hermes/skills/humanize-korean"
assert_not_contains "$copy_output" "+ ln -s $SRC"
rm -rf "$TMP_HOME/.hermes"

# HERMES_HOME 오버라이드를 존중한다.
CUSTOM_HOME="$TMP_HOME/custom-hermes"
mkdir -p "$CUSTOM_HOME"
custom_output="$(env -i HOME="$TMP_HOME" PATH="$MINIMAL_PATH" HERMES_HOME="$CUSTOM_HOME" \
  bash "$ROOT/install.sh" --dry-run)"
assert_contains "$custom_output" "+ ln -s $SRC $CUSTOM_HOME/skills/humanize-korean"

# 대상에 남의 파일이 있으면 --force 없이는 거부한다.
mkdir -p "$TMP_HOME/.hermes/skills"
: > "$TMP_HOME/.hermes/skills/humanize-korean"
set +e
refuse_output="$(run_installer 2>&1)"
refuse_rc=$?
set -e
[ "$refuse_rc" -ne 0 ] || { echo "installer must fail when the target is occupied" >&2; exit 1; }
assert_contains "$refuse_output" "refuse: $TMP_HOME/.hermes/skills/humanize-korean 가 이미 있음"
assert_not_contains "$refuse_output" "+ ln -s $SRC"

force_output="$(run_installer --force)"
assert_contains "$force_output" "+ mv $TMP_HOME/.hermes/skills/humanize-korean"
assert_contains "$force_output" "+ ln -s $SRC $TMP_HOME/.hermes/skills/humanize-korean"
rm -rf "$TMP_HOME/.hermes"

# 알 수 없는 인자는 조용히 무시하지 않는다.
if run_installer --claude-only >/dev/null 2>&1; then
  echo "installer accepted an unknown flag" >&2
  exit 1
fi

# --dry-run 은 실제로 아무것도 만들지 않는다.
[ ! -e "$TMP_HOME/.hermes" ] || { echo "dry-run created files" >&2; exit 1; }

echo "install flag tests passed"
