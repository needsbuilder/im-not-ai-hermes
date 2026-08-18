#!/usr/bin/env python3
"""번들 룰북 사본이 본진(upstream)과 어긋났는지 검사한다.

이 저장소는 본진의 룰북을 **사본으로** 배포한다. Hermes Skills Hub 가 번들 안의
심볼릭 링크를 거부하기 때문에 실파일이어야 하고, 실파일 사본은 조용히 낡는다.
그 "조용한 낡음"을 막는 것이 이 스크립트의 유일한 목적이다 — 어긋나면 CI 가 깨진다.

비교 대상은 룰북의 A~J 패턴 본문뿐이다. 헤더/푸터는 런타임별 문구 차이가 있을 수
있어 제외한다. 본진의 `scripts/build_quick_rules.py` 가 생성하는 구조와 같은 경계다.

종료 코드:
    0  일치
    1  드리프트 — 사본을 갱신해야 한다
    2  구조 이상(경계 마커 없음 등) — 룰북 포맷 자체가 바뀌었을 수 있다
    3  본진을 가져오지 못함(네트워크·핀 오류) — 조용히 통과시키지 않는다
"""

from __future__ import annotations

import argparse
import difflib
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PIN_FILE = ROOT / "UPSTREAM"

START_MARKER = "## A. "
END_MARKER = "## 자체검증"
RAW_BASE = "https://raw.githubusercontent.com"
TIMEOUT_SECONDS = 30


class DriftError(Exception):
    """드리프트가 아니라 검사 자체가 성립하지 않은 경우."""

    def __init__(self, message: str, code: int) -> None:
        super().__init__(message)
        self.code = code


def read_pin() -> dict[str, str]:
    pin: dict[str, str] = {}
    for line in PIN_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, _, value = line.partition("=")
        pin[key.strip()] = value.strip()

    missing = {"repo", "ref", "canonical_rules", "bundled_rules"} - pin.keys()
    if missing:
        raise DriftError(f"UPSTREAM 핀에 항목이 없다: {sorted(missing)}", 2)
    return pin


def pattern_body(text: str, source: str) -> str:
    """룰북에서 A~J 패턴 본문만 잘라낸다."""
    start = text.find(START_MARKER)
    if start == -1:
        raise DriftError(f"{source}: 시작 마커 {START_MARKER!r} 없음 — 룰북 구조가 바뀌었다", 2)
    end = text.find(END_MARKER, start)
    if end == -1:
        raise DriftError(f"{source}: 종료 마커 {END_MARKER!r} 없음 — 룰북 구조가 바뀌었다", 2)
    return text[start:end].rstrip()


def fetch_canonical(repo: str, ref: str, path: str) -> str:
    url = f"{RAW_BASE}/{repo}/{ref}/{path}"
    request = urllib.request.Request(url, headers={"User-Agent": "im-not-ai-hermes-drift-check"})
    try:
        with urllib.request.urlopen(request, timeout=TIMEOUT_SECONDS) as response:
            return response.read().decode("utf-8")
    except urllib.error.HTTPError as error:
        raise DriftError(f"본진 룰북을 가져오지 못했다 (HTTP {error.code}): {url}", 3) from error
    except (urllib.error.URLError, TimeoutError, OSError) as error:
        raise DriftError(f"본진 룰북을 가져오지 못했다: {url} — {error}", 3) from error


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="번들 룰북 사본의 본진 드리프트 검사")
    parser.add_argument(
        "--ref",
        help="UPSTREAM 핀 대신 검사할 본진 ref (예: main). 주간 조기경보용.",
    )
    args = parser.parse_args(argv)

    try:
        pin = read_pin()
        ref = args.ref or pin["ref"]

        bundled_path = ROOT / pin["bundled_rules"]
        if not bundled_path.is_file():
            raise DriftError(f"번들 룰북이 없다: {pin['bundled_rules']}", 2)

        bundled = pattern_body(bundled_path.read_text(encoding="utf-8"), "번들 사본")
        canonical = pattern_body(
            fetch_canonical(pin["repo"], ref, pin["canonical_rules"]),
            f"본진 {pin['repo']}@{ref}",
        )
    except DriftError as error:
        print(f"error: {error}", file=sys.stderr)
        return error.code

    if bundled == canonical:
        rule_count = sum(1 for line in bundled.splitlines() if line.startswith("- **"))
        print(f"룰북 사본 일치 — {pin['repo']}@{ref} · 패턴 {rule_count}건")
        return 0

    print(
        f"error: 룰북 사본이 본진({pin['repo']}@{ref})과 어긋났다.\n"
        f"  {pin['canonical_rules']} 의 A~J 본문을 {pin['bundled_rules']} 로 다시 가져온 뒤,\n"
        f"  변경이 SKILL.md 절차와 충돌하지 않는지 확인하고 UPSTREAM 핀의 ref 를 올려라.",
        file=sys.stderr,
    )
    diff = difflib.unified_diff(
        canonical.splitlines(),
        bundled.splitlines(),
        fromfile=f"upstream/{pin['canonical_rules']}",
        tofile=pin["bundled_rules"],
        lineterm="",
    )
    for line in diff:
        print(line, file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
