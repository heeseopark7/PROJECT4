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
| **`V4`** | **주소 디코드 레지스터화 (V3 기반)** | **진행 중 (RTL, 기능 시뮬, 합성 10 ns, EC 완료)** | `v4` |
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
- **사이클 증가 측정 결과 (기능 시뮬, xrun 확인):** 처음 예상(APB 204회 그대로, 총 클럭 약 1,046)과 달리 **총 클럭 856(V3 842, +14, +1.7%)**, APB 접근 166회(V3 204)였다. 테스트 프로그램이 UART 수신(UARTFR RXFE)과 SPI 완료(SPSR DONE, slave RX valid)를 **폴링으로 기다리는** 구조라서, 대기 시간은 보드레이트와 SPI 분주(클럭 수 고정)로 정해지고 lw가 1클럭 길어진 만큼 폴링 횟수만 줄었다. 따라서 이 워크로드에서 V4의 사이클 비용은 작고, 실행 시간 비교는 최소 주기에 거의 좌우된다 (V4가 이기려면 최소 주기 < 약 3.90 ns, 7장). 단, 이것은 **I/O 대기 위주 프로그램**의 결과이며 APB 접근이 연산과 겹치지 않는 워크로드(대기 없는 연속 접근)에서는 접근당 +1클럭이 그대로 늘어난다는 점을 함께 적는다.

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
- RAM 4곳, 최종 pc 0xAC, UART 0x41, SPI A5/3C는 같아야 한다.
- **실제 수정 (완료):** 226번 줄 체크를 `check("stall = 2 x penable", n_stall == 2*n_pen ...)`로 변경, 헤더 주석 27~28번 줄 갱신, `$display("info : total clocks = %0d", cyc)` 한 줄 추가. 나머지 체크는 그대로.
- **결과 (xrun 확인):** PASS, APB 접근 **166**(V3 204), 총 클럭 **856**(V3 842), 종료 8,785 ns(V3 8,645 ns). 처음 예상했던 "APB 204회 동일, 약 1,046클럭(842 + 204)"은 폴링 루프를 고려하지 않은 계산이라 틀렸다 (3장).
- `1_FUNCTION/run_function.tcl`은 수정 없음 (새 파일이 없어 RTL 목록 동일).
- 테스트벤치 수정은 기능 변경이 아니라 프로토콜 변경에 맞춘 체크 조정이다.

## 7. V3 기준값 (비교 대상, 모두 `V3/README.md`·`V3/V3_정리.md`에서 로그 확인)
| 지표 | V3 |
|---|---|
| 총 실행 클럭 (`cyc`) / APB 접근 | 842 / 204 |
| 합성 10 ns slack / 셀 면적 / FF | +1.8 ps / 22,019.670 µm² / 1,816 |
| 합성 통과 최소 주기 | **3.97 ns** (3.95 실패, 3.9 실패, 4.0 통과) |
| 실행 시간 (842 × 3.97) | 약 **3,343 ns** → V4(856클럭)가 이기려면 최소 주기 < 약 **3.90 ns** (3,343 / 856, 계산값). 처음 적었던 3.20 ns(3,343 / 1,046)는 틀린 예상 클럭 기준 |
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
- [x] 0. 루트 `CLAUDE.md`의 "현재 작업"을 V4로 변경
- [ ] 1. `V4/TOP` 폴더 세팅 (8장 기준, 사용자): `1_RTL`, `2_SIM`, `3_SYN`, `4_EC` 완료. `5_PNR`, `4_EC/POST`는 저장소에 아직 없음
- [x] 2. RTL 수정: `apb_bridge.v`, `mcu_top.v`
- [x] 3. 테스트벤치 체크 조정 (6장)
- [x] 4. iverilog 회귀: PASS, RAM/pc/UART/SPI 값 동일, APB 166, 총 클럭 856
- [x] 5. xrun 기능 시뮬 PASS, 캡처 6장 (전체, APB 3클럭, 폴링 루프, UART, SPI, 콘솔)
- [ ] 6. 합성 10 ns, EC(RTL ↔ 합성), 짧은 sweep (V3와 같은 주기 우선): **10 ns 합성, EC 완료.** sweep 남음
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
| EC 1단계 (RTL ↔ Genus 중간 넷리스트) | `3_SYN` | `lec -xl -nogui -dofile fv/mcu_core_top/rtl_to_fv_map.do` (Genus가 합성 때 만드는 dofile, 경로가 `3_SYN` 기준이라 반드시 `3_SYN`에서 실행). 로그 `fv/mcu_core_top/rtl_to_fv_map.log` |
| EC 2단계 (Genus 중간 넷리스트 ↔ 최종 넷리스트) | `4_EC` | `mkdir -p log`, `lec`, `dofile ./script/script.tcl` (V4에서 Golden을 `fv_map.v.gz`로 바꿈, 13장) |
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
- [x] **CLAUDE.md 갱신:** 현재 작업을 V4로 변경 (V3 완료, V4 진행 중, 수정 금지 대상에 V3 추가).
- [x] **RTL 수정** (`1_RTL`, 나머지 20개 파일은 V3와 동일):
  - `apb_bridge.v`: FF 1개(`r_access`) → 2비트 `r_state` (S_IDLE=0/DECODE, S_SETUP=1, S_ACCESS=2, ACCESS 다음은 무조건 IDLE). `o_capture = i_req & (state==IDLE)` 포트 추가, `o_psel = SETUP|ACCESS`, `o_penable = ACCESS`(둘 다 FF 출력, `i_req` 무관), `o_stall = i_req & (state != ACCESS)`.
  - `mcu_top.v`: 디코드 레지스터 `r_psel_uart/spi/slv`, `r_pwrite`, `r_paddr[9:0]`, `r_pwdata[15:0]`(30비트)를 `w_capture`에 저장. 슬레이브 3개의 PSEL = `r_psel_* & w_psel`, PWRITE/PADDR/PWDATA = 레지스터 출력. `memout`의 APB 쪽 선택을 `r_psel_*`로. 조합 디코드(`w_in_apb`, `w_req`, `w_psel_*`)와 RAM 쓰기 enable은 그대로. `uut4.o_psel`을 `w_psel`에 연결.
  - 슬레이브는 모두 `psel & penable`(ACCESS)에서만 읽기/쓰기를 하므로(`reg_block.v` 129~130, `spi_regs.v` 99, `spis_regs.v` 96) 수정 불필요.
  - `r_pwdata`는 처음에 32비트로 만들었으나, 첫 합성 check_design에서 `r_pwdata[31:16]`이 출력을 받는 곳이 없다는 경고(Unloaded Sequential Pin 16)가 나왔다. 슬레이브가 쓰는 PWDATA 최대 폭이 UART IBRD [15:0](`reg_block.v` 181번 줄)이라서다. 16비트로 줄이고 슬레이브에는 `{16'd0, r_pwdata}`로 연결했다(커밋 5dcc986). 재시뮬 결과 동일(PASS, APB 166, 856클럭, 8,785 ns), 재합성 넷리스트도 셀 수/면적/경로가 이전과 같다(그 16개 FF는 이전에도 합성에서 지워졌음).
  - 예상 FF 증가: 상태 +1, 디코드 레지스터 +30 → 최대 +31 (계산값). 실제 +29 (아래 합성 항목, 차이 2개는 EC 항목에서 원인 확인).
  - 이후 사용자가 `uut5` 연결부 정렬만 탭으로 바꿈 (커밋 ebc7f7c, 기능 변경 없음).
  - RTL 코드 캡처 5장 (`apb_bridge` 상태 머신, 조합 디코드, 디코드 레지스터, UART 슬레이브 연결, `memout` mux).
- [x] **테스트벤치 조정:** 6장. iverilog와 xrun 결과 동일.
- [x] **기능 시뮬 (xrun) PASS:** RAM[0~3] = 0x37/0x41/0x3C/0xA5, 최종 pc 0xAC, `stall = 2 x penable` ok, **APB 접근 166, 총 클럭 856**, UARTTXD 0x41 1프레임, SCLK 8, MOSI 0xA5, MISO 0x3C, **8,785 ns 종료** (V3 8,645 ns).
  - APB 3클럭 파형: sw UARTIBRD에서 DECODE 375~385, SETUP 385~395, ACCESS 395~405 ns (Baseline 375 → 405 ns, 30 ns). w_stall 2클럭, w_penable 1클럭(겹치지 않음), pc 0x20 3클럭 정지, 385 ns에 r_paddr 0x009 / r_pwdata 0x4 / r_pwrite 1. 이어서 sw UARTCR(0x00C/0x381), lw UARTFR(0x006, r_pwrite 0)도 같은 패턴.
  - UARTFR 폴링 루프: lw 3 + andi 1 + bne 1 = 5클럭(50 ns, w_penable 555 → 605 ns). V3는 4클럭(40 ns). ACCESS의 memout 0x18 → 0x98 (PL011 UARTFR 비트 해석은 RTL 레지스터 정의로 미확인).
  - UART: start bit 575 ns(V3 525 ns), stop bit 시작 6,335 ns, 비트당 640 ns, tx_byte 0x41, r_ram[1]=65.
  - SPI: 첫 SCLK 상승 7,105 ns, 8번째 8,225 ns(V3 8,135 ns), 1,120 ns = 7 × 160 ns. MOSI 0xA5, MISO 0x3C, r_ram[2]=60, r_ram[3]=165.
  - 해석: 3장 "사이클 증가 측정 결과".
- [x] **합성 10 ns** (`r_pwdata` 16비트 기준, `3_SYN/report`, 로그와 대조): slack **+2.1 ps**, TNS 0, 위반 0. 인스턴스 5,252(V3 5,243), **FF 1,845(V3 1,816, +29)**, 조합 3,407(V3 3,427), 계층 25. 셀 면적 **22,097.646 µm²(V3 22,019.670, +77.976, +0.35%)**. 런타임 3분 31초(CPU).
  - check_design: Unresolved 0, Empty 0, Unloaded Port 0, **Unloaded Sequential Pin 0**, Unloaded Combinational Pin 4(V3와 같음), Assigns 98, Constant Leaf Pin 7, Constant hierarchical Pin **1,923**(V3 1,869, +54: 슬레이브 3개 × PWDATA 상위 16비트 상수 = 48, 나머지 6 원인 미확인).
  - 계층별 면적: `mcu_top` 자체(하위 제외, 계산값) 123.120 → 412.794 µm²(63 → 127셀), `apb_bridge` 11.628 → 23.256(3 → 10셀). RTL 미변경인 `sccpu` 4,404.276 → 4,254.480(`u_add` 386.118 → 353.628), `scinstmem` 376.542 → 323.874로 감소 (10 ns에서 앞쪽 로직이 더 작은 셀로 매핑된 것으로 추정).
  - 셀 종류: sequential 14,461.470 → 14,673.510 µm²(+212.040), logic 7,426.872 → 7,317.432(−109.440), buffer 7 → 0. ADDFX1 7 → 6, ADDHX1 80 → 78. 합성 전력 0.6157 mW(V3 0.6153, 참고용).
  - **최악 경로: `uut1/r_pc_reg_3` → ROM(`uut2`, 1,250 ps) → CPU 디코드(1,135) → `u_add`(`w_bx[0]` → `w_sum[31]`, 41셀, 4,687) → `mcu_top` 주소 비교 `w_in_apb`(OR4X1 `g1076`, OR4X6 팬아웃 35, INVX1, 872) → `memout` mux(AND2X1, AOI222X1, OAI2BB1X1, 745, 추정) → 레지스터 파일 쓰기 선택(AO22X1, MX2X1, 560) → `uut1/r_regs_reg_13_7`**, 데이터 경로 9,788 ps(V3 9,789). V3의 끝점(UART TX FIFO `r_count_reg_4`)에서 레지스터 파일로 바뀜. Timing Debug 상위 7개 경로도 모두 `r_regs_reg_13_*`, `14_7` 끝점, slack +2 ps(V3 상위 경로는 UART/SPI 끝점).
  - 해석: 가산기 뒤 구간이 V3 약 2.92 ns(디코드 → UART → FIFO)에서 약 2.35 ns로 짧아졌지만, 10 ns에서는 툴이 남는 시간을 면적 절약에 써서 `u_add`가 약 3.9 → 4.69 ns로 길어지고 총 지연은 같다(추정). 실제 속도 비교는 sweep 최소 주기로 한다. 남은 최악 경로는 RAM 1클럭 접근을 위해 조합으로 남긴 `w_in_apb` 선택이다 (5장 예상과 같음).
  - 캡처: 스키매틱(최상위, Timing Debug, 경로 전체, 확대 2장), 스크립트, SDC, check_design, 완료 로그, QoR, 경로 리포트 2장, 계층 면적, 셀 종류, 계층, 전력, ADD 셀. 캡처 문서 `3_SYN_V4.docx`(사용자 로컬).
- [x] **EC (RTL ↔ 합성) PASS (2단계)**
  - **V3와 같은 스크립트(RTL ↔ 최종 넷리스트)는 FAIL:** Equivalent 1,787(PO 8 + DFF 1,779), **Non-equivalent 66**, Golden 2,639 중 Unreachable 760, **Not-mapped 34**(V3 32).
    - Not-mapped 34 = `r_regs_reg[15][31:0]`(V3와 같은 32개, 미사용 레지스터) + **`r_regs_reg[11][9]`, `[11][8]`**(t3 비트 9, 8).
    - Genus가 ROM 프로그램상 t3에 8비트 값만 쓰여 이 두 비트가 리셋 후 항상 0임을 찾아 상수로 대체했다(Genus 로그 GLO-12, 상수 0 대체 FF가 V3 256 → V4 258). FF가 +31이 아니라 +29인 이유도 이것이다.
    - LEC 기본 설정은 RTL 쪽 t3[9:8]을 임의 값으로 취급해, 이 값을 저장 데이터로 받는 `r_pwdata_reg[9:8]`(2) + `r_ram_reg[0..31][9:8]`(64) = 66개를 Non-equivalent로 판정했다. 설계 차이가 아니라 검증 설정의 한계다.
    - `set flatten model -seq_constant`(-seq_constant_x_to 0)만 추가해서는 결과가 같았다 (ROM 내용에 의존하는 상수는 찾지 못함). 최종 넷리스트 비교에 `read implementation information`을 추가해도 FAIL 그대로였다.
  - **해결: Genus 권장 2단계 EC.**
    - 1단계 RTL ↔ Genus 중간 넷리스트(`fv_map.v.gz`): Genus가 만든 `3_SYN/fv/mcu_core_top/rtl_to_fv_map.do`를 `3_SYN`에서 실행. 구현 정보의 순차 상수 258개를 읽어 RTL FF 258개를 상수로 변환("Converted 258 DFF/DLAT(s) in (G) to ZERO/ONE"), Not-mapped 0, 최상위 비교점 1,367개(DFF 1,350, PO 8, BBOX 9) Equivalent, **PASS**. 정보 불일치 0, diff/abort/unknown 0. 모듈 단위 비교 중 `sccpu`, `sclk_gen`의 NEQ는 경계 상수 맥락이 없어서 생긴 것으로, 상위에서 dynamic flattening으로 재비교해 Equivalent.
    - 2단계 Genus 중간 넷리스트 ↔ 최종 넷리스트(`mapped/mcu_core_top_syn_final.v`): `4_EC/script/script.tcl`의 Golden을 `../3_SYN/fv/mcu_core_top/fv_map.v.gz`로 바꿔 실행. **비교점 1,853개(PO 8 + DFF 1,845) 모두 Equivalent, PASS**, Incomplete verification 0, User modification 0, Duplicate module definition 1(V3와 같음).
  - **스크립트 변경 기록 (실험 원칙상 EC 방법 변경):** `4_EC/script/script.tcl`은 RTL `read design` 블록을 `//`로 막고 Golden을 `fv_map.v.gz`로 바꿨다. `set flatten model -seq_constant`, `-seq_constant_x_to 0` 두 줄과 주석 처리된 `read implementation information` 줄이 남아 있다(2단계 결과에는 영향 없음, 추정). V3 스크립트는 수정하지 않았다. PnR 후 EC(`4_EC/POST`, Golden이 합성 넷리스트)는 이 문제와 무관하므로 V3 방식 그대로 쓸 수 있을 것으로 본다(추정).
  - 캡처: 2단계 compare, report verification 2장만 사용(사용자 결정, PI 포트폴리오 범위 밖). 1단계는 로그로 근거를 남긴다.

## 14. 비교표 (V3 vs V4)
| 지표 | V3 | V4 | 차이 |
|---|---|---|---|
| 총 실행 클럭 (APB 접근) | 842 (204) | 856 (166) | +14 (+1.7%) |
| 합성 10 ns slack / 셀 면적 / FF | +1.8 ps / 22,019.670 / 1,816 | +2.1 ps / 22,097.646 / 1,845 | 면적 +0.35%, FF +29 |
| 합성 10 ns 최악 경로 끝점 / 데이터 경로 | TX FIFO `r_count_reg_4` / 9,789 ps | 레지스터 파일 `r_regs_reg_13_7` / 9,788 ps | 끝점 이동, 지연 같음 |
| 합성 통과 최소 주기 | 3.97 ns | | |
| 실행 시간 (클럭 × 최소 주기) | 약 3,343 ns | | |
| 10 ns postRoute setup / hold | +0.341 / +0.009 ns | | |
| 10 ns 코어 / Density | 36,734 µm² / 61.753% | | |
| 클럭 버퍼 / sink / skew | 141 / 1,816 / 0.084, 0.029 ns | | |
| 정적 전력 (10 ns, 8 ns 기준) | 0.694 mW | | |
| DRC / 연결성 | 0 / 0 | | |
| EC (RTL↔합성, 합성↔PnR) | PASS / PASS | PASS (2단계) / - | 방식 변경 (13장) |
| RTL / pre / post 시뮬 | PASS | PASS / - / - | |

## 15. 사용자 선호 / 작업 방식
- **가이드 우선, 시킨 것만 한다.** 사용자가 직접 수정/실행하고, Claude는 지시 전에 파일을 수정하지 않는다. 요청 범위 밖에서 고칠 곳을 발견하면 위치와 이유만 알린다.
- 대화는 반말, 결론 먼저, 표로 정리, 불확실한 것은 불확실하다고 말한다.
- PD/PI 포트폴리오가 목적이다. 실험을 필요 이상으로 늘리지 않는다 (sweep은 경계만).
- 포트폴리오 문서는 사용자가 로컬 Claude Code에서 만든다. 이 세션에서는 만들지 않는다.
- main 푸시는 사용자가 요청할 때만, 푸시 전 `git fetch` 후 병합.
