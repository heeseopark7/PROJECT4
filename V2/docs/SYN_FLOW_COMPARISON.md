# 합성 플로우 비교: Genus 기본 플로우(PDF) vs V1(pad) vs V2(core)

작성 목적: V2 합성 전에, 강의 자료(`25_syn_sdc.pdf`, Generic Genus Work Flow)와 V1 스크립트가 어떻게 다른지, V2가 V1에서 무엇을 바꿨는지 한 곳에 기록한다.
근거: `V1/TOP/3_SYN/script/syn_mcu_pad_top.tcl`, `V1/TOP/3_SYN/cons/mcu_pad_top.sdc`, `V1/TOP/3_SYN/log/all.log`, V1 리포트, `V2/TOP/3_SYN/{script,cons}/`.
표시: `[확인]` = 파일/로그에서 직접 확인, `[추정]` = 내 해석, 로그로 검증 필요.

---

## 1. PDF 기본 플로우 (참고 기준)

PDF의 흐름은 7단계이고, 슬라이드 9~10은 앞 슬라이드를 합친 요약이다.

| # | 단계 | PDF 내용 |
|---|---|---|
| 1 | 검색 경로, 라이브러리 | `set_db init_lib_search_path`, `init_hdl_search_path`, `set_db library` |
| 2 | 합성 모드 (선택) | 기본은 wireload. `set_db interconnect_mode ple`이면 LEF 등 물리 정보를 써서 합성 |
| 3 | HDL 읽기, elaborate | `read_hdl`(순차 또는 `{}`로 동시), `elaborate`. Windows에서 옮긴 파일의 숨은 문자 확인 주의 |
| 4 | 제약 | `read_sdc` (동작 조건, 클럭, I/O 지연) |
| 5 | 최적화 설정 | I2O, I2C, C2C, C2O 경로별 제약 |
| 6 | 합성 | `syn_generic` → `syn_map` |
| 7 | 분석 / 출력 | `report_area`, `report_gates`, `report_timing` / `write_hdl`, `write_sdc`, `write_design -innovus` |

PDF에는 `syn_opt`, 단계별 snapshot, SDF 출력, 계층 유지, dont_use 설정이 없다.

---

## 2. 단계별 상세 비교

### 2.1 검색 경로, 라이브러리

| 항목 | PDF | V1 (pad) | V2 (core) |
|---|---|---|---|
| lib 검색 경로 | `init_lib_search_path` | `init_lib_search_path` = std 셀 timing + IO timing + LEF + QRC 경로 | 같음. IO timing 경로는 `""`로 비움 |
| HDL 검색 경로 | `init_hdl_search_path` | `../1_RTL` | 같음 |
| 라이브러리 지정 | `set_db library` | `read_libs {slow_vdd1v0_basicCells.lib slow_vdd1v0_multibitsDFF.lib pads_SS_s1vg.lib}` | `read_libs {slow_vdd1v0_basicCells.lib slow_vdd1v0_multibitsDFF.lib}` (pads_SS 제거) |
| 물리 정보 | 없음 | `read_physical -lef {gsclib045_tech.lef gsclib045_macro.lef giolib045.lef}`, `read_qrc gpdk045.tch` | `giolib045.lef` 제거, 나머지 동일 |
| 코너 | 단일 | slow 라이브러리만 읽음 (fast는 읽지 않음) [확인] | 동일 |

- V1에서 SDC의 `set_operating_conditions -min_library fast_vdd1v0...`가 **경고**(SDC-208, `get_libs`가 `fast_vdd1v0`를 못 찾음)를 낸다 [확인: V1 `log/all.log` 611행]. 에러는 아니고 합성은 slow 단일 코너로 진행된다. V2도 같은 SDC 줄을 유지하므로 같은 경고가 나온다. min 코너(hold)는 Genus가 아니라 Innovus/Tempus의 MMMC에서 본다 [추정].
- 참고: `V1/TOP/3_SYN/cons/mcu_pad_top.mmmc.view`는 FF/SS 두 코너를 정의하지만 합성 스크립트(`syn_mcu_pad_top.tcl`)는 이 파일을 쓰지 않는다. 용도는 PnR 쪽이다 [추정].

### 2.2 합성 모드 (interconnect_mode)

| 항목 | PDF | V1 | V2 |
|---|---|---|---|
| 설정 | 선택: `set_db interconnect_mode ple` | 설정하지 않음 | 설정하지 않음 (V1과 동일 유지) |
| 리포트 표기 | - | `Interconnect mode: global`, `Area mode: physical library` [확인: V1 19_qor 리포트] | 동일할 것으로 예상 |

- V1 PPT 16번 슬라이드의 미해결 항목(같은 `ADDFX1` 체인이 Genus 약 51 ps, Innovus init 약 185 ps)과 관련 있을 수 있다. `ple`은 LEF 정보로 지연을 추정해서 PnR 값에 더 가까워진다 [추정].
- **지금은 바꾸지 않는다.** 기준선은 V1과 같은 조건이어야 하고, 한 번에 하나만 바꾸는 원칙이다. 나중에 별도 실험 후보.

### 2.3 HDL 읽기, elaborate

| 항목 | PDF | V1 | V2 |
|---|---|---|---|
| 읽기 | `read_hdl` | `read_hdl $RTL_SOURCES` (21개 파일 목록) | 동일하되 첫 파일이 `mcu_core_top.v`(래퍼)이고 `mcu_pad_top.v`는 목록에서 제외 |
| elaborate | `elaborate` | `elaborate ${TOP_DESIGN}` | `TOP_DESIGN = mcu_core_top` |
| 추가 | 없음 | `uniquify -verbose`, `optimize_merge_flops false`, `optimize_merge_latches false`, `check_design`(unresolved 포함) | 동일 |
| 패드 의존 | - | `mcu_pad_top.v`가 `add_pad`를 `` `include`` (PnR에서 전원 패드 16개 주석 해제) | 패드 없음. `include` 불필요 |

- V1은 PDF에 없는 `optimize_merge_flops false`를 써서 FF가 합쳐지는 것을 막는다. 그래서 합성 후 FF 수(1,816개)가 RTL의 레지스터 정의와 1:1로 대응된다. 이 설정은 V2에서도 유지해서 FF 수 비교가 가능하다 [추정].

### 2.4 제약 (SDC)

| 항목 | PDF | V1 SDC (`mcu_pad_top.sdc`) | V2 SDC (`mcu_core_top.sdc`) |
|---|---|---|---|
| 읽는 방식 | `read_sdc` | `source -verbose` (그래서 `read_sdc` 대신 Tcl로 실행, 줄 단위 로그) | 동일 |
| 클럭 | - | `create_clock -period 10 -name MAIN_CLOCK [get_ports clk]` | 동일 |
| 클럭 latency | - | source 0.2 ns, network 0.2 ns | 동일 |
| uncertainty / transition | - | setup 0.1 ns / 0.1 ns | 동일 |
| 입력 delay | - | max 0.1, min 0.01 ns (clk 제외) | 동일 (수정됨: 처음에 1.0/0.1로 잘못 바꿨다가 V1 값으로 복구) |
| 출력 delay | - | max 0.1, min -0.01 ns | 동일 (같은 이유로 복구) |
| 입력 구동 | - | `set_driving_cell -lib_cell PADDI -pin Y` (활성), `set_input_transition 0.1`은 주석 처리 | **`set_input_transition 0.1`** |
| 출력 부하 | - | `set_load [load_of PADDO/A]` (패드 셀 입력 용량) | 임시 `set_load 0.02` (20 fF). **TODO: PADDO/A 실제 값으로 교체** |
| 동작 조건 | - | `set_operating_conditions` max=slow 0.9V 125C, min=fast 1.1V 0C (min은 위 경고 때문에 적용 안 됨) | 동일 |
| ideal network | - | `set_ideal_network [get_ports "clk clrn"]` | 동일 |
| dont_touch | - | `set_dont_touch pad2 ... pad40` (패드 15개) | 제거 (패드가 없음) |
| 기타 | - | `reset_design` 선행 | 동일 |

**V2에서 바꾼 값의 근거와 주의 (정정: 패드 관련만 변경)**
- 정정: 이 문서의 이전 버전은 입출력 delay를 1.0 ns로 바꿨다고 적었다. 범위 밖 변경이어서 V1 값(0.1 / 0.01 / 0.1 / -0.01 ns)으로 되돌렸다. 아래 첫 항목은 이전 설명이라 무시한다.
- 입출력 delay 1.0 ns는 내가 정한 값이다. V1은 패드 모델 안에서 0.1 ns였다. 코어 단독 트랙에서는 포트가 곧 코어 경계라 더 현실적인 값을 썼다. 입력 7개 중 clk, clrn 외에는 모두 2-FF 동기화기로 들어가므로 이 값이 최악 경로에 영향을 주지 않을 것으로 예상하지만, 합성 결과로 확인해야 한다. **사용자 확인 필요.**
- 패드를 제거했으니 `PADDI` 구동 셀, `PADDO/A` 부하는 의미가 없다. 대신 외부 transition 0.1 ns, 부하 20 fF로 대체했다.
- **V1 자체의 불일치 [확인, 검증 필요]:** PPT 12번 슬라이드는 "입력 구동 가정을 `set_input_transition 0.1`로 교체했다"고 쓰여 있지만, 현재 V1 SDC에서는 `set_driving_cell PADDI`가 활성이고 `set_input_transition`이 주석이다. SDC 주석에도 "instead of the PADDI cell"이라고 적혀 있어 실제 상태와 모순된다. 10 ns 합성이 어느 SDC로 돌았는지 확인하고, PPT 서술을 현재 SDC와 맞추거나 그 반대로 정리해야 한다. V2는 `set_input_transition` 쪽이라 이 문제와 무관하다.
- V1 `02_report_port.rpt`에서 입력 delay가 100 ps(= 0.1 ns)로 적용된 것을 확인했다 [확인].

### 2.5 최적화 설정

| 항목 | PDF | V1 | V2 |
|---|---|---|---|
| 경로 그룹 제약 | I2O, I2C, C2C, C2O | 별도 그룹 지정 없음, 기본 `default`와 `MAIN_CLOCK` 두 cost group | 동일 |
| 계층 | - | `set_db auto_ungroup none` (계층 유지) | 동일 |
| effort | 기본 medium | `syn_generic_effort`, `syn_map_effort`, `syn_opt_effort` 모두 high | 동일 |
| CPU | - | `max_cpus_per_server 2` | 동일 |
| dont_use | - | `dont_use_45nm.tcl`: ANTENNA*, DLY*, HOLD*, TIE*, TLA*, DFFS*, SDFF* | 동일 파일 |
| 배열 이름 | - | `hdl_array_naming_style %s_%d`, `uniquify_naming_style` | 동일 |

- `auto_ungroup none` 덕분에 계층별 면적(RAM, UART, CPU)을 리포트로 볼 수 있다. V2에서도 유지해야 비교표의 면적 분해가 가능하다.
- `DFFS*`, `SDFF*`를 쓰지 못하게 해서 합성 FF가 `DFFRHQX*` 계열로 정해진다 [확인: V1 넷리스트 `DFFRHQX1`].

### 2.6 합성

| 항목 | PDF | V1 / V2 |
|---|---|---|
| `syn_generic` | 있음 | 있음, 직후 `write_snapshot -tag syn_generic`, `write_db` |
| `syn_map` | 있음 | 있음, 직후 `report_datapath`, 코스트 그룹별 `report timing`(05), snapshot, `write_db` |
| `syn_opt` | **없음** | **있음**, 직후 `report_constraint -all_violators`(06), 코스트 그룹별 timing(07), snapshot, `write_db` |
| `-physical` | 없음 | 주석 처리 (`syn_generic -physical` 등은 쓰지 않음) |

- `syn_opt`가 있기 때문에 slack이 목표(10 ns)에 딱 맞게 +2.3 ps 정도까지 줄어든다. V1 합성은 "느슨한 제약에서는 면적 쪽으로 최적화" 되는 동작이다 [확인: V1 PPT 17번].

### 2.7 분석 (리포트)

| 번호 | PDF | V1 / V2 리포트 |
|---|---|---|
| 00~02 | - | check_design, check_timing_intent, report_port(delay, driver, load) |
| 03, 04 | - | report_datapath (generic 직후, map 직후) |
| 05, 06, 07 | - | 단계별 timing, violators, post-opt timing |
| 08~18 | `report_area`, `report_gates` | analysis view, area, clocks, datapath, design_rules, gates(+power), hierarchy, memory_cells, messages, nets, power |
| 19, 20 | `report_timing` | QoR, `report_timing -nworst 100 -net` |
| 추가 | - | `report_summary`, snapshot 3종(`syn_generic`, `syn_map`, `syn_opt`) |

### 2.8 출력

| 항목 | PDF | V1 / V2 |
|---|---|---|
| 넷리스트 | `write_hdl > design.v` | `write_hdl > mapped/${TOP}_syn_final.v` |
| SDC | `write_sdc > constraints.sdc` | `write_sdc > mapped/${TOP}_syn_final.sdc` |
| Innovus 연동 | `write_design -innovus <name>` | `write_design -basename mapped/${TOP}_mapped` (**`-innovus` 없음**) |
| SDF | 없음 | `write_sdf -timescale ns -nonegchecks -recrem split -edges check_edge -setuphold split` (pre-layout 게이트 시뮬용) |
| LEC | - | `write_do_lec`는 주석 처리 (EC는 Conformal에서 따로 수행) |

- V1은 `-innovus` 없이 PnR(`0_InitDesign.tcl`)까지 문제없이 갔다. V2도 같은 방식을 유지한다.
- 출력 이름이 `${TOP_DESIGN}` 변수 기반이라 V2는 `mcu_core_top_syn_final.v` 등으로 나온다. PnR/EC 스크립트에서 이름을 바꿔줘야 한다.

---

## 3. V1 → V2 변경 요약 (이 파일 기준)

| 파일 | 변경 | 이유 |
|---|---|---|
| `script/syn_mcu_core_top.tcl` | `TOP_DESIGN`, 첫 RTL 파일, IO 경로/라이브러리/LEF에서 패드 항목 제거, SDC 파일명 | 패드 제거 |
| `cons/mcu_core_top.sdc` | 패드 dont_touch 제거, 입출력 delay 0.1→1.0 ns, driving cell→input_transition, load→20 fF 고정, `CLK_PERIOD` 변수화 | 코어 단독 트랙 |
| `cons/dont_use_45nm.tcl` | 변경 없음 | 비교 조건 유지 |
| 그 외 (effort, ungroup, merge_flops, 리포트, 출력) | 변경 없음 | 비교 조건 유지 |

## 4. 합성 전 확인할 것

1. 입출력 delay 1.0 ns, 출력 부하 20 fF를 사용자가 승인하는지 (미승인 시 값 수정 후 동결).
2. V1 SDC와 PPT 12번의 `set_driving_cell` / `set_input_transition` 불일치 정리.
3. 합성 로그에서 SDC-208(fast 라이브러리 없음) 경고는 V1과 같게 나오는지 확인 (새로운 에러 없는지).
4. 합성 후: `check_design` 결과(unresolved, undriven, multidriven 0), `Interconnect mode`, 계층 구조(`uut1~uut7`)가 V1과 같은지.
5. 래퍼가 최상위라 계층이 `mcu_core_top / u_mcu_top / uut*` 형태인지. 이후 SDF 인스턴스 경로(`u_mcu_top`)가 V1과 같다 [확인: V1 `u_mcu_top`].

## 5. 나중에 실험할 후보 (지금은 하지 않음)

- `set_db interconnect_mode ple`: Genus와 Innovus의 지연 차이 원인 확인용.
- `write_design -innovus` 사용 여부: PnR 입력 방식 비교.
- 입출력 delay를 주기 비례(예: 20%)로 바꾸는 방식: sweep 시 의미 비교.
