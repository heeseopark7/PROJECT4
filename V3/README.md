# V3 작업 지침 (새 세션은 이 파일부터 끝까지 읽을 것)

이 파일은 다른 채팅방(새 세션)에서 작업을 이어가기 위한 **인수인계 문서**다. 이전 대화가 없어도 여기만 읽으면 이어갈 수 있게 썼다. 루트의 `CLAUDE.md`가 이 파일을 가리킨다. 사용자와는 **반말**로 대화한다.

---

## 1. 프로젝트 한 줄 요약
자작 MIPS MCU(단일 사이클 CPU, 명령어 ROM, 데이터 RAM, APB 브리지, UART, SPI master/slave)를 GPDK045로 RTL부터 GDS까지 구현하고, 병목을 분석해 **버전마다 한 가지만 바꿔** PPA 변화를 측정/해석하는 PD/PI 신입 지원용 포트폴리오다. 평가 포인트는 RTL이 아니라 합성~PnR~STA를 직접 다뤘다는 근거와 분석 과정이다.
- 도구: Genus(합성), Conformal(EC), Innovus(PnR), Tempus(STA), xrun(시뮬). **사용자가 학교(폴리텍) 서버에서 직접 실행**한다. 이 클라우드 환경에는 EDA 툴이 없다.
- 기준 계획서: `V2/docs/MCU_계획서_V번호수정본.docx` (버전 번호를 폴더 번호에 맞춰 수정한 최신본). 원문 요지는 아래 3장.

## 2. 버전과 폴더 (번호 = 폴더 번호)
| 폴더 | 내용 | 상태 | git 태그 |
|---|---|---|---|
| `V1` | 패드 포함 칩 레벨 완성본 (`mcu_pad_top`) | 완료 | `v1-pad` (커밋 `4010c09`) |
| `V2` | 패드 없는 코어 단독 기준선 (`mcu_core_top`), RTL 변경 없음 | **완료** | `v2-core` (커밋 `9f594fc`) |
| `V3` | **가산기 구조 교체 (계획서의 v2)** | **이번에 시작** | `v3` |
| `V4` | 주소 디코드 레지스터화 (계획서 v3) | 선택 | `v4` |
| `V5`, `V6` | 전력/면적 축, SPI FIFO | 선택/후순위 | |

태그 상태: 원격에는 옛 이름 `v1-core`(= `9f594fc`)만 있다. 이 환경에서는 태그 푸시가 막혀 있어서 사용자가 로컬에서 바꿔야 한다. 안내 명령:
```bash
git fetch origin --tags
git tag v2-core v1-core
git tag v1-pad 4010c09
git push origin v2-core v1-pad
git tag -d v1-core
git push origin :refs/tags/v1-core
```

## 3. 계획서 핵심 원칙
1. 버전마다 바꾸는 것은 **한 가지**뿐이다.
2. 모든 버전은 **같은 SDC, 같은 플로우 스크립트**로 돌린다 (클럭 sweep 때만 `create_clock -period` 변경).
3. 기대와 다른 결과나 실패도 그대로 기록한다.
4. 숫자마다 "왜"를 한 문단으로 설명할 수 있어야 한다. 로그 원본과 대조 전에는 "확인됨"으로 쓰지 않는다.
5. 패드 있는 결과(V1)와 없는 결과(V2~)의 슬랙/전력은 **직접 비교하지 않는다.** 비교는 코어 단독 트랙(V2 이후)에서 한다.
6. 버전 페이지 5칸: 가설 / 변경 내용 / 결과 / 해석 / 한계.
7. 폴리텍 도구 사용이 11월에 종료된다고 계획서에 적혀 있다. **툴이 필요한 작업을 먼저, 문서화는 나중에** 한다. 정확한 종료일은 사용자에게 확인해야 한다 (미확인).

---

## 4. V3 범위, 가설, 근거
- **변경 (한 가지):** `V3/TOP/1_RTL/sccpu.v`의 ALU 덧셈/뺄셈 구현을 prefix 가산기(Kogge-Stone 등)로 교체. 나머지(PC+4, 분기 목표 가산, 비교기, SDC, 플로우 옵션)는 V2와 동일.
- **가설:** 가산기 구간이 줄어 더 빠른 클럭까지 timing이 닫히고 면적은 늘어난다. 최악 경로가 다른 구간(명령어 ROM → 디코드 → 주소 디코드 → FIFO)으로 옮겨갈 수 있다.
- **근거 (V2 post-route Tempus, 로그 확인):** 최악 setup 경로는 `u_mcu_top/uut1/r_pc_reg_7 → 명령어 ROM(uut2) → CPU 디코드/가산기(uut1) → 주소 디코드(u_mcu_top 상위 게이트) → UART 레지스터(uut5/uut6) → tx_fifo(uut5/uut2) r_count_reg_4`. 데이터 경로 약 9.43 ns 중 구간별 지연(근사):
  | 구간 | 지연 |
  |---|---|
  | PC 클럭→Q | 0.32 ns |
  | 명령어 ROM | 1.41 ns |
  | CPU 디코드+연산 | 4.71 ns (그중 **가산기 약 3.2 ns, 34%**) |
  | 주소 디코드 | 1.42 ns |
  | UART 레지스터 | 0.62 ns |
  | TX FIFO | 0.97 ns |
- **합성 넷리스트의 가산기 구조:** ADDFX1 체인이 아니다. 전체 ADDFX1 6개, ADDHX1 51개, `sccpu` 안은 ADDFX1 6 + ADDHX1 7. 최악 경로의 가산기는 `sub_158_49_Y_add_166_49_*` 셀과 `g201xx` AOI2BB1 계열 게이트열(약 15단, 단당 약 180 ps)이다. (V1 PPT의 "32비트 ripple-carry 약 1.67 ns"는 20 ns/5 ns 합성에서 본 구조이고 10 ns 넷리스트와 다르다.)
- **주의 (sweep 범위 재검토):** 10 ns에서는 툴이 slack을 0에 가깝게 채우며 면적을 줄인다. V1 PPT 11번(패드 버전, 로그 대조 전 수치)상 합성은 4 ns(+0.2 ps, 면적 +19%)와 2.5 ns(SDC 수정 후 +0.7 ps)까지 닫혔다. 따라서 계획서의 10 → 8 → 7 ns sweep은 아무것도 안 깨질 가능성이 높고, 더 낮은 주기(6/5/4/3.5/3 ns)에서 깨지는 지점을 찾아야 의미가 있다. V1 PnR은 5 ns에서 처음 위반(init WNS −6.2 ns, 원인 미확인)이었다가 재실행으로 통과했다.

## 5. 결정 상태 (미확정, 사용자에게 확인할 것)
| 항목 | 기본값(제안) | 상태 |
|---|---|---|
| 가산기 구조 | Kogge-Stone (대안: CLA 4비트 블록). KS는 prefix 5단(간격 1,2,4,8,16)으로 지연이 가장 짧고 설명이 쉽지만 셀/배선이 가장 많음 | 미확정 |
| 합성 sweep 주기 | 10, 6, 5, 4, 3.5, 3 ns, **v1-core(V2)와 V3 둘 다** (계획서 원안 10, 8, 7) | 미확정 |
| 플로우 깊이 | 합성과 EC는 전부, PnR/Tempus는 10 ns와 두 버전이 모두 통과하는 가장 빠른 주기 하나, 시뮬은 pre-layout 한 번 | 미확정 |
| 도구 사용 종료일 | 사용자에게 확인 | 미확인 |

사용자가 "응"이라고만 하면 위 기본값으로 진행한다.

---

## 6. V3 폴더 세팅 (V2에서 복사)
`V3/TOP/{1_RTL,2_SIM,3_SYN,4_EC,5_PNR}` 구조를 V2와 똑같이 만든다. 현재 `V3/`에는 빈 `3.v` 플레이스홀더만 있다 (세팅 시 삭제).
| 파일 | V3에서 |
|---|---|
| `1_RTL/*.v` (`mcu_pad_top.v` 포함 V2와 동일 목록) | 복사. **`sccpu.v`만 수정**, 새 가산기 파일(예: `add32_ks.v`) 추가 |
| `3_SYN/script/syn_mcu_core_top.tcl` | `RTL_SOURCES`에 새 파일 한 줄 추가 (불가피, README에 기록) |
| `4_EC/script/script.tcl`, `4_EC/POST/script/script.tcl` | Golden RTL 목록에 새 파일 추가 (불가피) |
| `3_SYN/cons/*.sdc`, `5_PNR/*.tcl`, `mmmc.view`, 시뮬 스크립트 | 복사만, **수정 없음** (sweep 때 주기만) |
| `5_PNR/mcu_core_top_pnr.sdc` | 합성 후 **새로 생성** (아래 7장 PnR SDC) |
| 최상위 이름 | `mcu_core_top` 그대로, 산출물 이름 변경 불필요 |
복사할 때 산출물(`report`, `mapped`, `*.dat`, 로그 등 `.gitignore` 대상과 큰 파일)은 가져오지 않는다. 스크립트와 RTL, SDC만 복사.

## 7. RTL 변경 지침
- 현재 `sccpu.v`: 158번 줄 `r_alu = w_a - w_b` (sub), 166번 줄 `r_alu = w_a + w_b` (add, addi, lw, sw). Genus가 두 연산을 `sub_158_49_Y_add_166_49` 하나의 가산기로 합쳤다. `w_a`, `w_b`는 레지스터/immediate 선택 mux 뒤의 ALU 입력이다. 같은 `r_alu`가 주소(`o_aluout`)로도 나가 주소 디코드 경로로 이어진다.
- 변경안:
  ```verilog
  wire [31:0] w_bx  = w_sub ? ~w_b : w_b;      // sub: a + ~b + 1
  wire [31:0] w_sum;
  add32_ks u_add (.a(w_a), .b(w_bx), .cin(w_sub), .sum(w_sum));
  ...
  if (w_sub)  r_alu = w_sum;                   // 158번 줄 대체
  ...
  else        r_alu = w_sum;                   // 166번 줄 대체
  ```
  `add32_ks`: 비트별 `g = a&b`, `p = a^b`, prefix 5단(간격 1,2,4,8,16), `sum = p ^ 캐리`. `cin`은 최하위 캐리 입력에 반영.
- **건드리지 않는 것:** `w_p4 = r_pc + 4`, `w_br_target`, 비교기(`==`, `!=`). 최악 경로 밖이다.
- **검증 (툴 없이 이 환경에서 가능):**
  1. `add32_ks` 단독 랜덤 테스트: add와 sub를 수만 번 `+`, `-` 연산자와 비교하는 별도 테스트벤치.
  2. RTL 회귀: V2와 같은 명령, `PASS tb_mcu_top`이 8645000 ps(8645 ns)에서 나와야 한다.
     ```bash
     cd V3/TOP
     iverilog -g2012 -o tb.vvp -s tb_mcu_top $(ls 1_RTL/*.v | grep -v pad_top) 2_SIM/4_TESTBENCH/tb_mcu_top.v && vvp tb.vvp
     ```
     iverilog가 없으면 `apt-get update && apt-get install -y iverilog` (이 환경에 없을 수 있음).
  3. 게이트 시뮬용 분기 확인: `iverilog -DGATE_SIM ...`(RTL로 `mcu_core_top` 인스턴스 이름/포트 연결만 확인).

---

## 8. 플로우와 실행 방법 (V2에서 검증 완료, V3도 동일)
사용자가 학교 서버에서 실행하고 로그/캡처를 가져온다. 경로 기준은 `V3/TOP/`.
| 단계 | 위치 | 명령 |
|---|---|---|
| RTL 회귀 | (이 환경) | 위 7장 iverilog 명령 |
| 합성 | `3_SYN` | `./run_synthesis` (`genus -f ./script/syn_mcu_core_top.tcl -log ./log/all.log`). 약 4분 |
| EC (RTL ↔ 합성) | `4_EC` | `lec` 실행 후 `dofile ./script/script.tcl`. **`mkdir -p log` 필요** |
| pre-layout 시뮬 | `2_SIM/2_PRE` | `./run_pre.tcl`. 합성 SDF 사용 |
| PnR | `5_PNR` | `innovus -files 0_InitDesign.tcl` → `1_PowerPlan.tcl` → `2_PlaceOpt.tcl` → `3_PostCTSopt.tcl` → `4_RouteDesign_PowerAnalysis.tcl` → `5_ChipFinish.tcl` (단계별 로그를 따로 남김) |
| EC (합성 ↔ PnR) | `4_EC/POST` | `lec` 후 `dofile ./script/script.tcl`. Golden = 합성 넷리스트, Revised = `5_PNR/mcu_core_top.v` |
| post-route Tempus | `5_PNR` | `tempus` 후 `read_design RouteDesign.dat mcu_core_top`, `report_timing -late/-early -max_paths 1`, `check_timing`, `report_annotated_parasitics`, `report_analysis_coverage`, `write_sdf -view FUNC_SS_WORST mcu_core_top_post_wst.sdf`, `write_sdf -view FUNC_FF_BEST mcu_core_top_post_bst.sdf` |
| post-layout 시뮬 | `2_SIM/3_POST/max`, `min` | `mkdir -p dump` 후 `./run_post_max.tcl`, `./run_post_min.tcl` |
| 청소 | 각 폴더 | `clean.tcl`은 셸 스크립트라 **`sh clean.tcl`**로 실행. 지우는 범위가 넓으니 백업 후 |

**PnR용 SDC (매우 중요):** PnR은 `mcu_core_top_pnr.sdc`를 읽는다 (`5_PNR/mcu_core_top.mmmc.view`가 `./mcu_core_top_pnr.sdc` 참조). 합성 SDC(`3_SYN/mapped/mcu_core_top_syn_final.sdc`)에서 `set_ideal_network [get_ports clk]`와 `[get_ports clrn]` 두 줄만 뺀 복사본이다. 이유: V2는 패드가 없어 clk 포트 net이 곧 FF를 구동하는 net이라, ideal network로 지정하면 CTS가 버퍼를 만들지 않는다 (V1은 패드 뒤 net이라 해당 없음). **합성을 다시 돌릴 때마다 새로 만들어야 한다.**
```bash
cd 5_PNR
{ sed -n '1,8p' ../../../V2/TOP/5_PNR/mcu_core_top_pnr.sdc; sed '/^set_ideal_network \[get_ports \(clk\|clrn\)\]$/d' ../3_SYN/mapped/mcu_core_top_syn_final.sdc; } > mcu_core_top_pnr.sdc
```
(첫 8줄은 V2 파일의 설명 주석 헤더. 새 합성에서 나온 SDC의 `set_ideal_network` 두 줄은 주석 없이 나오므로 이 `sed`로 지워진다. 참고: V2의 `mapped/mcu_core_top_syn_final.sdc`에는 해당 두 줄이 `#`으로 주석 처리돼 있는데 사용자가 직접 수정한 흔적으로 보이고, 실제 PnR은 `mcu_core_top_pnr.sdc`를 읽는다.)

## 9. V2에서 겪은 함정 (V3에서도 조심)
1. **ideal network → CTS 버퍼 0개 위험.** 위 7장 PnR SDC로 해결. V2 CTS 결과: 버퍼 138개 (V1 176).
2. **`clean.tcl`** 은 실행 권한이 없어 `./clean.tcl`이 안 된다 → `sh clean.tcl`.
3. **EC `log` 폴더:** `set log file ./log/all.log`는 폴더를 만들어주지 않는다. `mkdir -p log`.
4. **post-layout 시뮬 `run_post_*.tcl`:** 파일 이름 오타(`mcu_core_top_.v`)를 조심. `dump` 폴더가 없으면 `$shm_open` 경고(결과와 무관).
5. **SDF 적용률 확인 필수** (V1에서 0.17%만 적용된 사고). xmelab 로그의 `SDF statistics`에서 경로 지연 약 90% 이상, `Instance ... not found` 없음, 에러 0. 미적용은 `RECREM`(리셋 FF의 recovery/removal). 확인 명령:
   ```bash
   head -14 sdf_post_wst.log
   grep -c "Unable to annotate" sdf_post_wst.log
   grep "Unable to annotate" sdf_post_wst.log | grep -vc "RECREM"   # 0이어야 함
   grep -c "\*E," sdf_post_wst.log                                   # 0이어야 함
   ```
   RECREM은 셀 모델(`DFFRX1`)이 리셋 핀에 별도의 `$recovery`/`$hold`(한계 0)를 두고 있고 Tempus SDF는 RECREM 결합 항목으로 줘서 매핑되지 않는 것이다 (모델 소스로 확인함). 해당 체크는 STA에서 위반 0.
6. **IO hold:** 입력 지연 최소값이 0.01 ns라 입력 경로에 hold 수정용 지연 버퍼(`FE_PHC*`)가 들어간다. V2 postRoute hold WNS는 +0.011 ns로 여유가 얇다. V3에서도 재확인.
7. **전력 계산 주기:** `4_RouteDesign_PowerAnalysis.tcl`의 `set_default_switching_activity -input_activity 0.2 -period 8.0`은 V1에서 물려받은 값이다(설계 클럭 10 ns). V1/V2와 같게 8.0을 유지하고 캡션에 "8 ns 기준"이라고 쓴다. 클럭 sweep을 하면 이 값도 의미가 달라지니 주의.
8. **Tempus `Design Mode: 65nm`:** 스크립트에 `setDesignMode -process`가 없는 V1과 동일 조건. "한계"에 기록.
9. **tempus.tcl** 은 끝에서 `exit`하므로 경로 리포트가 필요하면 명령을 직접 친다.
10. **main 충돌:** 사용자도 main에 직접 커밋한다 (학교 서버에서). main 푸시 전에 반드시 `git fetch` 후 병합. 한 번 `3_POST` 스크립트 add/add 충돌이 났었다.
11. **GUI 캡처:** Density map은 `setLayerPreference allLayers -isVisible 0` 후 `densityMap` 켜고 확대해야 숫자가 보인다. 모듈 색칠은 Design Browser에서 `highlight`.

---

## 10. V2 기준선 결과 (V3 비교 대상, 모두 로그 확인)
| 지표 | v1-core (V2) |
|---|---|
| 합성 (10 ns) | slack +1.2 ps, TNS 0, FF 1,816, 인스턴스 5,235, 셀 면적 21,819 µm² (RAM 10,495 / UART 5,160 / CPU 4,275 / ROM 315) |
| 최악 합성 경로 | `r_pc_reg_5 → u_mcu_top/uut5/uut2/r_count_reg_4` (`uut5/uut2` = `tx_fifo`의 카운터, 보레이트 카운터 아님) |
| EC | RTL↔합성 PASS (입력 7, 출력 8, FF 1,816, RTL만 있는 792개 = Extra 32 + Unreachable 760, Design ambiguity 1건), 합성↔PnR PASS (비교점 1,824) |
| floorplan | die 251.6 × 249.85 µm, 코어 191.6 × 189.81 µm = 36,368 µm², utilization 0.6 |
| 타이밍 흐름 (setup WNS) | prePlace +3.138 → preCTS +0.399 → CTS 직후 +0.034 → 최적화 후 +0.275 → postRoute **+0.348 ns** |
| hold WNS | CTS 최적화 후 +0.001 → postRoute **+0.011 ns** (reg2reg +0.054, IO +0.011) |
| 클럭 트리 | sink 1,816 (1,799+17), 버퍼 138, 인버터 1, skew setup 0.097 / hold 0.039 ns, 삽입 지연 평균 0.477 ns |
| 밀도 / 혼잡도 | 61.839% (필러 전), Overflow 0, DRC 0, 연결성 0 |
| 필러 / 산출물 | 필러 7,384개, `.v` 0.62 MB, SDF 3.75 MB, GDS 8.1 MB |
| 전력 | 정적 0.765 mW (활동 0.2, 계산 주기 8 ns 기준; 내부 0.548 / 스위칭 0.216 / 누설 0.0005 mW) |
| Tempus | setup +0.347 ns, hold +0.011 ns, Setup/Hold 3,144/3,144 Met, 실제 net 5,906개 100% annotated |
| pre-layout 시뮬 | PASS, 첫 UARTTXD 하강 +0.83 ns, 첫 SCLK 상승 +0.36 ns |
| post-layout 시뮬 | worst/best PASS, 경로 지연 91.56%, 체크 82.30% 적용, worst +0.941/+0.891 ns, best +0.241/+0.22 ns |
| 총 실행 클럭 | 843 (V1과 같은 프로그램, 재측정 안 함) |

V2 상세 진행 기록과 "V1 대비 의도된 차이 목록", 비교표 원본은 `V2/README.md`에 있다.

## 11. 작업 순서와 진행 체크리스트
순서: 툴 없이 되는 준비 → (사용자) 합성 sweep → 비교 → EC → PnR/Tempus → 시뮬 → 문서화.
- [ ] 결정 확정 (5장 표)
- [ ] V3 폴더 세팅(6장), `add32_ks.v`와 `sccpu.v` 수정, iverilog 검증(7장)
- [ ] **v1-core(V2) 합성 sweep** — V2 폴더의 SDC에서 주기만 바꿔서 같은 주기들을 합성 (V3와 비교할 기준값. 지금 v1-core는 10 ns 하나뿐)
- [ ] V3 합성 sweep, 비교표 (slack, 면적, 최악 경로, **가산기 구간 지연**, 가산기 셀 구성, 계층별 면적 `sccpu`)
- [ ] EC (RTL ↔ 합성)
- [ ] PnR + Tempus (선택 주기), PnR용 SDC 재생성 필수
- [ ] pre-layout 시뮬 (필요 시 post-layout)
- [ ] 버전 페이지 5칸, 비교표, 슬랙 그래프(sweep 데이터), 태그 `v3`

**비교할 지표 (계획서 6장):** setup/hold WNS·TNS, 합성 면적, PnR 면적/utilization, 전력, 클럭 트리 sink/skew/latency, DRC, EC, 시뮬 통과, 총 실행 클럭(843), 도달한 최소 클럭 주기(정의: 합성과 postRoute setup/hold가 모두 ≥ 0인 가장 짧은 주기). 해석 포인트는 **최악 경로가 어디로 이동했는지**와 면적 증가 이유다.

## 12. 비교표 (V2 열은 위 10장 값)
| 지표 | V2 | V3 |
|---|---|---|
| setup WNS / TNS | +0.348 ns / 0 (postRoute) | |
| hold WNS / TNS | +0.011 ns / 0 | |
| 합성 면적 | 21,819 µm² | |
| PnR 면적 / utilization | 코어 36,368 µm² / 61.839% | |
| 전력 | 0.765 mW (8 ns 기준) | |
| 클럭 트리 sink / skew / latency | 1,816 / 0.097, 0.039 ns / 0.477 ns | |
| DRC | 0 | |
| EC | PASS | |
| RTL / 게이트 시뮬 | PASS | |
| 총 실행 클럭 | 843 | |
| 도달한 최소 클럭 주기 | 미측정 | |

---

## 13. 캡처, 캡션, 문서화 방식 (사용자가 선호하는 흐름)
- 사용자가 로그나 GUI 캡처를 채팅에 올리면, Claude가 **값을 읽어 기대값/이전 단계와 대조하고 정상 여부를 판정**한 뒤 **한국어 캡션**을 준다. 캡션은 V1 문서 형식(한두 문장, 값 포함)을 따른다. 예: `배선 후 최종 setup 타이밍(postRoute, slow 코너 SS_WORST, 클럭 10 ns): WNS +0.348 ns, TNS 0, 위반 경로 0개이다. ...`
- **캡처 가이드와 캡션은 채팅으로 준다.** (별도 md를 만들지 않는다. 사용자가 이미 없애도 된다고 했다.)
- 캡처 목록 형식은 단계별 표: 캡처 / 방법(파일, 명령) / 보여야 할 것 / V2 대비 바뀌는 점. 이전 단계 가이드는 V2 세션에서 만든 것과 같은 구성을 쓴다 (합성: SDC+스크립트, 스키매틱, check_design, 완료 로그, QoR, 최악 경로, 계층별 면적, 셀 종류, 전력, 계층 구조 / EC: 스크립트, black box, verification, statistics / PnR: 단계별 GUI와 로그, 타이밍 요약 / Tempus: 경로, check_timing, 주석, 커버리지 / 시뮬: SDF 통계, 파형 4장, 콘솔 로그, SDF 로그).
- 값이 기대와 다르거나 이상하면 **숨기지 말고 짚는다** (예: 설명 못 하는 차이는 "원인 확인하지 못했다"고 쓴다). 추정은 "추정"이라고 표시.
- 단계가 끝날 때마다 해당 README(`V3/README.md`)의 체크리스트와 결과 기록을 갱신하고 푸시한다.

## 14. 미해결 / 후속 정리 항목
- **V1 PPT 정정 (계획서와 별개):** (a) 17번 슬라이드 "UART 보레이트 카운터 r_count_reg_4"는 TX FIFO 카운터가 맞다 (V1 면적 표와 경로의 `w_tx_push`로 확인). (b) V1 SDC는 `set_driving_cell PADDI`가 활성인데 PPT 12번은 `set_input_transition 0.1`로 교체했다고 서술 (불일치). (c) "RCA 병목"은 20/5 ns 합성에서의 구조이고 10 ns 넷리스트는 AOI 게이트열. (d) V1 pre-layout 문서의 지연 확대 캡션 "약 1.15 ns"는 캡처의 1.773 ns와 불일치.
- **공개 전 점검 (계획서 9장):** 라이선스, 미완성 결과 제외, 수치와 로그 대조. 현재 `.gitignore`가 툴 산출물을 제외하지만 PnR 산출물(GDS 등)이 일부 올라가 있다. 과거 커밋에 `cmsdk_mcu.v`가 남아 있으나 사용자는 암호화되어 있어 공개돼도 괜찮다고 판단했다. 로그/캡처에 학교 계정/호스트 이름(`kopo-seongnam` 등)이 보인다.
- **선택 실험 (후순위):** `set_db interconnect_mode ple`(Genus/Innovus 지연 차이 원인), `setDesignMode -process`, cost group 분리, mmmc 합성 — 모두 별도 버전 실험으로만, 한 번에 하나.

## 15. 사용자 선호 / 작업 방식 메모
- **가이드 우선:** 사용자가 직접 수정한다. 사용자가 지시하기 전에는 어떤 파일도 수정/생성하지 않고, 파일과 위치, 변경 내용만 안내한다. 사용자가 명시적으로 요청하면 그때 해당 범위만 수정한다 (루트 `CLAUDE.md`에도 동일 규칙).
- 대화는 반말. 답은 결론 먼저, 표로 정리. 불확실한 것은 불확실하다고 말하기.
- "V1과 패드 유무만 다르게, 나머지는 똑같이"가 핵심 원칙이었다. 임의로 값을 바꾸면 지적받는다 (실제로 I/O delay를 1.0 ns로 바꿨다가 되돌린 적이 있다). V3도 "가산기 한 가지"만.
- 사용자가 스크립트/테스트벤치를 직접 고치는 경우가 많다. 같은 파일을 만지기 전에 최신 main을 받고, 충돌 가능성이 있으면 먼저 묻는다.
- main 푸시는 사용자가 요청할 때만 (개발 브랜치는 `claude/elegant-allen-346eot`).
