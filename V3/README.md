# V3: 가산기 구조 교체 (계획서의 v2) — 완료 기록

이 파일은 V3의 **진행 기록이자 인수인계 문서**다. 새 세션은 이 파일부터 끝까지 읽는다. 루트의 `CLAUDE.md`가 이 파일을 가리킨다. 사용자와는 **반말**로 대화한다.
포트폴리오용 정리(가설/결과/해석/한계, 예상 질문, 캡션 모음)는 `V3/V3_portfolio.docx`에 있다.
**다음 작업(PD 실험: 4 ns PnR timing closure, 이용률 sweep)의 순서와 방법은 `V3/PD_실험_계획.md`에 있다.**

---

## 1. 프로젝트 한 줄 요약
자작 MIPS MCU(단일 사이클 CPU, 명령어 ROM, 데이터 RAM, APB 브리지, UART, SPI master/slave)를 GPDK045로 RTL부터 GDS까지 구현하고, 병목을 분석해 **버전마다 한 가지만 바꿔** PPA 변화를 측정/해석하는 PD/PI 신입 지원용 포트폴리오다. 평가 포인트는 RTL이 아니라 합성~PnR~STA를 직접 다뤘다는 근거와 분석 과정이다.
- 도구: Genus 22.17(합성), Conformal(EC), Innovus 22.17(PnR), Tempus 22.17(STA), xrun 22.03(시뮬). **사용자가 학교(폴리텍) 서버에서 직접 실행**한다. 이 클라우드 환경에는 EDA 툴이 없다.
- 기준 계획서: `V2/docs/MCU_계획서_V번호수정본.docx`.

## 2. 버전과 폴더 (번호 = 폴더 번호)
| 폴더 | 내용 | 상태 | git 태그 |
|---|---|---|---|
| `V1` | 패드 포함 칩 레벨 완성본 (`mcu_pad_top`) | 완료 | `v1-pad` |
| `V2` | 패드 없는 코어 단독 기준선 (`mcu_core_top`), RTL 변경 없음 | 완료 | `v2-core` |
| `V3` | 가산기 구조 교체 (계획서의 v2) + 4 ns PnR timing closure(V2/V3) | **완료 (툴 작업 전부, 문서화 진행 중)** | `v3` (사용자가 로컬에서 푸시) |
| `V4` | 주소 디코드 레지스터화 (계획서 v3) | 선택 | `v4` |
| `V5`, `V6` | 전력/면적 축, SPI FIFO | 선택/후순위 | |

## 3. 계획서 핵심 원칙
1. 버전마다 바꾸는 것은 **한 가지**뿐이다.
2. 모든 버전은 같은 SDC, 같은 플로우 스크립트로 돌린다 (클럭 sweep 때만 `create_clock -period` 변경).
3. 기대와 다른 결과나 실패도 그대로 기록한다.
4. 숫자마다 "왜"를 설명할 수 있어야 한다. 로그 원본과 대조 전에는 "확인됨"으로 쓰지 않는다.
5. 패드 있는 결과(V1)와 없는 결과(V2~)의 슬랙/전력은 직접 비교하지 않는다.
6. 버전 페이지 5칸: 가설 / 변경 내용 / 결과 / 해석 / 한계.

---

## 4. V3 범위, 가설, 근거
- **변경 (한 가지):** `V3/TOP/1_RTL/sccpu.v`의 ALU 덧셈/뺄셈을 32비트 Kogge-Stone prefix 가산기(`add32_ks.v`)로 교체. PC+4, 분기 목표 가산, 비교기, SDC, 플로우 옵션은 V2와 동일.
- **가설:** 가산기 구간이 줄어 더 빠른 클럭까지 timing이 닫히고 면적은 늘어난다. 최악 경로가 다른 구간으로 옮겨갈 수 있다.
- **근거 (V2 post-route):** 최악 setup 경로(PC → 명령어 ROM → CPU 디코드/가산기 → 주소 디코드 → UART 레지스터 → TX FIFO)의 데이터 경로 약 9.4 ns 중 가산기가 약 3.2 ns(34%)로 가장 큰 구간이었다.

## 5. 결정 사항 (확정)
| 항목 | 결정 |
|---|---|
| 가산기 구조 | Kogge-Stone (prefix 5단, 간격 1/2/4/8/16), add/sub 공용(`sub = a + ~b + 1`) |
| 합성 sweep | V2와 V3 모두. 10, 4, 3.5, 3 ns로 시작해 통과/실패 경계를 좁힘 (V2 7점, V3 8점) |
| 플로우 깊이 | 합성/EC는 10 ns, PnR/Tempus/게이트 시뮬은 10 ns 한 번 (V2 기준선이 10 ns라 V2 PnR 재실행 없이 비교) |
| 도구 사용 기간 | 사용자 확인: 제약 없음 (넉넉함) |
| 진행 방식 | 가이드 우선. 사용자가 직접 수정/실행하고 Claude는 안내와 해석. 시킨 것만 한다 (`CLAUDE.md`) |

## 6. V2 대비 바뀐 것 (전부 기록)
| 항목 | V2 | V3 | 성격 |
|---|---|---|---|
| `1_RTL/sccpu.v` | `w_a - w_b`, `w_a + w_b` | `w_bx`, `w_sum` 선언, `add32_ks u_add` 인스턴스, 두 분기를 `w_sum`으로 | **실험 변경 (한 가지)** |
| `1_RTL/add32_ks.v` | 없음 | 신규 | 실험 변경 |
| `3_SYN/script/syn_mcu_core_top.tcl` | - | `RTL_SOURCES`에 `../1_RTL/add32_ks.v` 한 줄 | 새 파일 때문에 불가피 |
| `4_EC/script/script.tcl` | - | Golden 목록에 `add32_ks.v` 한 줄 | 새 파일 때문에 불가피 |
| `4_EC/POST/script/script.tcl` | - | 변경 없음 (Golden이 합성 넷리스트) | - |
| `2_SIM/1_FUNCTION/run_function.tcl` | `../TESTBENCH` 경로 | `add32_ks.v` 한 줄 추가, 테스트벤치 경로 `../4_TESTBENCH`(실제 폴더 이름) | 불가피 + 경로 오타 수정 |
| `5_PNR/mcu_core_top.mmmc.view` | `-sdc_files ./mcu_core_top_pnr.sdc` | `-sdc_files ../3_SYN/mapped/mcu_core_top_syn_final.sdc` | **사용자 결정** (아래 참고) |
| `3_SYN/mapped/mcu_core_top_syn_final.sdc` | (V2도 같은 흔적) | 61, 62번 줄 `#set_ideal_network [get_ports clk/clrn]` 주석 처리 | 사용자 결정 |

**4 ns PnR 실험에서 추가된 것 (V3, 저장소):**
| 위치 | 내용 |
|---|---|
| `5_PNR/4ns/` | 10 ns `5_PNR` 스크립트 복사본. 다른 점은 `0_InitDesign.tcl` 9번 줄 `init_verilog ../../3_SYN/4ns/mapped/...`, `mcu_core_top.mmmc.view` 73번 줄 `-sdc_files ../../3_SYN/4ns/mapped/...sdc` 두 줄뿐 |
| `3_SYN/4ns/mapped/mcu_core_top_syn_final.sdc` | 61, 62번 줄 ideal 두 줄 주석 처리 (10 ns와 같은 방식) |
| `4_EC/POST/4ns/script.tcl` | Golden `../../../3_SYN/4ns/mapped/...`, Revised `../../../5_PNR/4ns/mcu_core_top.v` |

V2 4 ns는 서버 `~/sweep_v2/`(저장소 밖)에서 V3 `5_PNR/4ns` 스크립트를 그대로 복사해 실행했다 (`~/sweep_v2/3_SYN/4ns/mapped/` SDC의 ideal 두 줄도 주석 처리). 수동 ECO 스크립트(`6_ECO_manual.tcl`, 교수님 `6_ECO.tcl` 구조에서 `innovus.eco`/`optDesign` 제거, `ecoChangeCell` + `refinePlace` + `ecoRoute` + `extractRC`, 분석 모드 bcwc)와 ECO 후 산출물(`*_ECO.*`, `RouteDesign_ECO.dat`, `ChipFinish_ECO.dat`)도 서버에만 있다. V2 4 ns 수치는 **사용자 캡처 기준**이다.

**PnR SDC 처리 (중요):** V2는 합성 SDC에서 ideal 두 줄을 뺀 사본 `5_PNR/mcu_core_top_pnr.sdc`를 읽었다. V3는 사본을 만들지 않고 mmmc가 합성 결과 SDC를 직접 읽게 바꾸고, 그 파일에서 ideal 두 줄을 주석 처리했다. **적용된 제약은 V2와 같다** (주기 10 ns, clk/clrn ideal 없음, Innovus SDC 경고 3개도 V2와 같음, CTS 버퍼 141개로 정상). 단, 이 방식은 **합성을 다시 돌리면 `mapped/`의 SDC가 덮어써져 ideal 줄이 살아난다.** 재합성 후 PnR을 하면 반드시 두 줄을 다시 주석 처리하거나 V2 방식(PnR용 사본)으로 돌아가야 한다. `3_SYN/10ns/mapped/`에는 원본(ideal 줄 있음)이 남아 있다.

## 7. RTL 변경과 검증 (완료)
- `add32_ks.v`: 비트별 `p = a^b`, `g = a&b`(cin은 비트 0의 g에 합침), prefix 5단, `sum = p ^ {G[30:0], cin}`.
- `sccpu.v`: `w_bx = w_sub ? ~w_b : w_b`, `add32_ks u_add (.a(w_a), .b(w_bx), .cin(w_sub), .sum(w_sum))`, sub(164번 줄)와 add/addi/lw/sw(172번 줄)가 `w_sum`.
- 검증 (iverilog, 이 환경): 가산기 단독 랜덤 200,000건(0, 0xFFFFFFFF 코너 포함) `+`/`-`와 일치. RTL 회귀 `PASS tb_mcu_top` 8645 ns (V2와 같음). 테스트벤치는 저장소에 올리지 않음.
- 서버 xrun 기능 시뮬: PASS, 8645 ns, RAM[0..3]=0x37/0x41/0x3C/0xA5, pc 0xAC, APB 접근 204회. `u_add` 파형으로 add 값 확인. 프로그램에 `sub` 명령이 없어 `cin`은 항상 0 (sub는 단독 테스트로 검증).
- 총 실행 클럭: 테스트벤치 `cyc` 기준 **842** (V2도 iverilog로 같은 기준에서 842). README/계획서의 843은 V1에서 다른 기준으로 센 값으로 추정, 미확인.

---

## 8. 플로우와 실행 방법 (V3에서 실제로 쓴 것)
경로 기준은 `V3/TOP/`.
| 단계 | 위치 | 명령 |
|---|---|---|
| RTL 회귀 | (이 환경) | `iverilog -g2012 -o tb.vvp -s tb_mcu_top $(ls 1_RTL/*.v) 2_SIM/4_TESTBENCH/tb_mcu_top.v && vvp tb.vvp` |
| 기능 시뮬 | `2_SIM/1_FUNCTION` | `./run_function.tcl` |
| 합성 | `3_SYN` | `./run_synthesis` (10 ns 약 3분 47초, 빡빡한 주기는 10~15분) |
| sweep | `3_SYN` | `cons/mcu_core_top.sdc` 17번 줄 주기만 변경 → 합성 → 바로 `<주기>/`에 `report mapped log fv` 백업 (예: `3p75ns`). 끝나면 주기를 10으로 되돌림 |
| V2 sweep | 서버 `~/sweep_v2/` | V2의 `1_RTL`, `3_SYN` 스크립트를 복사해서 실행 (V2 원본 폴더는 건드리지 않음). 10 ns 재현 결과가 V2 원본과 완전히 같음을 확인 |
| EC (RTL ↔ 합성) | `4_EC` | `mkdir -p log`, `lec`, `dofile ./script/script.tcl` |
| pre-layout 시뮬 | `2_SIM/2_PRE` | `mkdir -p dump`, `./run_pre.tcl` (`3_SYN/mapped/`가 10 ns 결과인지 먼저 확인) |
| PnR | `5_PNR` | `innovus -files 0_InitDesign.tcl` 후 같은 세션에서 `source 1_...` ~ `5_ChipFinish.tcl`. 3단계 전 `mkdir -p reports/clock reports/timing` |
| EC (합성 ↔ PnR) | `4_EC/POST` | `mkdir -p log`, `lec`, `dofile ./script/script.tcl` |
| Tempus | `5_PNR` | `tempus` 후 명령 직접 입력: `read_design RouteDesign.dat mcu_core_top`, `check_timing`, `report_annotated_parasitics`, `report_analysis_coverage`, `report_timing -late/-early -max_paths 1`, `write_sdf -view FUNC_SS_WORST/FUNC_FF_BEST ...` (`tempus.tcl`은 끝에 `exit`이 있음) |
| post-layout 시뮬 | `2_SIM/3_POST/max`, `min` | `mkdir -p dump`, `./run_post_max.tcl`, `./run_post_min.tcl` |

순서 메모: `tempus.tcl`은 `RouteDesign.dat`을 읽는다. 원래 의도는 배선 → Tempus → (위반 시 ECO) → ChipFinish이지만, V2/V3 모두 위반이 없어 ChipFinish 뒤에 Tempus를 돌렸다. 필러는 타이밍 경로가 없어 결과는 같다 (Tempus = Innovus postRoute로 확인).

## 9. 함정 (V2에서 겪은 것 + V3에서 새로 겪은 것)
1. **ideal network → CTS 버퍼 0개.** V3는 6장의 방식으로 해결 (재합성 시 주의).
2. `clean.tcl`은 `sh clean.tcl`로 실행.
3. EC/시뮬 `log`, `dump` 폴더는 미리 `mkdir -p`.
4. **SDF 적용률 확인 필수** (V1 0.17% 사고). RECREM/REMOVAL 외 미적용 0, 에러 0, 경로 지연 약 90% 이상.
5. 전력 계산 주기는 `-period 8.0` 유지, 캡션에 "8 ns 기준".
6. Tempus `Design Mode: 65nm` 표시 (스크립트에 `setDesignMode -process` 없음, V1/V2와 같음).
7. main 푸시 전 `git fetch` 후 병합.
8. (V3 신규) **sweep 후 `3_SYN/mapped/`에는 마지막 주기 결과가 남는다.** pre-sim/PnR 전에 `10ns/mapped`로 복원하고 `grep create_clock`으로 확인.
9. (V3 신규) **같은 `3_SYN`에서 두 주기를 동시에 돌리지 않는다** (report/mapped/SDC가 하나). V2와 V3는 폴더가 달라 동시 실행 가능.
10. (V3 신규) `gui_dump_picture snap/...`는 `snap/` 폴더가 없으면 EMS-19 에러(설계 에러 아님).
11. (V3 신규) 합성 sweep 결과는 주기에 단조롭지 않다 (V3 3.95 ns가 3.9 ns보다 slack이 나쁨). "통과한 최소 주기"는 측정한 점 기준이다.

---

## 10. V2 기준선 (비교 대상, V2 README에서 로그 확인된 값)
합성 10 ns slack +1.2 ps, 셀 면적 21,819.258 µm², FF 1,816 / EC 두 번 PASS / die 251.6 × 249.85 µm, 코어 191.6 × 189.81 µm / postRoute setup +0.348 ns, hold +0.011 ns / 클럭 버퍼 138, skew 0.097/0.039 ns, 삽입 지연 0.477 ns / Density 61.839% / 정적 전력 0.765 mW / 필러 7,384 / Tempus +0.347/+0.011 ns, real net 5,906개 100% / post-sim worst +0.941/+0.891 ns, best +0.241/+0.22 ns, 경로 지연 91.56%.

## 11. 진행 기록 (모든 값은 `V3/TOP` 로그와 대조 완료, 예외는 표시)
- [x] 결정 확정 (5장)
- [x] RTL 수정, iverilog 검증 (가산기 단독 200,000건, 회귀 PASS 8645 ns)
- [x] 기능 시뮬(xrun) PASS 8645 ns (`2_SIM/1_FUNCTION/func_sim.log`). 캡처 완료
- [x] 합성 10 ns: slack +1.8 ps, TNS 0, 셀 면적 22,019.670 µm²(V2 대비 +200.4, +0.92%), 인스턴스 5,243, FF 1,816, 계층 25(`u_add` 추가). `sccpu` 4,404.276 µm²(`u_add` 386.118 µm², 137셀), `scinstmem` 376.542 µm²(V2 315.324, RTL 미변경인데 증가, 원인 미확인). 최악 경로 `r_pc_reg_8 → uut5/uut2/r_count_reg_4`, 데이터 경로 9,789 ps, 그중 `u_add` 약 3.9 ns(경로상 셀 43개, NOR 계열 ripple 형태). ADDFX1 7 / ADDHX1 80 (V2 6/51). 합성 전력 0.6153 mW(참고용). check_design Unresolved 0, Unloaded Combinational Pin 3→4(원인 미확인). 스키매틱(최악 경로 하이라이트, `u_add` 앞/끝) 캡처 완료
- [x] EC (RTL ↔ 합성) PASS: 입력 7, 출력 8, FF 1,816 Equivalent, Golden 전용 792(Extra 32 + Unreachable 760), Design ambiguity 1 (V2와 동일)
- [x] 합성 sweep (V2, V3): 13장. 통과 최소 주기 **V2 3.9 ns, V3 3.97 ns**
- [x] pre-layout 시뮬 PASS 8645 ns: 첫 UARTTXD 하강 +0.83 ns, 첫 SCLK 상승 +0.36 ns (V2와 동일). SDF 미적용 488건 모두 REMOVAL, 에러 0. 넷리스트 `u_add` 파형 확인
- [x] PnR 0단계: die 251.8 × 251.56 µm, 코어 191.8 × 191.52 µm(36,734 µm², V2 +1.0%), 셀 5,243 / 22,019.67 µm², prePlace WNS +3.371 ns, Density 59.944%
- [x] PnR 1단계: 링 1쌍 + 스트라이프, verify_drc 0, verifyConnectivity 0/0, 저장 0 warning 0 error
- [x] PnR 2단계: 배치 5,230, 밀도 59.88%, 혼잡도 2.2%H/3.9%V Overflow 0, **preCTS setup −0.016 ns(reg2reg 1개 위반, V2 +0.399)**, DRV 0, Density 60.563%, 저장 0/0
- [x] PnR 3단계: CTS 직후 +0.039 ns(위반 해소), 클럭 버퍼 141 / 인버터 1, sink 1,816, skew setup 0.084 / hold 0.029 ns, 삽입 지연 평균 0.470 ns, 최적화 후 setup +0.091 ns(V2 +0.275), hold +0.001 ns(reg2reg 0.054), Density 61.753%
- [x] PnR 4단계: postRoute setup **+0.341 ns**(IO 8.229), hold **+0.009 ns**(reg2reg 0.053), DRV 0, verify_drc 0, verifyConnectivity 0/0, 정적 전력 **0.694 mW**(내부 0.512 / 스위칭 0.182 / 누설 0.00046, 활동 0.2, 8 ns 기준)
- [x] PnR 5단계: 필러 7,411개(FILL64 201 / 32 151 / 16 343 / 8 660 / 4 1,442 / 2 2,234 / 1 2,380), 필러 후 DRC 0, 연결성 0/0, streamOut 인스턴스 13,366, 핀 15, 신호 배선 도형 69,176, via 45,097. 산출물(ls -lh) .v 597K, .sdf 3.6M ×2, .sdc 5.2K, .gds 7.9M
- [x] EC (합성 ↔ PnR) PASS: 1,824(PO 8 + DFF 1,816) Equivalent, black box 0
- [x] Tempus: setup +0.341 ns(`r_pc_reg_8 → uut5/uut2/r_mem_reg_2_4/E`, `u_add` 셀 44개 약 3.98 ns = 데이터 경로의 42.7%), hold +0.009 ns(`SPIMISO → uut6/uut3/r_miso_s1_reg`, FE_PHC 버퍼 5개), Setup/Hold 3,144/3,144 Met, real net 6,077개 100% annotated, no_drive 14. SDF worst/best 생성(SDF-808 경고, V2와 동일)
- [x] post-layout 시뮬 worst/best PASS 8645 ns: 첫 UARTTXD 하강 worst +1.042 / best +0.262 ns, 첫 SCLK 상승 worst +0.861 / best +0.221 ns. 경로 지연 91.64%(14,768/16,116), 체크 82.30%, RECREM 외 미적용 0, 에러 0, MTM MAXIMUM/MINIMUM 확인. `u_add` 파형 확인
- [x] **4 ns PnR (V3, `5_PNR/4ns`)**: 기본 플로우로 통과. postRoute setup +0.006 / hold +0.012 ns, Tempus setup +0.009 / hold +0.012 ns, EC PASS(1,802). 13-2장
- [x] **4 ns PnR (V2, 서버 `~/sweep_v2`)**: 기본 플로우 postRoute setup −0.001 ns(1개) → 수동 ECO 셀 1개 교체로 Tempus +0.010 ns, EC PASS(1,824). 13-2장, 13-3장 (캡처 기준)
- [ ] 버전 페이지 5칸 최종본, 슬랙-주기 그래프 (초안: `V3/V3_portfolio.docx`, 4 ns 결과 미반영)
- [ ] 저장소 정리 (흔적 파일 `5_PNR/.tempus.tcl.swp`, `4_EC/POST/log/all.log~`, 용량 약 188 MB 중 sweep 백업 처리 결정)
- [ ] 태그 `v3` (사용자 로컬에서)

## 12. 비교표 (10 ns, PnR까지)
| 지표 | V2 | V3 | 차이 |
|---|---|---|---|
| 합성 slack / 셀 면적 | +1.2 ps / 21,819.258 µm² | +1.8 ps / 22,019.670 µm² | 면적 +0.92% |
| 합성 `sccpu` 면적 | 4,275.000 µm² | 4,404.276 µm² (`u_add` 386.118) | +3.0% |
| 통과 최소 클럭 주기 (합성) | **3.9 ns** | **3.97 ns** | V2가 약 1.8% 빠름 |
| 코어 면적 / Density(필러 전) | 36,368 µm² / 61.839% | 36,734 µm² / 61.753% | +1.0% |
| postRoute setup WNS / TNS | +0.348 ns / 0 | +0.341 ns / 0 | −0.007 ns |
| postRoute hold WNS / TNS | +0.011 ns / 0 | +0.009 ns / 0 | −0.002 ns |
| 클럭 트리 버퍼 / sink | 138 / 1,816 | 141 / 1,816 | +3 |
| skew setup / hold, 삽입 지연 | 0.097 / 0.039 ns, 0.477 ns | 0.084 / 0.029 ns, 0.470 ns | 비슷 |
| 정적 전력 (0.2, 8 ns 기준) | 0.765 mW | 0.694 mW | −9.2% (해석 주의, 14장) |
| DRC / 연결성 | 0 / 0 | 0 / 0 | 같음 |
| EC (RTL↔합성, 합성↔PnR) | PASS / PASS | PASS / PASS | 같음 |
| 필러 | 7,384 | 7,411 | +27 |
| RTL / pre / post(worst, best) 시뮬 | PASS | PASS | 같음 |
| 총 실행 클럭 (테스트벤치 `cyc`) | 842 | 842 | 같음 |

## 13. 합성 sweep 결과
V3 값은 `V3/TOP/3_SYN/<주기>/report`에서 대조. V2 값은 서버 `~/sweep_v2/`의 리포트 캡처 기준(저장소에 없음).
| 주기 (ns) | V2 slack (ps) | V3 slack (ps) | V2 셀 면적 | V3 셀 면적 | V2 경로 지연 | V3 경로 지연 | V3 경로상 `u_add` 셀 / 구간 |
|---|---|---|---|---|---|---|---|
| 10 | +1.2 | +1.8 | 21,819.258 | 22,019.670 | 9,790 | 9,789 | 43 / 약 3.90 ns |
| 4.0 | **0.0 통과** | **0.0 통과** | 28,783.746 | 30,989.304 | 3,787 | 3,852 | 7 / 0.885 ns |
| 3.97 | - | **0.0 통과** | - | 31,531.032 | - | 3,735 | 0 (경로가 시프터를 지남) |
| 3.95 | - | −45.9 | - | 32,413.392 | - | 3,847 | 14 / 0.892 ns |
| 3.9 | **0.0 통과** | −16.3 | 29,101.806 | 33,732.144 | 3,697 | 3,775 | 12 / 0.866 ns |
| 3.85 | −20.6 | - | 31,540.608 | - | 3,670 | - | - |
| 3.75 | −53.6 | −228.8 | 32,509.836 | 34,234.200 | 3,665 | 3,840 | 12 / 0.823 ns |
| 3.5 | −257.3 | −445.3 | 33,870.996 | 35,582.022 | 3,548 | 3,807 | 13 / 0.877 ns |
| 3.0 | −1,095.8 | −946.3 | 45,818.766 | 33,741.378 | 3,961 | 3,808 | 14 / 0.916 ns |

- V3 FF는 10 ns 1,816, 4 ns 이하 1,794 (22개 감소, 원인 미확인). V2는 3 ns에서만 2,072 (원인 미확인).
- 경로 지연 구간 분해와 주기별 정리는 `V3/V3_portfolio.docx`.

## 13-2. 4 ns PnR (timing closure 실험)
목적: 합성 기준 통과 주기를 PnR/사인오프 기준으로 확인하고 closure 과정을 기록. 두 버전 모두 합성에서 통과한 가장 빠른 공통 주기 4 ns. 스크립트와 옵션은 10 ns와 같고 입력 경로만 다르다. V3 값은 `V3/TOP/5_PNR/4ns` 로그와 대조, V2 값은 캡처 기준.

**단계별 setup WNS (SS_WORST)**
| 단계 | V3 4 ns | V2 4 ns | (참고) V3 10 ns |
|---|---|---|---|
| 합성 | 0.0 ps | 0.0 ps | +1.8 ps |
| prePlace | +0.563 ns | +0.548 ns | +3.371 ns |
| preCTS | **−0.103 ns, 위반 988 / TNS −34.570** | **−0.110 ns, 위반 551 / TNS −26.650** | −0.016 ns, 위반 1 |
| CTS 직후 | −0.001 ns, 위반 1 | +0.001 ns, 위반 0 | +0.039 ns |
| CTS 후 최적화 (setup / hold) | −0.001 ns(2개) / +0.002 ns | 0.000 ns(max_tran 1 net −0.019) / +0.002 ns | +0.091 / +0.001 ns |
| **postRoute (setup / hold)** | **+0.006 / +0.012 ns** | **−0.001 ns(1개) / +0.006 ns** | +0.341 / +0.009 ns |
| 수동 ECO 후 | - | **+0.010 / +0.006 ns** | - |
| **Tempus (setup / hold)** | **+0.009 / +0.012 ns** | **+0.010 / +0.006 ns (ECO 후)** | +0.341 / +0.009 ns |

**물리/전력 비교 (4 ns)**
| 지표 | V3 4 ns | V2 4 ns |
|---|---|---|
| 넷리스트 셀 / 셀 면적 | 7,549 / 30,989.30 µm² | 6,752 / 28,783.75 µm² |
| die / 코어 | 289.0 × 285.76 µm / 51,689 µm² | 279.2 × 278.92 µm / 47,978 µm² |
| 배치 셀 (placeDesign 직후) / Density 최종 | 7,274 / 56.473% | - / 54.821% |
| 혼잡도 Usage, Overflow | 2.4% H, 4.0% V, 0 | 2.2% H, 3.7% V, 0 |
| 세로 스트라이프 (Metal10) | 5쌍 (10 ns 4쌍) | (GUI 미확인) |
| 클럭 버퍼 / sink / 최대 배선 길이 | 139 / 1,794 / 272.11 µm | 141 / 1,816 / 272.68 µm |
| skew setup / hold, 삽입 지연 평균 | 0.102 / 0.050 ns, 0.496 ns | 0.098 / 0.045 ns, 0.486 ns |
| 정적 전력 (입력 활동 0.2, 클럭 4 ns) | 2.064 mW | 1.866 mW |
| 필러 / 신호 배선 최상위층 | 10,170 / Metal8 | 9,272 / Metal6 |
| streamOut 인스턴스 (로직 셀 계산) | 18,111 (7,941) | 16,338 (7,066), ECO 후 |
| Tempus Setup/Hold 체크 | 2,994 / 2,994 Met | 3,016 / 3,016 Met (ECO 후), real net 8,141(V3) 100% |
| EC 합성 ↔ PnR | PASS 1,802 (8 + 1,794) | PASS 1,824 (8 + 1,816), ECO 후 넷리스트 |
| DRC / 연결성 (전 단계) | 0 / 0 | 0 / 0 |

**최악 경로 변화 (V3 4 ns)**
| 단계 | 최악 경로 | 비고 |
|---|---|---|
| 합성 | `r_pc_reg_8` → … → TX FIFO `r_mem_reg_8_7` | `u_add` 7셀 0.885 ns |
| preCTS | `r_pc_reg_4` → ROM → CPU → **RAM(`uut3`) → 레지스터 파일 `r_regs_reg_9_25`** | `u_add` 없음, RAM 구간 0.984 ns. 상위 10개 중 7개 레지스터 파일 |
| postCTS | `r_pc_reg_8` → … → `r_regs_reg_13_25` (−0.001) | 상위 10개 중 2개만 위반 |
| Tempus 최종 | `r_pc_reg_8` → ROM → CPU 디코드 → **`u_add`(11셀 0.809 ns, 21.3%)** → 주소 디코드 → UART 레지스터 → RX FIFO `r_rptr_reg_3` | launch 0.356 / capture 0.369 ns. 상위 10개: FIFO 7, 레지스터 파일 3 |

- 배치 직후 위반이 넓고 얕게(평균 약 −35 ps) 퍼졌다가 CTS(`ccopt_design`의 데이터 경로 최적화/useful skew, 추정)에서 거의 해소되고 배선 후 최적화로 닫혔다.
- 배치 후 셀 면적이 넷리스트보다 약 8.8% 줄었다(V3 Density 54.669% × 51,689 ≈ 28,258 µm²). 원인 미확인.
- hold: V3 최악은 `SPIMISO → uut6/uut3/r_miso_s1_reg`(FE_PHC 6개), V2 최악은 리셋 removal `clrn → uut5/uut2/r_wptr_reg_1/RN`(async_default, FE_PHC 8개).
- 전력은 입력 활동 주기 8 ns 고정이지만 클럭은 4 ns로 토글하므로 10 ns 결과와 직접 비교하지 않는다 (같은 4 ns끼리만 비교).
- Tempus와 Innovus 차이: V3 setup +0.009 vs +0.006 ns(3 ps, 원인 미확인), hold는 일치.
- 4 ns 게이트 시뮬은 하지 않았다 (테스트벤치 `CLK_PERIOD=10`, `UART_BIT=640` 고정. STA와 EC로 확인).

## 13-3. V2 4 ns 수동 ECO (closure)
| 단계 | 내용 |
|---|---|
| 문제 | postRoute setup −0.001 ns, Tempus −0.000 ns(Required = Arrival 4.179 ns), Setup 3,015/3,016 Met. 2위 경로 +0.010 ns |
| 분석 | 위반 경로 `r_pc_reg_5` → ROM(0.567) → CPU 디코드(0.706) → 주소 가산기(0.473) → **RAM 읽기(1.005, 26.5%)** → `w_ram_out` 선택 → 레지스터 파일 `uut1/r_regs_reg_12_15/D`. 데이터 경로 3.789 ns |
| 선택 | 끝점 직전 셀 `u_mcu_top/uut1/g28776__4733` OAI2BB2XL(가장 약한 크기, 0.148 ns). 해당 FF만 구동해 다른 경로 영향이 작음 |
| 수정 | `ecoChangeCell -cell OAI2BB2X1` → `refinePlace`(인접 INVX1 1개 0.20 µm 이동) → `ecoRoute` → `extractRC`. `optDesign` 미사용 |
| 결과 | 셀 지연 0.148 → 0.125 ns(−23 ps), FF setup 요구 0.094 → 0.079 ns(−15 ps), 해당 경로 slack +0.037 ns. 최악 경로는 기존 2위 TX FIFO `r_mem_reg_8_5`(+0.010 ns)로 이동, 상위 5개(+0.010/+0.013/+0.022/+0.024/+0.032) 나머지 값 변화 없음 |
| 검증 | Tempus Setup 3,016/3,016 Met, hold/removal +0.006 ns 변화 없음, DRC 0, 연결성 0, 필러 9,272(ECO 전과 같음), EC PASS 1,824. 셀 위치 (153.0, 163.4) µm |
| 산출물 | `mcu_core_top_ECO.v` 685K, `.sdf` 4.0M, `.sdf_2.1` 3.9M, `.sdc` 5.2K, `.gds` 8.8M (ls -lh) |

## 14. 해석과 결론
- **가설(더 빠른 클럭까지 닫힌다)은 지지되지 않았다.** 통과 최소 주기는 V2 3.9 ns, V3 3.97 ns로 V3가 약간 느리고, 같은 주기에서 면적은 V3가 크다(4 ns +7.7%, 3.9 ns +15.9%).
- **이유: Genus가 RTL 가산기 구조를 유지하지 않고 타이밍 제약에 맞게 다시 만든다.** 10 ns에서는 Kogge-Stone로 짠 `u_add`가 면적을 줄이는 ripple 형태(경로상 43셀, 약 3.9 ns)로 합성되었고 PnR/Tempus 후에도 유지되었다(44셀, 3.98 ns). 빡빡한 주기에서는 얕은 구조(7~14셀, 약 0.8~0.9 ns)로 바뀌었다. V2의 `+`/`-`도 툴이 같은 방식으로 최적화하므로 RTL 수준의 구조 지정은 이점이 없었다. 3.75 ns에서 CPU 구간 지연은 V2 1,667 ps, V3 1,668 ps로 같았다.
- **가설의 다른 부분(최악 경로 이동)은 관찰되었다.** V3 한계 주기(3.97 ns)에서 최악 경로가 `u_add`가 아닌 시프터(`sll`)를 지났다. 빡빡한 주기에서는 끝점이 TX FIFO 카운터에서 FIFO 메모리(`r_mem_reg`)로 옮겨갔다.
- **10 ns PnR에서는 차이가 거의 없다.** setup −0.007 ns, hold −0.002 ns, 코어 면적 +1.0%. CTS 후 최적화 단계에서만 V3 setup 여유가 0.184 ns 작았고 배선 후 최적화에서 따라잡았다.
- **전력 −9.2%는 실제 이득으로 해석하지 않는다.** 벡터 없이 입력 활동도 0.2를 전파한 정적 분석이라 논리 구조가 바뀌면 추정 활동도가 달라진다. 합성 단계에서도 V3가 4.4% 낮았다(같은 경향). 같은 4 ns PnR에서는 반대로 V3가 10.6% 높았다(셀이 7.7% 많음).
- **4 ns PnR: 두 버전 모두 사인오프 기준으로 닫혔다.** V3는 기본 플로우로(+0.009 ns), V2는 기본 플로우에서 1 ps 미달 후 수동 ECO 셀 1개로(+0.010 ns). 차이가 1 ps 수준이라 버전 간 우열이 아니라 **둘 다 4 ns가 한계 근처**라고 해석한다. 같은 4 ns에서 V3는 면적 +7.7%, 코어 +7.7%, 전력 +10.6%로 가산기 변경의 비용만 남았다.
- **4 ns 병목은 한 경로가 아니다.** RAM 읽기 → 레지스터 파일 계열과 ROM → CPU → 주소 디코드 → UART FIFO 계열이 경계에서 경쟁한다(배치 직후에는 전자, 최종에는 후자가 1위). 다음 개선 대상은 가산기가 아니라 이 경로들(CPU-RAM 배치 제약, RAM 출력 파이프라인 = 계획서 V4 성격)이다.

## 15. 한계 (문서에 그대로 기록)
1. 합성 결과가 주기에 단조롭지 않아(V3 3.95 실패, 3.97 통과) 통과 최소 주기는 측정한 점 기준이다. 실패한 주기끼리의 면적 비교는 신뢰도가 낮다(예: 3.5 ns에서 RTL 미변경 RAM 면적 차이가 가장 큼).
2. 합성 통과 주기(3.9/3.97 ns)는 합성 기준이다. PnR은 10 ns와 4 ns에서 했고, 4 ns는 두 버전 모두 사인오프 통과(V2는 수동 ECO 1회). PnR 기준 최소 주기를 더 좁히지는 않았다.
10. 4 ns: 게이트 시뮬 미실시(STA+EC로 확인), V2 값은 캡처 기준(로그는 서버에만), V2는 ECO 적용으로 V3와 플로우가 1단계 다르다, 정적 전력의 클럭 주기가 10 ns와 달라 직접 비교 불가, Innovus 로그 Design Mode 표시가 90nm(ECO 세션)/65nm(Tempus)로 공정 설정 없음.
3. V2 sweep 값은 서버 리포트 캡처 기준이다 (10 ns 재현 결과가 V2 원본과 완전히 같아 복사본 신뢰성은 확인).
4. 전력은 정적 분석(활동 0.2, 8 ns 기준)이다.
5. 테스트 프로그램에 `sub`가 없어 시뮬에서 `cin=1` 경로는 단독 랜덤 테스트로만 검증했다.
6. IO hold 여유가 +0.009 ns로 얇다 (입력 지연 최소 0.01 ns 조건, FE_PHC 버퍼로 확보).
7. Tempus `Design Mode: 65nm`, SDF-808(같은 핀 쌍 arc에 같은 지연), ECO 없이 ChipFinish 후 RouteDesign 기준 STA (모두 V2와 같은 조건).
8. PnR SDC를 mmmc 직접 참조 + 합성 SDC 주석 처리 방식으로 바꿨다 (6장). 적용 제약은 V2와 같다.
9. 원인 미확인 항목: 합성 10 ns `scinstmem` +61 µm², Unloaded Combinational Pin +1, 4 ns 이하 V3 FF 1,794개.

---

## 16. 캡처, 캡션, 문서화 방식
- 사용자가 로그/캡처를 올리면 Claude가 값을 읽어 기대값/V2와 대조하고 한국어 캡션을 준다. 캡처 가이드와 캡션은 채팅으로 준다.
- 기대와 다르거나 설명 못 하는 값은 숨기지 않고 "원인 확인하지 못했다", 추정은 "추정"으로 표시.
- V3 캡처 문서(사용자 작성): `3_SYN_V3.docx` 등. 캡션 모음은 `V3/V3_portfolio.docx` 부록.

## 17. 미해결 / 후속
- V1 PPT 정정 항목 (V2 README 참고: 보레이트 카운터 → TX FIFO 카운터, SDC 서술 불일치, RCA 서술, 캡션 1.15 ns 불일치).
- 공개 전 점검: 로그에 서버/계정 이름(`kopo-seongnam`, `/home/hah013`), 큰 산출물(GDS, SDF, `.dat`, sweep 백업), ARM/cmsdk 파일 제외.
- 선택 실험(별도 버전으로만): 이용률 sweep(`V3/PD_실험_계획.md` 2장, 폴더 이름 사용자 확인 필요), `interconnect_mode ple`, `setDesignMode -process`.
- `V3/PD_실험_계획.md` 1장 체크리스트는 아직 갱신 안 함 (4 ns 폴더 이름도 실제는 `5_PNR/4ns`).
- 저장소 흔적: `4_EC/POST/4ns/script.tcl`은 `script/` 하위가 아닌 폴더 바로 아래에 있고, 4 ns EC 로그는 저장소에 없다(결과는 캡처).

## 18. 사용자 선호 / 작업 방식 메모
- **가이드 우선:** 사용자가 직접 수정한다. 지시 전에는 어떤 파일도 수정/생성하지 않고, 파일과 위치, 변경 내용만 안내한다. **시킨 것만 한다:** 요청한 파일과 범위 밖은 발견해도 고치지 않고 위치와 이유만 알린다 (루트 `CLAUDE.md`에도 동일).
- 대화는 반말. 결론 먼저, 표로 정리. 불확실한 것은 불확실하다고 말하기.
- PD/PI 포트폴리오가 목적이다. 필요 이상으로 실험을 늘리지 않는다 (sweep을 촘촘하게 끌고 가지 말 것).
- 사용자가 main에 직접 커밋한다. main 푸시는 요청할 때만, 푸시 전 `git fetch` 후 병합.
