# 합성 스크립트 비교: Cadence 템플릿(이미지) vs V1 `script/*.tcl` vs V2

`SYN_FLOW_COMPARISON.md`가 강의 PDF(개념 흐름)와의 비교라면, 이 문서는 **실제 Tcl 스크립트 수준**의 비교다.

## 0. 비교 대상

| 약칭 | 파일 / 출처 | 비고 |
|---|---|---|
| **T** | Cadence 템플릿 이미지 (`Template Script for RTL->Gate-Level Flow`, GENUS 21.16-s062_1 생성) | 이미지에는 `syn_generic`까지만 보인다. 그 뒤(`syn_map`, `syn_opt`, 출력)는 T에 없는 것이 아니라 **이미지에 없다.** |
| **P** | `V1/TOP/3_SYN/script/syn_mcu_pad_top.tcl` (233줄) | V1 합성에 실제로 쓴 스크립트 [확인: V1 리포트가 slow 단일 라이브러리, `Technology libraries: slow_vdd1v0 / giolib045`] |
| **M** | `V1/TOP/3_SYN/script/syn_mcu_pad_top_mmmc.tcl` (213줄) | 수업용 `cmsdk_mcu` 템플릿(GENUS 17.10 헤더). 현재 상태로는 실행 불가 [확인, 3.4절] |
| **V2** | `V2/TOP/3_SYN/script/syn_mcu_core_top.tcl` | P에서 패드 항목만 제거 |

표시: `[확인]` 파일에서 직접 확인, `[추정]` 내 해석.

---

## 1. 템플릿(T) vs P(V1): 항목별

| # | 항목 | T (Cadence 템플릿) | P (V1 스크립트 = V2 기준) | 영향 |
|---|---|---|---|---|
| 1 | 설정 방식 | `include setup_run.tcl`로 root attribute와 변수(`$DESIGN`, `$_LOG_PATH`, `$_OUTPUTS_PATH`, `$_REPORTS_PATH`, `$GEN_EFF`)를 외부 파일에서 읽음 | 스크립트 상단에서 직접 지정 (`TOP_DESIGN`, `LOG_DIR`, `RPT_DIR`, `UNMAPPED_DIR`, `MAPPED_DIR`, lib/LEF/RTL 경로, `set_db ...`) | 파일 하나로 완결. 재현성에는 P가 유리 |
| 2 | 디렉터리 생성 | `if {![file exists ${_LOG_PATH}]} {file mkdir ...}` 3종 (log, outputs, reports) | `foreach d [list LOG RPT UNMAPPED MAPPED] {file mkdir $d}` (4종) | 동등. P는 unmapped/mapped를 분리 |
| 3 | HDL 읽기 | `read_hdl <files>` → `elaborate $DESIGN` → `time_info Elaboration` | 같음 + `uniquify -verbose`, `set_db optimize_merge_flops/latches false` | P가 계층 이름 고유화와 FF 병합 방지를 추가 |
| 4 | 설계 점검 | `check_design -unresolved` | `check_design`과 `check_design -unresolved`를 `00_check_design.rpt`에 저장 | P가 더 넓게 점검 |
| 5 | 제약 읽기 | `read_sdc <file>` → 예외 수 출력(`vfind ... -exception`) | `source -verbose ./cons/*.sdc` → 같은 예외 수 출력, 추가로 `source dont_use_45nm.tcl` | 방식 차이. 예외 수 출력은 동일 |
| 6 | wireload | `#set_db "design:$DESIGN" .force_wireload` 주석 | 같은 주석 | 동일 (미사용) |
| 7 | timing intent | `check_timing_intent` | `check_timing_intent -verbose > report/01_...rpt` | P가 리포트 저장 |
| 8 | **cost group** | `I2C`, `C2O`, `C2C`, `I2O` 4개를 `define_cost_group` + `path_group`(from/to)으로 정의하고 `_pretim.rpt`에 그룹별 timing 저장 | **정의 없음.** 기본 cost group만 사용. `foreach cg [vfind / -cost_group *]`로 있는 그룹을 보고만 함 | 아래 2.1절 참고 (가장 큰 차이) |
| 9 | FF/latch 병합 | `##set_db / .optimize_merge_flops false` **주석(기본값, 병합 허용)** | **활성** (`false`) | P는 FF 수가 RTL과 대응되게 유지. 합성 후 FF 1,816개와 EC 비교점 1:1 매핑에 영향 [추정] |
| 10 | effort | `set_db / .syn_generic_effort $GEN_EFF` (변수, `syn_generic` 직전) | `syn_generic/map/opt_effort` 모두 `high`를 상단에서 고정 | P가 map/opt까지 high |
| 11 | `syn_generic` 후 | `report_dp > .../generic/${DESIGN}_datapath.rpt`, `write_snapshot -tag generic`, `report_summary -directory` | `report_datapath > 03_...rpt`, `write_snapshot -tag syn_generic`, `write_db unmapped/syn_generic.db` (`report_summary`는 주석) | 리포트 구조 차이: T는 하위 폴더(generic/), P는 번호 접두 평면 구조 |
| 12 | 계층 | 언급 없음 (기본 동작) | `auto_ungroup none` | P는 계층 유지, 계층별 면적 리포트 가능 |
| 13 | 헤더/환경 출력 | `/proc/cpuinfo`, `Hostname` 출력, 시간 표시 | 같음 (P는 `echo TIMEX`, `sh date` 추가) | 동일 계열 |

### 2.1 cost group이 왜 중요한가

- T는 경로를 4종(reg→reg, reg→out, in→reg, in→out)으로 나눠 **각 그룹의 최악 경로를 따로 최적화**한다.
- P는 그룹을 정의하지 않아서 Genus 기본값(클럭별 그룹)을 쓴다. V1 리포트에서도 그룹이 `default`(경로 없음)와 `MAIN_CLOCK` 두 개뿐이다 [확인: `19_..._qor.rpt`의 Cost Group 표].
- 따라서 V1에서는 입출력 경로와 reg→reg 경로가 **한 그룹의 최악 슬랙 기준으로 같이 최적화**된다 [추정]. 이 설계는 최악 경로가 CPU 내부(reg→reg)라 큰 차이는 없을 가능성이 높다. 그래도 4그룹으로 나누면 reg→reg 최악 경로가 여전히 지배적이어서, 다른 그룹 경로가 상대적으로 더 열심히 최적화된다.
- **V2 결정:** V1과 같은 조건 유지(그룹 정의 없음). 나중에 "cost group 분리"를 별도 실험으로 할 수 있다.

---

## 3. P vs M (V1 `script/` 안의 두 파일)

### 3.1 차이 요약

| 항목 | P (`syn_mcu_pad_top.tcl`) | M (`..._mmmc.tcl`) |
|---|---|---|
| 헤더 | 없음 | `generated from GENUS 17.10-p007_1` |
| `TOP_DESIGN` | `mcu_pad_top` | `cmsdk_mcu` |
| 폴더 생성 | `foreach ... file mkdir` 있음 | 없음 |
| 경로 | `/GPDK045/...` 절대 경로, `../1_RTL` | `../../../GPDK045/...` 상대 경로, `../RTL/` |
| 라이브러리 | `read_libs {slow, slow multibitsDFF, pads_SS}` | `read_mmmc cons/cmsdk_mcu.mmmc.view` (`read_libs`와 충돌해서 택일, 파일 주석에 명시) |
| `init_design` | 없음 | 있음 (`read_mmmc` 사용 시 필요) |
| preserve | 없음 | `set_db hinst:u_cmsdk_mcu_system .preserve true` (ARM 서브시스템 보호) |
| RTL 목록 | 자작 MCU 21개 | `cmsdk_mcu.v`, `verilog_smkcow/*`, `cortexm0_designstart/.../cmsdk_mcu_system_syn_final.v` |
| SDC | `source ./cons/mcu_pad_top.sdc` | **주석 처리**(SDC는 mmmc view 안에서 읽는 구조), `dont_use`만 source |
| `check_design` | `-unresolved` 포함 | 기본형만 |
| `check_timing_intent` 리포트 | `01_check_timing_intent.rpt` | `01_check_timing.rpt` |
| 마지막 리포트 | `report_summary` (파일 저장 없음) | `report_summary > 21_..._SYN_summary.rpt` |
| 출력 | 동일 (`write_design`, `write_hdl`, `write_sdc`, `write_sdf`) | 동일 (+ Tempus용 `write_db` 주석 없음) |

`diff`로 `syn_map` 이후 구간(136~213줄 vs 156~233줄)을 비교하면 **차이는 위 3줄(빈 줄 1, `report_summary` 저장 여부, Tempus용 주석 1)뿐**이다 [확인]. 즉 두 스크립트의 차이는 앞부분(설정, 라이브러리, 설계 읽기)에 모여 있다.

### 3.2 mmmc 방식과 단일 코너 방식

- **P(V1이 쓴 방식):** `read_libs`로 **slow 라이브러리만** 읽는다. SDC의 `set_operating_conditions -min_library fast...`는 fast가 읽히지 않아 SDC-208 경고가 나고 무시된다 [확인: V1 `log/all.log` 611행]. Genus는 setup(max) 코너 하나로 합성한다.
- **M(mmmc):** `read_mmmc`로 library set/operating condition/analysis view를 정의해서 **합성 단계에서도 setup/hold 코너를 같이 볼 수 있다.** `cons/mcu_pad_top.mmmc.view`가 V1에 있고(`FF_Min_1p10v_0c`, `SS_Max_0p90v_125c`), PnR용으로 쓰인 것으로 보인다 [추정].
- 두 방식은 **같이 쓸 수 없다**(M 파일 주석: `read_libs and read_mmmc commands conflicts each other`).

### 3.3 V2에서 어느 쪽을 쓰는가

**P 기반(단일 코너).** 이유: ① V1과 같은 조건, ② M은 ARM 서브시스템 전제라 그대로 못 씀, ③ hold는 PnR(Innovus/Tempus)의 MMMC로 확인한다.
mmmc 합성은 "SDC-208 경고 제거와 합성 단계 hold 확인"이 필요해지면 별도 실험으로 한다.

### 3.4 M을 그대로 쓸 수 없는 이유 [확인]

1. `cons/cmsdk_mcu.mmmc.view`를 읽지만 V1 `cons/`에는 `mcu_pad_top.mmmc.view`만 있다 (이름 불일치).
2. `RTL_SOURCES`가 `cortexm0_designstart/...` ARM 넷리스트를 가리킨다.
3. `TOP_DESIGN`이 `cmsdk_mcu`다.

공개 저장소 관점: M에는 ARM DesignStart 경로 문자열(`cortexm0_designstart`)이 들어 있다. 코드 내용은 아니고 경로 이름이지만, README 10장의 "cmsdk 관련 비공개" 원칙과 맞는지 판단이 필요하다. V2에는 M을 복사하지 않았다.

---

## 4. V2 스크립트가 템플릿과 다른 점 (최종 정리)

| 구분 | V2 처리 |
|---|---|
| T에는 있고 V2에는 없는 것 | `include setup_run.tcl`(설정은 스크립트 내부), cost group 4종 정의 + `_pretim.rpt`, `report_dp` 이름, `report_summary -directory` |
| V2에는 있고 T에는 없는 것 | `uniquify`, `optimize_merge_flops/latches false`, `auto_ungroup none`, effort high 3종, `dont_use_45nm.tcl`, `syn_opt` 및 이후 리포트 20여 종, `write_sdf` |
| V1 그대로 유지 | 위 전부 (패드 관련 항목 제외) |

## 5. 합성 전/후 확인 체크리스트

- [ ] V2 합성 로그에서 SDC-208 경고 외 새 에러/경고(SDC 관련) 없음
- [ ] `00_check_design.rpt`: unresolved, undriven, multidriven 모두 0
- [ ] cost group이 `default`, `MAIN_CLOCK` 두 개인지 (V1과 같은 구조)
- [ ] `19_..._qor.rpt`의 FF 수가 V1(1,816개)과 같은지 (패드 제거로 FF는 변하지 않아야 함. 다르면 래퍼/제약 영향 조사)
- [ ] 계층이 `mcu_core_top / u_mcu_top / uut1~uut7` 구조인지

## 6. 나중에 별도 실험 후보 (지금은 하지 않음, 한 번에 하나)

| 후보 | 목적 |
|---|---|
| cost group 4종 분리 (T 방식) | 입출력과 reg→reg를 따로 최적화했을 때 슬랙/면적 변화 |
| `interconnect_mode ple` | Genus/Innovus 지연 차이 확인 (`SYN_FLOW_COMPARISON.md` 2.2절) |
| mmmc 합성 (M 방식) | 합성 단계에서 hold 코너 포함, SDC-208 제거 |
| `optimize_merge_flops` 기본값(true)으로 | FF 병합 영향 확인 |
