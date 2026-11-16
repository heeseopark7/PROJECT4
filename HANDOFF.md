# HANDOFF: MCU RTL to GDS2 포트폴리오 (repo 상태 + 이전 대화 인수인계 통합본)

이 폴더(`PROJECT4`)에서 새 대화를 시작하면 이 파일을 먼저 읽고 이어서 작업한다.
통합 기준: git fetch 후 `main`(24f42a3 "update", 2026-11-17)과 브랜치 상태 + 첨부 HANDOFF.md(2026-11 이전 대화).

## 0. 주의
- 이 프로젝트는 **MCU(mcu_pad_top)의 RTL → GDS2 플로우 포트폴리오**다. PI/PD 직무 지원용.
- `C:\Users\user\Downloads\CLAUDE.md`(ALU/MAC RTL 프로젝트 지침)는 **다른 프로젝트**다. 여기에 적용하지 않는다.
- 대화는 반말로 한다 (사용자 선호).

## 1. 사용자 역할 (포트폴리오에 그대로 쓰는 문구)
- MCU RTL은 Claude의 도움을 받아 작성했고, 사용자는 코드 구조를 설명할 수 있는 수준으로 이해했다.
- RTL 시뮬레이션, 합성, P&R은 직접 수행했다고 사용자가 확인했다.
- Conformal 등가성 검사와 Tempus STA도 "직접 수행"으로 적었지만 **사용자가 명시적으로 확인한 것은 아니다**. 확인 필요.

## 2. 저장소 구조 (git 기준, 이번에 확인한 것)
`proj4_make/TOP/`
| 폴더/파일 | 내용 |
| --- | --- |
| `1_RTL/` | RTL 전체 (top=`mcu_pad_top`, core=`mcu_top`) |
| `2_SIM/` | RTL 시뮬(`FUNCTION`) 등 검증 환경 |
| `3_SYN/` | Genus 합성 (`cons/mcu_pad_top.sdc`, `script`, `report`, `mapped`) |
| `4_EC/` | Conformal 등가성 (`script`, `log`, `POST`) |
| `5_PNR/` | Innovus 스크립트 `0_InitDesign`~`5_ChipFinish`, `6_ECO.tcl`, `4_RouteDesign_PowerAnalysis_ECO.tcl`, `tempus.tcl`, `add_pad`, 로그/리포트 |
| `MCU_DESIGN.md` | 설계 문서 (구조, 블록 다이어그램. 48-pad ring, 신호 패드 15개 언급) |

### 브랜치 (fetch 결과)
| 브랜치 | 상태 |
| --- | --- |
| `main` = 현재 작업 브랜치 `claude/kind-knuth-l5qa4q` | 24f42a3. 최신 기준 |
| `claude/quirky-curie-e0kukr` | main 위에 커밋 1개: `5_PNR/sdf_flatten.pl` 추가(SDF 인스턴스 이름의 `/`를 escape해 평탄 넷리스트와 맞춤). 아래 3번 SDF 문제와 관련됨. **아직 main에 합치지 않음** |
| `claude/gifted-faraday-rmxyo6` | MCU 설계 문서(md + PDF) 추가. 별도 이력(merge base 없음), 오래된 폴더 상태라 통째 merge 금지 |
| `claude/vibrant-faraday-0b6c7p` | SPI master RTL + `mcu_top` 통합 + 시스템 시뮬(TB, UART stub). 별도 이력, 통째 merge 금지 |
| `claude/affectionate-curie-41wkx3` | 48-pad ring(패드당 12개/변), `add_pad` 갱신, `run_function` 수정. 별도 이력, 통째 merge 금지 |
- 위 3개는 main 이전 상태에서 갈라진 것이라 diff가 수천 파일(대부분 로그 삭제)로 나온다. 필요한 변경만 골라 cherry-pick/수동 반영한다.

### 포트폴리오 산출물
repo의 `portfolio/`에 있는 것:
- `portfolio/MCU_RTL_to_GDS2_portfolio.pptx` (23장)
- `portfolio/src/template.html` (HTML 편집용 원본, 이미지는 `src="assets/<이름>.jpg"`)
- `portfolio/src/deck.json` (PPT 슬라이드 내용, UTF-8)
- `portfolio/src/build.ps1` (deck.json → PPTX, PowerPoint COM 필요)

repo에 **없는 것**(사용자 PC에만 있음): `assets/*.jpg` 증거 캡처, 완성본 `MCU_RTL_to_GDS2_portfolio.html`(base64 포함), `evidence_5ns_rerun/`. 이미지가 없으면 HTML 재빌드와 PPT 재생성은 불가하다. 필요하면 사용자에게 assets를 받아 `portfolio/assets/`에 넣는다.
- HTML artifact: https://claude.ai/artifact/VLxxP3w3Fqs9oW5d4DHmgR (7번째 버전)
- HTML 빌드: `template.html`의 `src="assets/xxx.jpg"`를 `data:image/jpeg;base64,...`로 치환 → UTF-8(BOM 없음)로 저장 → artifact 같은 URL로 재게시.
- PPT 빌드: `build.ps1`을 `powershell -NoProfile -ExecutionPolicy Bypass -File`로 실행. **`$base`가 예전 임시 폴더(scratchpad), `$assets`/`$out`이 `C:\Users\user\Downloads\PROJECT4\portfolio\...`로 하드코딩**되어 있어 `$base`를 `src` 폴더로 바꿔야 한다(PNG 내보내기도 `$base\png`). PowerShell 5.1에서 BOM 없는 한글 .ps1은 깨지므로 한글은 `deck.json`에만 두고 .ps1은 ASCII 유지.

## 3. 프로젝트 사실 (수치는 증거 캡처 기준)
- 설계: `mcu_pad_top`. 32bit 단일 사이클 MIPS, APB 브리지, UART, SPI master/slave. GPDK045.
- 플로우: RTL 시뮬(xrun) → Genus 합성 → Conformal(RTL↔합성) → pre-layout 시뮬 → Innovus P&R → Conformal(합성↔PnR) → Tempus STA → post-layout 시뮬(worst/best).
- 최종 기준 클럭: **10 ns**. post-route setup WNS +0.441 ns, hold WNS +0.053 ns. verify_drc, verifyConnectivity 0건. GDS 10.7 MB.
- 해결한 문제 3개:
  1. 2.5 ns 합성 위반의 원인이 입력 구동 SDC 모델(PADDI 가정)임을 가려내 `set_input_transition 0.1`로 교체. RTL 수정 없음.
  2. 5 ns 넷리스트가 Innovus init에서 WNS −6.213 ns → 10 ns로 재합성하고 P&R을 처음부터 진행.
  3. post-layout 시뮬이 PASS였지만 SDF 적용률이 0.17%. 평탄(-flat) 넷리스트 저장이 원인. 계층 구조로 저장해 91.99%로 개선. (`sdf_flatten.pl`은 같은 문제를 SDF 쪽에서 푸는 다른 접근. quirky-curie 브랜치.)

## 4. 결정 사항
- **5ns 재도전(합성 후 P&R 재진행) 결과는 본문에서 제외.** 재합성에 쓴 SDC가 첫 시도와 같은지 불확실하고, 사용자가 보낸 SDC 사진(`evidence_5ns_rerun/10.png`)은 `set_driving_cell -lib_cell PADDI`가 켜져 있고 `set_input_transition 0.1`이 주석 처리된 **수정 전 버전**(클럭 5)이다.
  - 그 5ns 재실행 Tempus 결과: setup +0.075 ns(FUNC_SS_WORST), hold +0.052 ns(FUNC_FF_BEST), 각 3,272개 체크 모두 Met. (`evidence_5ns_rerun/6~9.png`)
- 실제 위반을 "의도한 실험"처럼 포장하지 않는다. 의도적 위반 실험은 실제로 수행하고 처음부터 명시한다.
- **다음 단계: hold ECO.** 교수님 방식(사용자 기억): Tempus single corner(fast 라이브러리) STA → hold 위반 확인 → Tempus ECO로 버퍼 추가 → P&R 재진행 → STA 재확인. 정확한 Tempus ECO 명령은 22.17 문서로 확인하고 추측하지 않는다.

## 5. repo와 HANDOFF 대조 시 발견한 불일치 (사용자 확인 필요)
1. **repo의 `3_SYN/cons/mcu_pad_top.sdc`가 지금 `create_clock -period 5`, `set_driving_cell ... PADDI` 활성, `set_input_transition 0.1` 주석 처리** 상태다. 즉 HANDOFF의 "10ns 최종 기준"과 "수정 후 SDC"와 **다르다**. 10ns 실행에 쓴 SDC가 repo에 커밋되어 있지 않다. 포트폴리오의 "스펙과 조건" 슬라이드에 쓸 SDC 값은 이 파일이 아니라 사용자가 10ns 때 쓴 SDC에서 받아야 한다.
2. repo에 `5_PNR/6_ECO.tcl`, `4_RouteDesign_PowerAnalysis_ECO.tcl`, `RouteDesign_ECO(.dat)`가 이미 있고, `6_ECO.tcl`은 `optDesign -postRoute -setup/-hold` 후 DRC까지 하는 Innovus ECO 스크립트다. HANDOFF는 "hold ECO 아직 미수행"인데, 이 스크립트가 실제로 실행되어 결과가 있는지(혹은 템플릿만 있는지) 불명. 또 이것은 Innovus 기반 ECO라 HANDOFF의 "Tempus ECO 기능" 방식과 다를 수 있다.
3. `MCU_DESIGN.md`는 48-pad ring, 신호 패드 15개를 말한다. 포트폴리오 슬라이드의 패드 수/스펙과 일치하는지 확인 필요.

## 6. 미결 사항 (사용자 답변 필요)
1. ECO 후 P&R이 "전체를 처음부터 다시"인지 "ECO 반영 후 증분 라우팅"인지.
2. 역할 표에서 Conformal, Tempus STA를 직접 수행했는지.
3. **"스펙과 조건" 슬라이드 1~2장 추가 예정.** 항목: 설계 스펙, 툴/라이브러리, 코너 정의(FUNC_SS_WORST 0.9V 125°C로 보임, FUNC_FF_BEST 1.1V 0°C), 제약(SDC), 합격 기준. SDC는 **10ns 실행에 쓴 값**(클럭 latency, uncertainty, input/output delay, 입력 구동 설정, 출력 부하)을 받아야 한다.
4. 사용자가 PPT에서 직접 고치려는 부분의 내용(아직 못 받음).
5. PowerPoint에서 글자 잘림/어색한 곳 확인(아직 안 함).
6. `quirky-curie`의 `sdf_flatten.pl`을 main에 반영할지.

## 7. 알려진 한계 (포트폴리오 한계 목록과 일치)
- Genus와 Innovus에서 같은 경로 지연이 크게 달랐음(ADDFX1 체인 단당 약 51 ps vs 185 ps). 원인 미확인. 가설: 라이브러리/코너/설정 차이, Innovus `Design Mode: 90nm` vs Tempus 65nm 표기(확정 아님).
- Genus 5ns 코어 면적(20,818)이 10ns(21,856)보다 작은 이유 미설명.
- IMPVL-159 경고 16건의 셀 이름 미확인.
- GDS 서명용 DRC/LVS(Calibre 등)는 하지 않음.
- 5ns 합성과 P&R 단계별 수치는 캡처하지 않았다.

## 8. 아직 반영하지 않은 아이디어
- 가산기 구조 변형(RCA/CLA/Kogge-Stone) 비교 프로젝트와의 연결 한 줄(별도 ALU/MAC 프로젝트, 지침이 다르니 링크만).
