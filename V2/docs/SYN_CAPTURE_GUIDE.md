# V2 (v1-core) 합성 캡처 가이드

기준: 사용자가 올린 V1 캡처 문서(`2_mcu_SYN.docx`)의 항목과 캡션 형식을 그대로 따른다.
V2는 **10 ns 한 번만** 합성했으므로 V1 문서의 20 / 4 / 2.5 / 5 ns 비교 섹션은 만들지 않는다.
저장 위치: `V2/docs/captures/` , 파일명은 아래 표의 번호를 앞에 붙인다. 모든 캡처에는 터미널/에디터 창 제목이나 경로가 보이게 한다.

> 주의: SDC가 수정되었다(I/O delay를 V1 값으로 복구). 이전 값(1.0 ns)으로 돌린 합성은 기준선이 아니므로, **수정된 SDC로 합성을 다시 돌린 뒤에 캡처한다.**

## 0. 캡처 전 확인 (수치 먼저 보고, 다르면 캡처 전에 알려줘)

| 확인 | 어디서 | 기대값 | 다르면 |
|---|---|---|---|
| 에러 없이 종료 | `log/all.log` 마지막 `Synthesis Finished` | 에러 0 | 로그 전달 |
| FF 수 | `report/19_..._qor.rpt` Sequential | **1,816** (V1과 동일) | 래퍼 구조 점검 |
| 인스턴스 수 | 같은 파일 Leaf Instance | 약 **5,241** (V1 5,256 − 패드 15) [추정] | 원인 확인 |
| 셀 면적 | 같은 파일 Cell Area | 약 **21,856 µm²** (V1 코어와 동일) [추정] | 원인 확인 |
| slack | 같은 파일 Critical Path Slack | 0에 가까운 양수 (V1 +2.3 ps) | 음수면 즉시 알려줘 |
| check_design | `00_check_design.rpt` | unresolved, undriven, multidriven 모두 0 | 그대로 전달 |
| 경고 | `log/all.log`에서 `SDC-208` | V1과 같은 경고만 | 새 에러/경고 전달 |

[추정] = V1 10 ns 결과(코어 21,856 µm², 칩 237,855 µm² 중 패드 약 216,000)에서 계산한 예상이다. 로그로 확인되기 전에는 "확인됨"으로 쓰지 않는다.

## 1. 캡처 목록 (V1 문서 순서 그대로)

| # | 캡처 | 파일 / 방법 | 보여야 할 것 | V1 대비 바뀌는 점 |
|---|---|---|---|---|
| 01 | 제약, 소스 | 에디터에서 `cons/mcu_core_top.sdc` (CLK_PERIOD, create_clock, I/O 지연, `set_input_transition`, `set_load`)와 `script/syn_mcu_core_top.tcl`의 `TOP_DESIGN`, `RTL_SOURCES`를 한 화면에 | top = `mcu_core_top`, 10 ns, 입출력 delay V1과 동일(0.1/0.01, 0.1/-0.01), 패드 `dont_touch` 없음 | 패드 15개 dont_touch가 사라짐 |
| 02 | 최상위 스키매틱 | Genus GUI에서 `mcu_core_top` 스키매틱 (V1 칩 레벨 캡처와 같은 방법) | 입력 7 / 출력 8 핀이 `u_mcu_top`에 직접 연결, 패드 셀 없음, 디버그 출력 4개 열림 | PADDI/PADDO가 없음 |
| 03 | 코어 내부 스키매틱 | `u_mcu_top` 내부 | 서브모듈 7개, 가운데 읽기 mux/주소 디코더 | V1과 동일해야 함 |
| 04 | check_design | `report/00_check_design.rpt` | Unresolved, Empty modules, Undriven, Multidriven 모두 0 | - |
| 05 | 합성 완료 로그 | `log/all.log` 끝부분 | 단계별 시간(GENERIC, MAPPED, OPT, FINAL), 총 시간, 최대 메모리, `Synthesis Finished` | 시간은 달라질 수 있음 |
| 06 | QoR 요약 | `report/19_mcu_core_top_SYN_qor.rpt` | 클럭 10,000 ps, slack, TNS 0, 위반 경로 0, 순차/조합 인스턴스, 셀 면적 | 패드가 빠져 면적이 약 1/11로 줄어듦 [추정] |
| 07 | 최악 setup 경로 | `report/20_mcu_core_top_SYN_timing.rpt` Path 1 | 시작점, 끝점, 경로별 지연, slack | 아래 2장 참고 |
| 08 | 계층별 면적 (1) | `report/09_mcu_core_top_SYN_area.rpt` (계층 표 상단) | `mcu_core_top` > `u_mcu_top` 총 면적 | 최상위가 칩에서 코어로 바뀜 |
| 09 | 계층별 면적 (2) | 같은 파일의 모듈별 면적 | RAM / UART / CPU / ROM / 기타 비율 | 비율이 V1 코어와 같아야 함 |
| 10 | 셀 종류별 면적, 전력 | `report/13_mcu_core_top_SYN_gate.rpt` | 순차/조합 소자 수, 셀 종류별 면적과 전력 | 패드 셀(PADDI/PADDO)이 목록에서 사라짐 |
| 11 | 전력 | `report/18_mcu_core_top_SYN_pwr.rpt` | 총 전력, 계층별 전력 (FF / 로직 / 클럭) | 패드 전력(V1 78.7%)이 없어 총 전력이 크게 줄어듦 |
| 12 | 계층 구조 | `report/14_mcu_core_top_SYN_hier.rpt` | `mcu_core_top` > `u_mcu_top` > `uut1~uut7`, 계층 인스턴스 개수, blackbox 없음 | 최상위 이름만 다름 |
| 13 | (선택) 가산기 구조 | `report/11_..._datapath.rpt`와 `report/13_..._gate.rpt`에서 `ADDF`/`ADDH` 셀 수 | `ADDFX1`, `ADDHX1` 개수 | 체크리스트 1번(가산기 실제 구조 확인) 증거용. 수치만 확인해서 알려줘 |

## 2. 07번(최악 경로) 주의

- V1 10 ns 합성의 최악 경로는 `r_pc_reg_4 → UART r_count_reg_4`였다(데이터 경로 9,789 ps, slack +2 ps). 느슨한 제약에서 면적 위주로 최적화한 결과다.
- V2도 비슷하게 나올 가능성이 높지만, 경로가 다르게 나와도 문제는 아니다. **경로가 달라지면 그 사실 자체를 기록**한다 (원칙 3: 기대와 다른 결과도 기록).
- 캡처에는 Startpoint, Endpoint, Data Path, Slack 줄이 반드시 포함해야 한다.
- PPT 계열 설명("PC → ROM → 가산기 → 주소 디코드 → FIFO enable")은 10 ns 합성 경로로 **직접 확인하기 전에는 쓰지 않는다.** 이 경로는 Tempus post-route 결과에서 나온 것이다.

## 3. 캡션 템플릿 (V1 문서 형식)

값은 실제 리포트에서 읽어서 채운다. 괄호 안 값은 예상치이므로 그대로 복사하지 않는다.

- **01 제약/소스:** `mcu_core_top 합성 제약과 소스. top은 mcu_core_top, 클럭 주기 10 ns, 입력 delay max 0.1 / min 0.01 ns, 출력 delay max 0.1 / min -0.01 ns(V1과 동일), 입력 transition 0.1 ns, 출력 load [PADDO/A 값 확정 후 기입]. 패드가 없어 dont_touch 항목이 없다.`
- **02 최상위 스키매틱:** `mcu_core_top 합성 후 스키매틱(코어 단독). 패드 없이 핀 15개(입력 7, 출력 8)가 mcu_top에 직접 연결된다. mcu_top의 디버그 출력(pc, inst, aluout, memout)은 연결하지 않아 열려 있다.`
- **06 QoR:** `mcu_core_top 합성 QoR(Genus, GPDK045 slow 코너): 클럭 10 ns에서 Critical Path Slack [값] ps, TNS 0, 위반 경로 0. 순차 소자 [값]개, 조합 소자 [값]개, 셀 면적 [값] µm².`
- **11 전력:** `합성 후 전력 추정(slow 코너, 클럭 10 ns, 기본 활동도 가정): 총 [값] mW. 플립플롭 [값], 로직 [값], 클럭 [값] mW.` (패드가 없어서 V1 pad 결과와 직접 비교하지 않는다. 문서 4장 원칙)

## 4. 캡처 후 할 일

1. `V2/docs/captures/`에 저장 → 알려주면 비교표(문서 6장)의 v1-core 열을 채운다.
2. 수치는 로그와 대조한 것만 "확인됨"으로 쓴다.
3. 합성 확인이 끝나면 다음은 floorplan 스크립트 수정(utilization 0.6~0.7, 핀 배치, 전원 링/스트라이프)이다.
