# V4 작업 지침: 주소 디코드 레지스터화 (새 세션은 이 파일부터 끝까지 읽을 것)

이 파일은 V4의 **인수인계 문서이자 진행 기록**이다. 이전 대화가 없어도 여기만 읽으면 이어갈 수 있게 썼다. 사용자와는 **반말**로 대화한다.
- 기준 계획서: `V2/docs/MCU_계획서_V번호수정본.docx` (5장 V4 항목, 7장 버전 페이지, 8장 비교표).
- 바로 이전 버전(비교 기준) 상세: `V3/README.md`, 전체 결과 정리: `V3/V3_정리.md`.
- 루트 `CLAUDE.md`의 진행 방식(가이드 우선, 시킨 것만 한다)을 그대로 따른다.

---

## 1. 프로젝트 한 줄 요약
자작 MIPS MCU(단일 사이클 CPU, 명령어 ROM, 데이터 RAM, APB 브리지, UART, SPI master/slave)를 GPDK045로 RTL부터 GDS까지 구현하고, **버전마다 한 가지만 바꿔** PPA 변화를 측정/해석하는 PD/PI 신입 지원용 포트폴리오다.
- 도구: Genus 22.17, Conformal, Innovus 22.17, Tempus 22.17, Xcelium 22.03. **사용자가 학교 서버에서 직접 실행**한다. 이 클라우드 환경에는 EDA 툴이 없다 (iverilog만 가능).

## 2. 버전과 폴더
| 폴더 | 내용 | 상태 | git 태그 |
|---|---|---|---|
| `V1` | 패드 포함 완성본 | 완료 | `v1-pad` |
| `V2` | 패드 없는 코어 단독 기준선 | 완료 | `v2-core` |
| `V3` | 가산기 구조 교체(Kogge-Stone) + 4 ns PnR closure | 완료 | `v3` (사용자 로컬) |
| **`V4`** | **주소 디코드 레지스터화 (V3 기반)** | **시작 전** | `v4` |
| `V5`, `V6` | 전력/면적 축(이용률 sweep 등), SPI FIFO | 선택/후순위 | |

## 3. V4 범위, 가설, 기준
- **기준 RTL: V3** (사용자 결정). V4 = V3 RTL(`add32_ks` 포함) + 주소 디코드 레지스터화. 버전을 하나씩 쌓아 가는 그림으로 포트폴리오를 구성하기 위해서다. **비교 대상은 V3**이고, V3 대비 바뀐 것은 디코드 레지스터화 하나뿐이다.
- **변경 (계획서 5장):** 주소 디코드 결과를 레지스터화하고 `apb_bridge`와 stall 타이밍을 수정한다.
- **가설:** APB 접근 경로(ALU → 주소 디코드 → UART 레지스터 → FIFO)가 끊겨 짧아지지만, APB 접근마다 사이클이 하나 늘어나는 trade-off가 생긴다.
- **비교 지표:** 슬랙, 통과 최소 클럭 주기, **총 실행 클럭**, **실행 시간(총 클럭 × 최소 주기)**, 면적, 전력.
- **근거 (V3 결과):**
  - V3 10 ns 최악 경로: `r_pc_reg_8` → ROM → CPU(`u_add`) → **주소 디코드(1.012 ns) → UART 레지스터(0.514) → TX FIFO(1.397)** → `r_count_reg_4`.
  - V3 4 ns Tempus 최악 경로도 같은 계열(… → 주소 디코드 0.469 → UART 레지스터 0.212 → RX FIFO 0.444).
  - 단, 4 ns에서는 **RAM 읽기 → 레지스터 파일 계열**(V2 4 ns 위반 경로, V3 preCTS 최악 경로)도 경계에서 경쟁한다. 이 경로는 V4로 줄지 않는다. 그래서 "클럭은 조금 빨라지지만 사이클 증가를 상쇄하지 못할 수 있다"는 것도 열린 결과로 둔다 (추정).

## 4. 현재 구조 (V3 RTL, 바꾸기 전)
`V3/TOP/1_RTL/mcu_top.v`
| 줄 | 내용 |
|---|---|
| 92~97 | `w_in_apb = (aluout[31:16] == 16'h4000)`, `w_req = w_in_apb & (w_is_lw \| w_wmem)`, `w_psel_uart/spi/slv = w_req & (aluout[15:12] == 0/1/2)` (전부 조합 논리) |
| 128 | RAM 쓰기 enable `w_wmem & ~w_in_apb` |
| 137~144 | `apb_bridge uut4`: `i_req(w_req)`, `o_penable(w_penable)`, `o_stall(w_stall)` |
| 150~200 근처 | 슬레이브 3개: `PSEL(w_psel_*)`, `PENABLE(w_penable)`, `PWRITE(w_wmem)`, `PADDR(aluout[11:2])`, `PWDATA(w_data)` (전부 CPU에서 조합으로 직결) |
| 215 | `memout = w_in_apb ? (w_psel_uart ? w_prdata : w_psel_spi ? ... : 0) : w_ram_out` |

`V3/TOP/1_RTL/apb_bridge.v`: FF 하나(`r_access`). `o_psel = i_req`, `o_penable = i_req & r_access`, `o_stall = i_req & ~r_access`. 접근 1회 = 2클럭(SETUP stall 1 + ACCESS 1).

## 5. 변경 설계 (제안, 사용자가 직접 수정)
APB 접근을 **2클럭 → 3클럭**으로 늘리고 첫 클럭에 디코드 결과를 레지스터로 받는다.
| 클럭 | 상태 | 하는 일 | stall | PSEL | PENABLE |
|---|---|---|---|---|---|
| 1 | DECODE (신규) | `w_req`가 1이 된 첫 클럭. 슬롯 선택(uart/spi/slv), `aluout[11:2]`, `w_data`, `w_wmem`을 레지스터에 저장 | 1 | 0 | 0 |
| 2 | SETUP | PSEL, PADDR, PWDATA, PWRITE를 **레지스터 출력**으로 슬레이브에 | 1 | 1 | 0 |
| 3 | ACCESS | 슬레이브 동작, `lw`면 PRDATA를 CPU로 (CPU 레지스터 파일 기록, PC 진행) | 0 | 1 | 1 |

- 바뀌는 파일: `apb_bridge.v`(상태 2비트 또는 FF 2개), `mcu_top.v`(레지스터 추가, 슬레이브 연결을 레지스터 출력으로, `memout`의 APB 쪽 선택을 레지스터된 슬롯으로). CPU, 슬레이브, 메모리는 그대로.
- RAM `lw`/`sw`는 1클럭 그대로(조합 `w_in_apb` 유지).
- ACCESS 다음 클럭에는 CPU가 다음 명령으로 넘어가므로 브리지는 IDLE로 돌아가야 한다(같은 명령으로 재시작 금지).
- 남는 조합 경로: `stall = w_req & (state != ACCESS)`는 여전히 PC → ROM → ALU → `w_in_apb` → stall → CPU enable로 이어진다. UART/FIFO까지 가는 경로보다는 짧다.
- 실제 코드(상태 인코딩, 레지스터 이름)는 사용자가 정하고, Claude는 요청 시 위치와 코드 예시를 안내한다.

## 6. 테스트벤치 영향 (의도한 변경)
`2_SIM/4_TESTBENCH/tb_mcu_top.v` (`function_sim` 모니터, 165~178번 줄 근처)
- `n_stall`은 `stall && !penable`인 **클럭 수**를 센다. 3클럭 방식에서는 접근당 2가 되어 **`check("stall = penable", n_stall == n_pen)`가 FAIL**한다. 3클럭 기준(예: `n_stall == 2*n_pen`, 또는 stall 상승 에지 수)으로 고쳐야 한다.
- "PENABLE은 1클럭", "PENABLE과 stall 동시 금지" 체크는 그대로 유효하다.
- RAM 4곳, 최종 pc 0xAC, UART 0x41, SPI A5/3C, `info: APB accesses = 204`는 같아야 한다.
- 총 실행 클럭은 테스트벤치 `cyc`(V3 842)로 비교한다. 예상 약 **1,046**(842 + 204, 계산값). 표시가 필요하면 `cyc`를 출력하는 줄을 추가.
- 테스트벤치 수정은 기능 변경이 아니라 프로토콜 변경에 맞춘 체크 조정이다. README에 기록한다.

## 7. V3 기준값 (비교 대상, 모두 `V3/README.md`·`V3/V3_정리.md`에서 로그 확인)
| 지표 | V3 |
|---|---|
| 총 실행 클럭 (`cyc`) / APB 접근 | 842 / 204 |
| 합성 10 ns slack / 셀 면적 / FF | +1.8 ps / 22,019.670 µm² / 1,816 |
| 합성 통과 최소 주기 | **3.97 ns** (3.95 실패, 3.9 실패, 4.0 통과) |
| 실행 시간 (842 × 3.97) | 약 **3,343 ns** → V4가 이기려면 최소 주기 < 약 3.20 ns (3,343 / 1,046) |
| 10 ns PnR setup / hold | +0.341 / +0.009 ns |
| 10 ns 코어 / Density / 정적 전력 | 36,734 µm² / 61.753% / 0.694 mW (8 ns 기준) |
| 10 ns 클럭 버퍼 / skew | 141 / 0.084, 0.029 ns |
| 4 ns PnR (기본 플로우) | setup +0.006 / hold +0.012 ns, Tempus +0.009 / +0.012 ns |
| 4 ns 셀 면적 / 전력 | 30,989.30 µm² / 2.064 mW (클럭 4 ns) |
| 4 ns Tempus 최악 경로 | ROM → CPU(`u_add` 0.809 ns) → 주소 디코드 → UART 레지스터 → RX FIFO |

## 8. 결정 사항
| 항목 | 결정 |
|---|---|
| 기준 RTL | **V3** (사용자 결정) |
| RTL/스크립트 출발점 | `V3/TOP`의 `1_RTL`, `2_SIM`(1_FUNCTION, 2_PRE, 3_POST, 4_TESTBENCH 스크립트), `3_SYN`(cons, script, run_synthesis, clean.tcl), `4_EC`(script, POST/script), `5_PNR`(0~5 tcl, mmmc.view, tempus.tcl, clean.tcl) **스크립트만** 복사. 산출물/백업 폴더(`10ns/` 등, `.dat`, 로그, GDS, SDF)는 복사하지 않는다 |
| 플로우 깊이 (제안대로) | RTL 회귀(iverilog), 기능 시뮬(xrun): 필수 / 합성 10 ns + EC: 필수 / 합성 sweep: **짧게** (4.0, 3.9, 3.75, 3.5 ns에서 시작해 경계만) / pre-layout 시뮬: 필수 / PnR 10 ns + Tempus + EC + post-layout 시뮬: 필수 / 빠른 주기 PnR: sweep 결과를 보고 결정 |
| 이용률 sweep | V4 범위 아님 (V5 후보, `V3/PD_실험_계획.md` 2장) |

## 9. 작업 순서와 체크리스트
- [ ] 0. 루트 `CLAUDE.md`의 "현재 작업"을 V4로 변경 (사용자 요청 시)
- [ ] 1. `V4/TOP` 폴더 세팅 (8장 기준, 사용자)
- [ ] 2. RTL 수정: `apb_bridge.v`, `mcu_top.v` (사용자, Claude 안내)
- [ ] 3. 테스트벤치 체크 조정 (6장)
- [ ] 4. iverilog 회귀: PASS, RAM/pc/UART/SPI 값 동일, 총 클럭 측정 (요청 시 Claude)
- [ ] 5. xrun 기능 시뮬, APB 3클럭(DECODE/SETUP/ACCESS) 파형 캡처
- [ ] 6. 합성 10 ns, EC(RTL ↔ 합성), 짧은 sweep (V3와 같은 주기 우선)
- [ ] 7. pre-layout 시뮬 (10 ns 합성 결과로 `mapped/` 복원 확인)
- [ ] 8. PnR 10 ns (0~5), Tempus, EC(합성 ↔ PnR), post-layout 시뮬 worst/best
- [ ] 9. (선택) 빠른 주기 PnR
- [ ] 10. 비교표(V3 vs V4), 버전 페이지 5칸, 실행 시간 비교, README 기록
- [ ] 11. 태그 `v4` (사용자 로컬)

## 10. 실행 방법 (V3와 같음, 경로 기준 `V4/TOP/`)
| 단계 | 위치 | 명령 |
|---|---|---|
| RTL 회귀 | (이 환경) | `iverilog -g2012 -o tb.vvp -s tb_mcu_top $(ls 1_RTL/*.v) 2_SIM/4_TESTBENCH/tb_mcu_top.v && vvp tb.vvp` (총 클럭 측정 시 `-Dfunction_sim`은 `$shm_*` 때문에 iverilog에서 안 됨, 별도 출력 추가로 측정) |
| 기능 시뮬 | `2_SIM/1_FUNCTION` | `./run_function.tcl` |
| 합성 | `3_SYN` | `./run_synthesis` → 끝나면 바로 `<주기>/`에 `report mapped log fv` 백업 (예: `10ns/`, `3p75ns/`) |
| EC | `4_EC` | `mkdir -p log`, `lec`, `dofile ./script/script.tcl` |
| pre-layout | `2_SIM/2_PRE` | `mkdir -p dump`, `./run_pre.tcl` |
| PnR | `5_PNR` | `mkdir -p reports/clock reports/timing snap`, `innovus -files 0_InitDesign.tcl` 후 같은 세션에서 `source 1_...` ~ `5_ChipFinish.tcl` |
| EC (합성 ↔ PnR) | `4_EC/POST` | `mkdir -p log`, `lec`, `dofile ./script/script.tcl` |
| Tempus | `5_PNR` | `tempus` → `read_design RouteDesign.dat mcu_core_top` → `check_timing`, `report_annotated_parasitics`, `report_analysis_coverage`, `report_timing -late/-early -max_paths 1`, `write_sdf -view FUNC_SS_WORST/FUNC_FF_BEST ...` |
| post-layout | `2_SIM/3_POST/max`, `min` | `mkdir -p dump`, `./run_post_max.tcl`, `./run_post_min.tcl` |

## 11. 함정 (V2, V3에서 겪은 것)
1. **ideal network → CTS 버퍼 0개.** V3 방식대로 mmmc가 합성 SDC(`3_SYN/mapped/...syn_final.sdc`)를 읽으면, **합성할 때마다 그 SDC의 `set_ideal_network` clk/clrn 두 줄을 다시 주석 처리**해야 한다. CTS 후 `clock_trees.rpt`의 Bufs가 0이면 멈춘다.
2. **sweep 후 `3_SYN/mapped/`에는 마지막 주기 결과가 남는다.** pre-sim/PnR 전에 `10ns/mapped`로 복원하고 `grep create_clock`으로 확인. `cons/mcu_core_top.sdc`는 17번 줄 10으로 되돌린다.
3. 같은 `3_SYN`에서 두 주기를 동시에 돌리지 않는다.
4. `clean.tcl`은 `sh clean.tcl`. `5_PNR`에서 실행하면 그 폴더 결과가 지워진다.
5. `log`, `dump`, `reports/clock`, `reports/timing`, `snap` 폴더는 미리 만든다.
6. **SDF 적용률 확인 필수.** RECREM/REMOVAL 외 미적용 0, 에러 0, 경로 지연 약 90% 이상.
7. 전력 계산 `-period 8.0` 유지, 캡션에 "입력 활동 8 ns 기준". 클럭 주기가 다른 결과끼리 전력 비교 금지.
8. Tempus는 반드시 PnR 폴더에서 실행 (상대 경로 리포트 저장 실패 사례 있음). `tempus.tcl`은 끝에 `exit`이 있어 경로 리포트는 직접 입력.
9. 합성 결과는 주기에 단조롭지 않다. "통과 최소 주기"는 측정점 기준.
10. main 푸시 전 `git fetch` 후 병합 (사용자도 main에 직접 커밋).
11. 공개 저장소: 로그에 서버/계정 이름(`kopo-seongnam`, `/home/hah013`), 큰 산출물, ARM/cmsdk 파일 주의.

## 12. 캡처/캡션 방식
- 사용자가 로그/캡처를 올리면 Claude가 값을 읽어 V3 값과 대조하고 한국어 캡션을 채팅으로 준다. 기대와 다른 값은 숨기지 않고, 추정은 "추정"으로 표시.
- V3와 같은 구성으로 찍되, V4 고유 캡처를 추가한다: **APB 3클럭 파형**(DECODE/SETUP/ACCESS, stall, PENABLE, PSEL, 레지스터된 PADDR), **총 실행 클럭 비교**, 최악 경로에서 주소 디코드~FIFO 구간이 사라졌는지.

## 13. 진행 기록
(작업하면서 채운다)

## 14. 비교표 (V3 vs V4)
| 지표 | V3 | V4 | 차이 |
|---|---|---|---|
| 총 실행 클럭 | 842 | | |
| 합성 10 ns slack / 셀 면적 / FF | +1.8 ps / 22,019.670 / 1,816 | | |
| 합성 통과 최소 주기 | 3.97 ns | | |
| 실행 시간 (클럭 × 최소 주기) | 약 3,343 ns | | |
| 10 ns postRoute setup / hold | +0.341 / +0.009 ns | | |
| 10 ns 코어 / Density | 36,734 µm² / 61.753% | | |
| 클럭 버퍼 / sink / skew | 141 / 1,816 / 0.084, 0.029 ns | | |
| 정적 전력 (10 ns, 8 ns 기준) | 0.694 mW | | |
| DRC / 연결성 | 0 / 0 | | |
| EC (RTL↔합성, 합성↔PnR) | PASS / PASS | | |
| RTL / pre / post 시뮬 | PASS | | |

## 15. 사용자 선호 / 작업 방식
- **가이드 우선, 시킨 것만 한다.** 사용자가 직접 수정/실행하고, Claude는 지시 전에 파일을 수정하지 않는다. 요청 범위 밖에서 고칠 곳을 발견하면 위치와 이유만 알린다.
- 대화는 반말, 결론 먼저, 표로 정리, 불확실한 것은 불확실하다고 말한다.
- PD/PI 포트폴리오가 목적이다. 실험을 필요 이상으로 늘리지 않는다 (sweep은 경계만).
- 포트폴리오 문서는 사용자가 로컬 Claude Code에서 만든다. 이 세션에서는 만들지 않는다.
- main 푸시는 사용자가 요청할 때만, 푸시 전 `git fetch` 후 병합.
