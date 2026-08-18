# im-not-ai — Hermes Agent 포트

한글 초안의 "AI 티"를 지우는 [im-not-ai](https://github.com/epoko77-ai/im-not-ai) 의 **Hermes Agent 커뮤니티 포트**입니다. 본진에 없는 기능은 없고, 본진의 룰북을 Hermes 가 읽을 수 있는 형태로 옮겨 담았습니다.

> **공식 지원이 아닙니다.** 본진은 라이브로 검증할 수 있는 런타임(Claude Code · Codex · Gemini CLI)에만 "공식 지원"을 붙이는 정책입니다. Hermes 는 그 범위 밖이라 이 저장소가 따로 유지합니다. 룰북의 단일 진실 원천(SSOT)은 여전히 본진이고, 이 저장소는 사본이 본진과 어긋나면 CI 가 깨지도록 묶어 두었습니다.

## 설치

**Hermes Skills Hub 에서 바로 (권장)**

```bash
hermes skills install needsbuilder/im-not-ai-hermes/skills/humanize-korean
```

**클론해서 심링크로**

```bash
git clone https://github.com/needsbuilder/im-not-ai-hermes.git
cd im-not-ai-hermes
./install.sh            # $HERMES_HOME/skills/humanize-korean (기본 ~/.hermes)
```

`--copy` 로 복사 설치, `--dry-run` 으로 미리보기, `--force` 로 기존 파일 백업 후 덮어쓰기. 제거는 `./uninstall.sh` — **이 저장소를 가리키는 심링크만** 지웁니다. 남의 파일, 다른 곳을 가리키는 링크, `.bak.*` 백업, `--copy` 설치본은 건드리지 않습니다.

## 사용

새 Hermes 세션에서:

```
/humanize-korean
```

또는 자연어로 — "AI 티 없애줘", "번역투 고쳐줘", "사람이 쓴 것처럼 윤문해줘". 파일 경로(`.txt`·`.md`)를 줘도 됩니다.

결과는 현재 작업 디렉터리의 `_workspace/YYYY-MM-DD-NNN/` 에 남습니다 — `01_input.txt`(원문 보존)와 `final.md`(윤문본 + 요약 주석).

## 이 포트가 하는 것과 하지 않는 것

**합니다** — Fast Path(단일 호출). 탐지·윤문·자체검증을 주 에이전트 한 번의 호출 안에서 끝냅니다.

**하지 않습니다** — Claude Code 전용 standard/heavy 다중 서브에이전트 경로. `--strict`·"heavy" 를 요청하면 스킬이 Fast Path 만 설치돼 있음을 알리고 멈춥니다. 지원하지 않는 다중 에이전트 산출물을 흉내 내지 않습니다. 정밀한 다중 관점 검증이 필요하면 본진의 Claude Code 버전을 쓰세요.

변경률은 모델이 눈대중으로 추정하지 않습니다. `difflib.SequenceMatcher(None, before, after, autojunk=False)` 로 `execute_code` 안에서 계산하고, 경계값을 포함한 세 구간(`<=30%` 채택 / `30~50%` 경고 / `>50%` 미채택)으로만 판정합니다. 그래서 `execute_code` 가 없는 세션에서는 스킬이 실행을 거부합니다.

## 룰북이 조용히 낡지 않게

Hermes Skills Hub 는 번들 안의 심볼릭 링크를 거부합니다. 그래서 `references/quick-rules.md` 는 본진을 가리키는 링크가 아니라 **실파일 사본**입니다. 실파일 사본의 유일한 위험은 본진이 룰북을 고쳤을 때 조용히 낡는 것입니다.

`scripts/check_upstream_drift.py` 가 그걸 막습니다. 본진의 정본 룰북을 가져와 A~J 패턴 본문을 사본과 대조하고, 어긋나면 **CI 를 깨뜨립니다.**

```bash
python3 scripts/check_upstream_drift.py            # UPSTREAM 핀(고정 태그)에 대해 검사
python3 scripts/check_upstream_drift.py --ref main # 본진 최신에 대해 검사(조기경보)
```

| 종료 코드 | 뜻 |
|---|---|
| 0 | 일치 |
| 1 | 드리프트 — 사본을 갱신해야 함 |
| 2 | 룰북 구조 이상(경계 마커 없음) — 포맷 자체가 바뀌었을 수 있음 |
| 3 | 본진을 가져오지 못함 — 조용히 통과시키지 않음 |

핀은 [`UPSTREAM`](UPSTREAM) 에 있습니다. 두 층으로 봅니다.

- **PR·push CI** — 고정 태그(`v2.3.1`)에 대해 검사. 재현 가능하고, 본진이 움직여도 우리 CI 가 무작위로 빨개지지 않습니다.
- **주간 예약 작업** — 본진 `main` 에 대해 검사. 어긋나면 이슈를 자동으로 엽니다. 사본이 낡았다는 걸 사용자가 아니라 우리가 먼저 압니다.

## 테스트

```bash
bash tests/test_hermes_skill.sh       # 번들 구조·프론트매터·지원파일 격리 (네트워크 불필요)
bash tests/test_install_flags.sh      # 설치 플래그·감지·거부·HERMES_HOME 오버라이드
bash tests/test_uninstall_flags.sh    # 우리 링크만 지우는지
bash tests/test_drift_check.sh        # 드리프트 검사가 실제로 드리프트를 잡는지 (네트워크 필요)
```

`tests/test_hermes_skill.sh` 는 저장소 전체에 심링크가 없는지도 봅니다 — 어디에 생기든 Skills Hub 배포가 깨지기 때문입니다.

## 본진과의 관계

- 룰북(A~J 패턴)의 주인은 본진입니다. **여기서 직접 고치지 마세요.** 룰 자체에 대한 제안은 본진 이슈로 올려 주세요.
- 이 저장소가 책임지는 것: Hermes 런타임 적응(`skill_view` 점진 로드, 도구 계약, Skills Hub 번들 제약), 설치·제거, 드리프트 검사.
- 본진이 Hermes 라이브 검증 환경을 갖추면 공식 지원으로 재제출할 계획입니다. 그때까지는 여기가 유지 주체입니다.

배경: [epoko77-ai/im-not-ai#61](https://github.com/epoko77-ai/im-not-ai/pull/61) — 품질 문제가 아니라 지원 범위 정책으로 닫힌 PR 이고, 그 논의에서 이 저장소가 나왔습니다.

## 라이선스

MIT. 저작권은 본진([epoko77-ai](https://github.com/epoko77-ai))에 있고, 이 포트도 같은 조건으로 배포합니다. 룰북과 스킬 절차의 원저작자는 본진 기여자들입니다.
