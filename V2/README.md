# V2 작업 지침 (매 세션 시작 시 먼저 읽을 것)

## 이 폴더(V2)에서 지금 하는 일
- **V2 = 문서의 "v1-core" 기준선.** 패드만 없애고 **RTL은 한 줄도 바꾸지 않고** 그대로 합성, EC, PnR, STA, 시뮬을 돌려 코어 단독 기준선(PPA 전체)을 만든다.
- 가산기 교체, 주소 디코드 레지스터화 같은 **RTL 개선은 이 폴더 범위가 아니다.** 문서의 v2(가산기), v3, v4는 기준선이 끝난 뒤 별도 폴더/버전에서 한다.
- 폴더 매핑: `V1` = v1-pad(완성본), `V2` = v1-core(코어 단독 기준선). 이후 폴더는 문서 5장 순서로 진행.
- 변경은 래퍼 추가(`mcu_core_top.v`), SDC(포트 기준 I/O, 클럭 10 ns), floorplan(utilization 0.6~0.7, 핀 배치, 전원 링/스트라이프)뿐이다.
- 합성/PnR 등 EDA 툴은 사용자가 직접 실행한다. Claude는 스크립트, SDC, 래퍼, 리포트 해석, 문서화를 돕는다.

## 현재 진행 상태
- [x] 코어 래퍼 `TOP/1_RTL/mcu_core_top.v` (디버그 출력 미연결)
- [x] SDC `TOP/3_SYN/cons/mcu_core_top.sdc`: **V1과 동일, 패드 관련 줄만 변경** (패드 dont_touch 15줄 제거, `set_driving_cell PADDI` -> `set_input_transition 0.1`, `set_load [load_of PADDO/A]` -> `set_load 0.003` = 3.0 fF, 근거: V1 `02_report_port.rpt` External Loads 3.0, 단위 fF는 확인됨: V1/V2 합성 SDC 출력에 `set_load -pin_load 0.003`으로 동일하게 나옴)
- [x] SDC 수정 후 합성 재실행 완료 (이전 I/O delay 1.0 ns, load 20 fF 합성은 기준선으로 쓰지 않음)
- [x] 합성 스크립트 `TOP/3_SYN/script/syn_mcu_core_top.tcl`
- [x] RTL 회귀 PASS (iverilog, 8645 ns 종료)
- [x] 합성 실행 (10 ns, slack +1.2 ps, FF 1,816, 셀 면적 21,819 µm², 출력 load 3.0 확인). 캡처 완료
- [x] 가산기 구조 확인: 전체 ADDFX1 6개, ADDHX1 51개(`13_..._gate.rpt`). `sccpu` 안은 ADDFX1 6 + ADDHX1 7로 V1 10ns 넷리스트와 동일. 32비트 ripple-carry(ADDF 31단) 체인이 아니고, 최악 경로상 가산기는 NOR/NAND/AOI 게이트열로 구현됨. ADDHX1 전체는 V1 46개 -> 51개(interrupt_logic 4 -> 9, CPU 밖)
- [x] 합성 전력 0.644 mW: V1 10ns(코어 약 0.80 mW)와 register/logic은 거의 같고 clock 행만 다름(V1 0.19 mW, V2 0.0006 mW, ideal network 때문으로 추정). 합성 전력은 비교에 쓰지 않고 Innovus 결과로 비교
- [x] EC (RTL ↔ 합성) PASS, V1과 동일한 결과 (입력 7 / 출력 8 / FF 1,816 equivalent, RTL만 있는 792개 = Extra 32 + Unreachable 760, Design ambiguity 1건 동일). 캡처 완료: `TOP/4_EC/script/script.tcl` (V1 스크립트에서 패드 lib 제거, golden `mcu_core_top.v`, revised `mapped/mcu_core_top_syn_final.v`)
- [x] pre-layout 게이트 시뮬 PASS (SDF 적용 확인: scope `tb_mcu_top.u_mcu_core_top`, 미적용 488건 모두 REMOVAL, 에러 0). 첫 UARTTXD 하강 +0.83 ns(V1 +1.773), 첫 SCLK 상승 +0.36 ns(V1 +1.392). 캡처 완료
- [x] PnR 스크립트 작성 `TOP/5_PNR/` (V1 0~6번 스크립트에서 이름/패드 관련만 변경: 0~5, 4_..._ECO, 6_ECO, tempus, clean, mmmc.view. all.tcl 제외). 아직 실행 전
- [x] 합성 후 Tempus 스크립트 작성 `TOP/3_SYN/script/tempus_syn.tcl` + `cons/mcu_core_top_tempus.mmmc.view` (3_SYN에서 실행하는 선택 단계. **사용자 결정으로 이번에는 실행하지 않음**, 스크립트만 보관)
- [x] PnR 0단계(0_InitDesign) 완료: die 251.6 x 249.85 um, core 191.6 x 189.81 um (util 0.6 정확히 일치), 핀 15개 4변 배치 정상, prePlace Density 59.996%, WNS +3.138 ns. 캡처 완료
- [x] PnR 1단계(1_PowerPlan) 완료: 코어 링(VSS 바깥/VDD 안쪽)+스트라이프, verify_drc 0 Viols, verifyConnectivity 0 Viols 0 Wrngs, saveDesign 0 warning 0 error. 캡처 완료
- [x] PnR 2단계(2_PlaceOpt) 완료(저장 로그 0 warning 0 error): 배치 인스턴스 5,223개, 밀도 59.94%(place_design 직후)/60.475%(place_opt 후), 혼잡도 Overflow 0(Usage 2.1%H 3.9%V), preCTS setup WNS +0.399 ns, TNS 0, DRV 모두 0, Density 60.603% (PnR용 SDC로 0~2단계 재실행한 최종값. 최초 실행은 +0.397 ns / 60.475%) (V1은 -0.352 ns, 위반 3개, max_tran 33 net)
- [x] **PnR용 SDC 분리(패드 제거에 따른 불가피한 변경, 사용자 결정)**: V2는 clk/clrn 포트 net이 곧 FF를 구동하는 net이라 합성 SDC의 `set_ideal_network`(clk, clrn)가 있으면 CTS가 버퍼링하지 않음(V1은 패드 뒤 net이라 해당 없음). `TOP/5_PNR/mcu_core_top_pnr.sdc` = 합성 SDC에서 이 두 줄만 삭제한 복사본, `mcu_core_top.mmmc.view`가 이 파일을 읽음. 합성/EC/pre-layout 시뮬은 영향 없음. 이 변경 이후 PnR 0단계부터 재실행 필요(clean.tcl은 `sh clean.tcl`). 재실행 후 `clock_trees.rpt`의 Bufs(V1 176)로 확인
- [x] PnR 3단계(CTS) 완료: 클럭 버퍼 138개(V1 176, ideal 제거 효과 확인), CTS 직후 setup WNS +0.034 ns(Density 61.588%), 최적화 후 setup WNS +0.275 ns(Density 61.828%), DRV 0. 최적화 후 hold WNS +0.001 ns(reg2reg +0.053, IO +0.001, 여유 매우 얇음: postRoute에서 재확인), 클럭 트리 Bufs 138/Invs 1/FF 1,816(1,799+17), 스큐 setup 0.097/hold 0.039 ns, 삽입 지연 평균 0.477 ns. Clock Tree Debugger GUI 캡처 완료(루트 -> 비말단 버퍼 22개 -> 말단 버퍼 약 116개 -> FF 1,816개, 3단). 3단계 완료
- [x] PnR 4단계(4_RouteDesign_PowerAnalysis) 완료: verify_drc 0 Viols, verifyConnectivity 0 Viols 0 Wrngs, postRoute setup WNS +0.348 ns(reg2reg +0.348, IO +8.203), hold WNS +0.011 ns(reg2reg +0.054, IO +0.011), DRV 0, Density 61.839%, 정적 전력 0.765 mW(내부 71.6%/스위칭 28.3%/누설 0.06%, 활동 계산 주기 8 ns로 V1과 동일 조건). 배선 상세 확대 캡처 완료. 4단계 완료
- [x] PnR 5단계(ChipFinish) 완료: 필러 총 7,384개(FILL1 2,262/FILL2 2,289/FILL4 1,495/FILL8 668/FILL16 327/FILL32 149/FILL64 194), 필러 후 verify_drc 0 Viols, verifyConnectivity 0 Viols 0 Wrngs, 산출물 .v 0.62 MB/.sdf 3.75 MB/.sdf_2.1 3.72 MB/.sdc 5 KB/.gds 8.1 MB, streamOut 완료(인스턴스 13,198, 핀 15, net 68,073, via 44,191). 캡처 완료
- [x] EC 2회차(합성 vs PnR) PASS: 비교점 PO 8 + DFF 1,816 = 1,824 모두 Equivalent, 입력 7/7, Design ambiguity 1건(V1과 동일), Revised 쪽에만 라이브러리 셀 추가(최상위 22개, u_mcu_top 144개 vs Golden 58개). 캡처 완료
- [ ] 다음: post-route Tempus `5_PNR/tempus.tcl`, post-layout 시뮬(worst/best SDF)
- [ ] PnR 실행 ( 0_InitDesign -> 1_PowerPlan -> 2_PlaceOpt -> 3_PostCTSopt -> 4_RouteDesign_PowerAnalysis -> 5_ChipFinish -> tempus.tcl), 리포트와 캡처
- [ ] 리포트 저장, 비교표 채우기, git 태그 `v1-core`

## 문서
- `docs/SYN_SCRIPT_COMPARISON.md`: Cadence 템플릿(이미지) vs V1 `script/*.tcl` 2개 vs V2 스크립트의 Tcl 수준 비교, cost group/mmmc 차이
- `docs/SYN_FLOW_COMPARISON.md`: Genus 기본 플로우(PDF) vs V1 vs V2 합성 플로우/SDC 상세 비교, 합성 전 체크리스트

## V1 대비 의도된 차이 목록 (패드 제거로 인한 것만, 이 외는 V1과 동일해야 함)
| 영역 | V1 | V2 | 구분 |
|---|---|---|---|
| RTL | mcu_pad_top = 패드 + mcu_top | mcu_core_top = mcu_top (패드 없음, 디버그 출력 미연결) | 패드 제거 |
| 합성 SDC | 패드 dont_touch 15줄, `set_driving_cell PADDI`, `set_load [load_of PADDO/A]` | dont_touch 제거, `set_input_transition 0.1`, `set_load 0.003`(V1 값과 동일) | 패드 관련 대체 |
| 합성 스크립트/EC/pre-layout 시뮬 | 패드 lib/모델 포함 | 패드 lib 제거, 이름 변경, TB DUT를 mcu_core_top으로 | 패드 제거 |
| floorplan | 패드 링 기준 die 1663 um, 여백 352 | 코어 기준 여백 30 um(링 폭에 맞춤), utilization 0.6은 V1과 동일 | 패드 제거 |
| 핀 | 패드(init.io) | `editPin`으로 4변 배치(V1 패드 변 기준) | 패드 제거 |
| 전원 | 안쪽 링 + 바깥 링 + 패드 연결 + 스트라이프 | 코어 링 + 스트라이프(바깥 링, 패드 연결 제거) | 패드 제거 |
| PnR SDC | 합성 SDC 그대로 (ideal network 포트가 패드에 연결) | 합성 SDC에서 `set_ideal_network`(clk, clrn) 2줄 제거한 복사본 | 패드 제거의 결과(clk은 필수, clrn은 V1과 같은 조건으로 맞춘 판단) |
| mmmc view | 패드 lib 포함 | 패드 lib 제거, SDC 경로 변경 | 패드 제거 |
| 그대로 둔 것 | CTS target_skew 0.01, 라우팅/최적화 옵션, 전력 `-period 8.0` 등 | 동일 | - |

## 규칙
- **V2 SDC/스크립트는 V1과 패드 관련 부분만 다르게 한다. 그 외 값(delay, uncertainty, 옵션 등)은 임의로 바꾸지 않는다.**
- 모든 실험은 같은 SDC, 같은 스크립트. 바꾸는 것은 한 번에 하나.
- 수치는 로그 원본과 대조하기 전에는 "확인됨"으로 쓰지 않는다.
- 이 README와 아래 원문 계획서에 어긋나는 작업(범위 밖 RTL 변경 등)은 하기 전에 사용자에게 먼저 묻는다.

## RTL 회귀 (참고)
```
iverilog -g2012 -o tb.vvp -s tb_mcu_top $(ls TOP/1_RTL/*.v | grep -v pad_top) TOP/2_SIM/4_TESTBENCH/tb_mcu_top.v && vvp tb.vvp
```
`PASS tb_mcu_top`이 8645000 ps에서 나와야 한다.

---

# 원문 계획서 (docx 그대로)

자작 MIPS MCU의 RTL-to-GDS 구현과 버전별 개선 실험 (PD/PI 지원용)

작성일 2026.11.18 \| 대상 설계: mcu_pad_top / mcu_top (저장소 proj4_make)

<table>
<colgroup>
<col style="width: 100%" />
</colgroup>
<tbody>
<tr class="odd">
<td><p><strong>한 줄 주제</strong></p>
<p>자작 MIPS MCU를 RTL부터 GDS까지 구현하고, 타이밍 병목을 분석해 버전별로 한 가지씩 개선하며 PPA 변화를 측정하고 해석했다.</p></td>
</tr>
</tbody>
</table>

# 1. 목표와 원칙

**목표**: PD/PI 신입 지원용 포트폴리오. 평가 포인트는 RTL 기능의 화려함이 아니라, 합성부터 PnR과 타이밍 분석까지 직접 다뤘다는 근거와 그 분석 사고 과정이다.

**핵심 흐름**: 병목 찾기 → 가설 → 변경 하나 → 같은 플로우로 재측정 → 왜 그런지 해석. 이 루프를 버전마다 반복한다.

1.  버전마다 바꾸는 것은 한 가지뿐이다. 변경이 둘이면 결과가 어느 쪽 때문인지 구분되지 않는다.

2.  모든 버전은 같은 SDC와 같은 플로우 스크립트로 돌린다. 누가 돌려도 재현되어야 한다.

3.  기대와 다른 결과나 실패도 그대로 기록한다. 원인을 다시 파고든 과정이 더 좋은 자료가 된다.

4.  숫자마다 "왜"를 한 문단으로 설명할 수 있어야 한다. 면접에서는 숫자보다 이유를 묻는다.

# 2. 현재 상태 (v1 완성본)

아래 수치는 "MCU RTL 상세 해설 보고서"에 적힌 값이다. 공개 전에 PnR 로그 원본과 대조해서 확인해야 한다.

| **항목**             | **내용**                                                                                                                                                                      |
|----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| **설계 구성**        | 단일 사이클 MIPS CPU(정수 명령어 20개), 명령어 ROM 256 word(프로그램 내장), 데이터 RAM 32 word(FF 배열), APB 브리지, UART(FIFO·인터럽트), SPI 마스터/슬레이브, 신호 패드 15개 |
| **공정·도구**        | GPDK045, Genus(합성), Conformal(EC), Innovus(PnR), Tempus(STA), xrun(시뮬레이션)                                                                                              |
| **동작 클럭**        | 100 MHz (주기 10 ns)                                                                                                                                                          |
| **합성 면적**        | 코어 21,856 µm² (데이터 RAM 10,493 / UART 5,157 / CPU 4,279)                                                                                                                  |
| **setup 최악 슬랙**  | +0.441 ns. 경로: PC → 명령어 ROM → 32비트 가산기 → 주소 디코더 → UART TX FIFO 쓰기 enable                                                                                     |
| **패드와 floorplan** | 패드 15개가 칩 셀 면적의 약 91%(20 ns 합성 결과). die 1663 µm, 코어 약 479 µm, 셀 밀도 약 10%                                                                                 |
| **클럭 트리**        | sink 1,816개 (합성 후 FF 수와 일치)                                                                                                                                           |
| **프로그램 실행**    | 843 클럭, APB 접근 204회 (대부분 폴링 대기)                                                                                                                                   |
| **검증**             | RTL 시뮬레이션, 합성 후(SDF), PnR 후(SDF, worst/best 코너) 시뮬레이션, 등가성 검사                                                                                            |

# 3. 현재 약점과 대응

| **약점**                                                                                      | **영향**                                              | **대응**                                                      |
|-----------------------------------------------------------------------------------------------|-------------------------------------------------------|---------------------------------------------------------------|
| 슬랙 여유가 작다 (+0.441 ns)                                                                  | 클럭을 얼마나 더 줄일 수 있는지 불명                  | v2, v3에서 병목 구간을 직접 개선하고 클럭 sweep으로 한계 확인 |
| 패드가 면적을 지배, 밀도 약 10%                                                               | congestion, CTS 등 물리 비교의 의미가 약함            | 패드를 뺀 코어 단독 트랙을 실험용으로 추가                    |
| 코어 디버그 출력(pc, inst, aluout, memout 각 32비트)은 패드에 미연결, 합성이 관련 논리를 제거 | 코어를 그대로 최상위로 합성하면 면적과 핀 수가 달라짐 | mcu_pad_top에서 패드만 뺀 얇은 래퍼를 만들어 합성             |
| 프로그램이 ROM에 고정, 레지스터 24개 미사용                                                   | RTL의 792개 FF가 합성에서 제거되어 실제 구현이 작음   | 해석 시 RTL 대비 합성 후 FF 수 차이(2,608 → 1,816)를 명시     |

# 4. 트랙 구조

- **코어 단독 트랙 (실험용)**: 패드 없는 래퍼, utilization 0.6~0.7. 모든 버전 비교는 이 트랙에서 한다.

- **패드 트랙 (완성본)**: v1-pad로 고정해 부록에 둔다. 패드 링, 전원 패드, post-layout SDF 시뮬레이션까지 해낸 증거다. 마지막에 가장 좋은 버전만 패드 포함으로 다시 돌리는 것은 선택.

- 패드 있는 결과와 없는 결과의 슬랙은 직접 비교하지 않는다. 코어 단독 v1을 새 기준선으로 다시 측정한다.

# 5. 버전 계획

| **버전** | **변경 (한 번에 하나)**                                                                                  | **가설**                                                            | **비교 지표**                                             | **우선순위** |
|----------|----------------------------------------------------------------------------------------------------------|---------------------------------------------------------------------|-----------------------------------------------------------|--------------|
| v1       | 패드 없는 코어 단독 기준선 (RTL 변경 없음)                                                               | 병목은 PC→ROM→가산기→디코더→FIFO enable 경로                        | 기준 PPA 전체                                             | 필수         |
| v2       | 32비트 가산기 구조 교체 (CLA 또는 Kogge-Stone)                                                           | 가산기 구간(약 3~4 ns)이 줄어 슬랙이 개선되고 면적은 증가           | 같은 10 ns에서 슬랙, 면적. 클럭 10→8→7 ns에서 깨지는 지점 | 필수         |
| v3       | 주소 디코드 결과를 SETUP 클럭에서 레지스터화 (apb_bridge와 stall 타이밍 수정)                            | ACCESS 경로가 짧아지지만 사이클 수가 늘어나는 trade-off             | 슬랙, 총 실행 클럭(기준 843), 면적                        | 권장         |
| v4       | 전력/면적 축: clock gating 또는 FF 배열 RAM 개선. 시간 부족 시 RTL 변경 없이 utilization, CTS 옵션 sweep | 타이밍 외 축에서도 개선 여지가 있다                                 | 전력, 면적, 클럭 트리(sink, skew, latency)                | 선택         |
| v5       | (선택) SPI에 FIFO 등 추가                                                                                | 기능 추가가 아니라 FF 증가가 면적, 전력, 클럭 트리에 주는 영향 비교 | FF 수, 면적, 전력                                         | 후순위       |

v1과 v2만 완성도 있게 끝내도 지원을 시작할 수 있다. v3, v4는 그 위에 추가한다.

# 6. 공통 지표 비교표 (틀)

모든 버전에 같은 항목을 채운다. 측정 전에는 빈칸으로 둔다.

| **지표**                            | **v1** | **v2** | **v3** | **v4** |
|-------------------------------------|--------|--------|--------|--------|
| **setup WNS / TNS**                 |        |        |        |        |
| **hold WNS / TNS**                  |        |        |        |        |
| **합성 면적**                       |        |        |        |        |
| **PnR 면적 / utilization**          |        |        |        |        |
| **전력**                            |        |        |        |        |
| **클럭 트리 sink / skew / latency** |        |        |        |        |
| **DRC**                             |        |        |        |        |
| **등가성 검사(EC)**                 |        |        |        |        |
| **RTL / 게이트 시뮬레이션 통과**    |        |        |        |        |
| **총 실행 클럭**                    |        |        |        |        |
| **도달한 최소 클럭 주기**           |        |        |        |        |

# 7. 버전 페이지 템플릿

각 버전 페이지는 아래 다섯 칸을 같은 순서로 쓴다.

| **칸**        | **쓸 내용**                                                             |
|---------------|-------------------------------------------------------------------------|
| **가설**      | 무엇이 병목이라고 보았는가, 무엇을 바꾸면 어떻게 될 것이라고 예상했는가 |
| **변경 내용** | 바꾼 파일과 모듈, 바꾸지 않은 것(SDC, 스크립트)                         |
| **결과**      | 공통 지표 비교표의 해당 열과 최악 경로 리포트                           |
| **해석**      | 왜 그런 결과가 나왔는가. 예상과 달랐다면 경로를 다시 뜯어본 과정        |
| **한계**      | 이 실험으로 말할 수 없는 것, 다음에 확인할 것                           |

# 8. 포트폴리오 구성

- **첫 화면(README)**: 한 줄 주제, 버전 × 지표 비교표 하나, 클럭별 슬랙 그래프 하나. 30초 안에 흐름이 보이게 한다.

- **버전별 페이지**: 7장의 다섯 칸 틀. 기존 GitHub Wiki(한국어, 사이드바)에 그대로 붙인다.

- **부록 A**: 패드 포함 완성본(v1-pad)의 합성, PnR, post-layout 시뮬레이션 결과.

- **부록 B**: MCU RTL 상세 해설 보고서 (RTL을 설명할 수 있다는 근거).

# 9. 진행 체크리스트

☐ 합성 넷리스트에서 가산기가 실제로 어떤 구조로 나왔는지 확인한다. RTL의 + 연산자는 Genus가 자체 구조로 바꿀 수 있어서, 이미 빠른 구조라면 v2의 가설이 달라진다.

☐ mcu_pad_top에서 패드만 뺀 래퍼를 작성한다 (디버그 출력은 연결하지 않음).

☐ SDC를 포트 기준 입출력 지연으로 수정하고, floorplan을 수정한다 (utilization 0.6~0.7, 핀 배치, 전원 링/스트라이프).

☐ v1 코어 단독 합성과 PnR을 돌리고 리포트를 저장한다. git 태그 v1-core.

☐ v2: 가산기 RTL 수정 → RTL 시뮬레이션 → 합성 → EC → PnR → 비교표 작성. git 태그 v2.

☐ v2에서 클럭을 10 → 8 → 7 ns로 줄이며 슬랙 변화와 깨지는 지점을 기록한다.

☐ README, 비교표, 슬랙 그래프를 작성한다. 여기까지 되면 지원 시작 가능.

☐ 시간이 남으면 v3, v4를 진행한다.

☐ 공개 전 점검: 라이선스, 미완성 결과 제외, 수치와 로그 대조.

# 10. 결정 사항과 주의사항

| **결정**                            | **이유**                                                                                                                                            |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| cmsdk_mcu 통합은 이번 범위에서 보류 | 코어가 ARM 자산이라 "내가 한 부분"이 흐려지고, 통합 오류 추적에 시간이 들며, 교수님 과제 취지(직접 MCU 설계 + UART/SPI 연결)는 자작 MCU로 이미 충족 |
| 패드는 대체가 아니라 트랙 분리      | 패드 성과는 유지하고, 실험은 의미 있는 밀도에서 하기 위해                                                                                           |
| SPI 기능 추가는 후순위              | 최악 경로가 CPU 쪽이라 SPI를 고쳐도 슬랙 변화가 없을 가능성이 높고, 검증 범위만 늘어남                                                              |
| 기능 추가(타이머 등)는 지양         | 변경이 겹치면 해석이 흐려지고 RTL 설계자 포트폴리오로 기움                                                                                          |

- 공개 저장소에는 ARM DesignStart와 수업 자료(cmsdk 관련)를 올리지 않는다. 필요하면 약관이나 교수님께 확인한다.

- 플로우가 돌아가는 상태까지 끝낸 버전만 공개한다. 미완성은 올리지 않는다.

- 폴리텍이 11월에 종료되므로 v1과 v2를 우선한다. 시간이 빠듯하면 v3 이후를 줄인다.

- 수치는 해설 보고서 기준이므로 로그 원본과 대조하기 전에는 "확인됨"으로 쓰지 않는다.

# 11. 면접 대비 질문

1.  최악 경로가 왜 PC → ROM → 가산기 → 디코더 → FIFO enable이었나? 한 클럭 안에 무엇이 끝나야 하나?

2.  가산기를 바꿨더니 슬랙은 얼마나 좋아졌고, 면적은 왜 늘었나?

3.  setup 슬랙 +0.441 ns는 어느 정도의 여유인가? 클럭을 줄이면 어디서 먼저 깨지나?

4.  패드를 빼면 PnR 결과 해석이 어떻게 달라지나? 왜 두 트랙의 슬랙을 직접 비교하지 않았나?

5.  RTL의 FF 2,608개가 합성 후 1,816개로 줄어든 이유는?

6.  v3에서 경로를 끊었더니 사이클 수는 어떻게 변했고, 그 trade-off를 어떻게 판단했나?
