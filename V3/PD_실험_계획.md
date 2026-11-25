# PD 실험 계획: (1) 4 ns PnR timing closure, (2) 이용률 sweep

V3 10 ns 플로우가 끝난 뒤 PD 포트폴리오용으로 추가하는 실험 두 개의 **순서, 방법, 기록할 값**을 정리한 문서다. 새 세션은 `V3/README.md`와 이 파일을 먼저 읽는다.
진행 방식은 지금까지와 같다: 사용자가 서버에서 직접 수정/실행하고, Claude는 안내·해석·캡션만 한다 (`CLAUDE.md`의 "시킨 것만 한다").

---

## 0. 왜 하는가
- 10 ns에서는 모든 단계가 여유 있게 통과해서 "문제 → 분석 → 수정" 과정이 없었다. PD 포트폴리오에서는 이 과정이 핵심이다.
- README의 "도달한 최소 클럭 주기" 정의는 **합성과 postRoute setup/hold가 모두 0 이상**이다. 지금 값(V2 3.9 ns, V3 3.97 ns)은 합성 기준뿐이라 PnR 기준이 비어 있다.
- 이용률(utilization)은 PD의 대표 trade-off(면적 vs 배선성 vs 타이밍)를 데이터로 보여줄 수 있다.

## 순서 요약
| 순서 | 실험 | 대상 | 비고 |
|---|---|---|---|
| 1-1 | 4 ns PnR (V3) | `V3/TOP/5_PNR_4ns` | 0~5단계 + Tempus |
| 1-2 | 4 ns PnR (V2) | 서버 `~/sweep_v2/5_PNR_4ns` | V3와 똑같은 절차 |
| 1-3 | 위반 분석과 closure | 둘 다 | 위반이 없으면 생략하고 1-4로 |
| 1-4 | PnR 기준 통과 주기 찾기 | 둘 다 | 필요할 때만, 최대 2점 |
| 2 | 이용률 sweep | V3 넷리스트 | 별도 실험 (폴더 이름 사용자 확인) |

---

## 1. 4 ns PnR + timing closure

### 1-0. 원칙
- 넷리스트와 제약은 **4 ns 합성 결과**(`3_SYN/4ns/mapped/`)를 쓴다. 두 버전 모두 합성에서 4 ns를 통과한 가장 빠른 공통 주기라서 4 ns를 고른다.
- 플로우 스크립트(0~5단계, 옵션)는 10 ns와 **같은 것**을 쓴다. 바꾸는 것은 입력 파일 경로뿐이다.
- **10 ns PnR 폴더(`5_PNR`)는 건드리지 않는다.** 별도 폴더에서 돌린다.
- 전력 계산 주기(`set_default_switching_activity -period 8.0`)는 그대로 둔다. 모든 버전 비교 조건을 맞추기 위해서다 (캡션에 "8 ns 기준" 명시).
- **V2와 V3에는 같은 수정만 적용한다.** 한쪽에만 ECO나 옵션 변경을 하면 비교가 깨진다. 수정은 하나씩 하고 매번 기록한다.

### 1-1. V3 세팅과 실행
1. 폴더: `V3/TOP/5_PNR_4ns`에 `5_PNR`의 스크립트만 복사한다 (`0_InitDesign.tcl` ~ `5_ChipFinish.tcl`, `mcu_core_top.mmmc.view`, `tempus.tcl`, `clean.tcl`). `.dat`, 로그, 산출물은 복사하지 않는다. `reports/clock`, `reports/timing`, `snap` 폴더를 미리 만든다.
2. PnR용 SDC: `3_SYN/4ns/mapped/mcu_core_top_syn_final.sdc`를 `5_PNR_4ns/mcu_core_top_pnr.sdc`로 복사하고 `set_ideal_network [get_ports clk]`, `[get_ports clrn]` 두 줄을 지운다(또는 `#`). `create_clock -period 4.0`인지 확인한다. **`3_SYN/4ns/mapped/` 원본은 고치지 않는다.**
3. 경로만 수정 (기록 대상):
   - `0_InitDesign.tcl`: `init_verilog ../3_SYN/4ns/mapped/mcu_core_top_syn_final.v`
   - `mcu_core_top.mmmc.view`: `-sdc_files [list ./mcu_core_top_pnr.sdc]` (V2 방식)
4. 실행: `innovus -files 0_InitDesign.tcl` 후 같은 세션에서 `source 1_...` ~ `source 5_ChipFinish.tcl`. 단계마다 로그를 남긴다.
5. Tempus: `read_design RouteDesign.dat mcu_core_top` 후 `report_timing -late/-early -max_paths 1`, `check_timing`, `report_annotated_parasitics`, `report_analysis_coverage`. 결과는 `reports/timing/`에 파일로도 저장한다.

### 1-2. V2 세팅과 실행
- 서버 `~/sweep_v2/`에는 `1_RTL`, `3_SYN`(백업 `4ns/` 포함)만 있다. `~/PROJ4/V2/TOP/5_PNR`의 스크립트를 `~/sweep_v2/5_PNR_4ns`로 복사하고 1-1의 2~5번과 똑같이 한다 (`init_verilog ../3_SYN/4ns/mapped/...`).
- **V2 원본 폴더(`~/PROJ4/V2`)는 건드리지 않는다.** V2 4 ns 결과는 저장소 밖에 있으므로 캡처와 로그 사본으로 기록한다.

### 1-3. 기록할 값 (V2, V3 각각)
| 단계 | 값 |
|---|---|
| 0 | die/코어 크기, prePlace WNS, Density |
| 2 | preCTS setup WNS/TNS/위반 수, DRV, 혼잡도 overflow |
| 3 | CTS 직후·최적화 후 setup WNS, 최적화 후 hold WNS, 클럭 버퍼 수, skew, 삽입 지연 |
| 4 | postRoute setup/hold WNS·TNS·위반 수, DRV, Density, 정적 전력 |
| 5 | DRC, 연결성, 필러 수 |
| Tempus | setup/hold 최악 경로(구간 분해), Met/Violated 수 |

**10 ns와 비교할 포인트:** 단계별 WNS가 어디서 무너지는지, 셀 면적 증가(합성 4 ns: V2 28,784 / V3 30,989 µm²)가 코어 크기와 밀도에 어떻게 반영되는지, 클럭 트리와 전력 변화.

### 1-4. postRoute에서 위반이 나면 (closure 절차)
분석 먼저, 수정은 하나씩.
1. **원인 분석** (Tempus 최악 경로):
   - 합성 4 ns 최악 경로(데이터 3,787/3,852 ps)와 같은 경로인지, 구간별로 무엇이 늘었는지 (셀 지연 vs 배선 지연).
   - 클럭: 합성은 ideal 클럭(source 0.2 + network 0.2 ns 가정), PnR은 실제 클럭 트리. launch/capture 삽입 지연 차이(skew)가 slack에 얼마나 영향을 줬는지.
   - 위반 경로 수와 분포 (`report_timing -max_paths 10`, `report_analysis_coverage`).
2. **수정 단계 (순서대로, 각 단계 후 WNS/TNS 기록):**
   - (a) 스크립트에 이미 있는 `optDesign -postRoute -setup / -hold` 결과를 먼저 기록한다 (4단계에 포함).
   - (b) 남은 위반: Tempus에서 경로 분석 → 버퍼/사이징 ECO → `write_eco` → Innovus에서 `source innovus.eco` 후 ECO 라우팅·`optDesign -postRoute` (V1에서 만든 `6_ECO.tcl`, `tempus.tcl` Practice 1 흐름).
   - (c) 그래도 안 닫히면 4 ns는 "PnR 기준 실패"로 기록하고 1-5로 간다.
   - (a)~(b)에서 쓴 명령과 옵션은 V2, V3에 똑같이 적용한다.
3. **hold:** 입력 지연 최소값 0.01 ns 조건 때문에 IO hold가 얇다. 위반이 나면 FE_PHC 버퍼 수와 위치를 기록한다.

### 1-5. PnR 기준 통과 주기 (필요할 때만)
- 4 ns가 PnR에서 실패하면 **4.5 ns**, 그다음 **4.25 ns**(또는 5 ns) 순으로 최대 2점만 더 본다. 촘촘하게 끌고 가지 않는다.
- 각 점은 **그 주기로 새로 합성한 넷리스트**를 쓴다 (SDC 17번 줄만 변경 → 합성 → `<주기>/` 백업 → 1-1과 같은 PnR). V2, V3 둘 다.
- 결과: "PnR 기준 도달 최소 주기" = 합성과 postRoute setup/hold가 모두 0 이상인 가장 짧은 주기.

### 1-6. 산출물 정리
- 1-1~1-5가 끝나면 `V3/README.md`에 진행 기록과 비교표(10 ns / 4 ns, V2 / V3)를 추가한다.
- 4 ns PnR 폴더의 큰 산출물(.dat, GDS, SDF)을 저장소에 올릴지는 사용자가 정한다.

---

## 2. 이용률(utilization) sweep

### 2-0. 원칙
- 바꾸는 것은 `0_InitDesign.tcl`의 `floorPlan -site CoreSite -r 1 0.6 30 30 30 30`에서 **0.6 숫자 하나**다. 나머지 스크립트, SDC, 넷리스트는 같다.
- 가산기 비교가 아니라 floorplan 실험이므로 **V3 한 버전**으로 한다.
- 계획서의 "전력/면적 축"(V5 후보)에 해당한다. **폴더 이름/버전 번호는 시작 전에 사용자에게 확인한다** (제안: `V5/TOP/5_PNR_u060`, `_u070`, `_u080`, ...).

### 2-1. 조건
- 넷리스트: **V3 10 ns 합성**(`V3/TOP/3_SYN/10ns/mapped/`) 기본. 10 ns PnR(이용률 0.6)이 기준점이다.
- 이용률: **0.6(기존 결과 재사용) → 0.7 → 0.8**, 결과를 보고 0.85, 0.9까지 깨지는 지점(혼잡도 overflow, DRC, 배치 실패)을 찾는다.
- 1번 결과가 흥미로우면(4 ns에서 겨우 닫힘) 4 ns 넷리스트로 0.6/0.7/0.8을 한 번 더 하는 것도 선택지다. 타이밍 영향이 10 ns보다 크게 보인다.
- PnR SDC 처리, 경로 수정 방법은 1-1과 같다.

### 2-2. 기록할 값 (이용률마다)
| 범주 | 값 |
|---|---|
| 면적 | die/코어 크기, 코어 면적, 최종 Density, 필러 수 |
| 배선성 | 혼잡도 overflow H/V, Usage, 총 배선 길이(`reportWire` 또는 streamOut 도형 수), DRC |
| 타이밍 | preCTS / postCTS / postRoute setup·hold WNS, 클럭 트리 버퍼 수, skew, 삽입 지연 |
| 전력 | 정적 전력 (8 ns 기준) |
| 그림 | floorplan, 배치, Density map, 혼잡도 맵 |

### 2-3. 기대(가설)와 해석 포인트
- 가설: 이용률을 높이면 코어 면적은 줄고, 배선 길이·클럭 트리는 짧아져 타이밍이 좋아질 수 있지만, 어느 지점부터 혼잡도와 DRC가 급격히 나빠진다.
- 해석 포인트: 타이밍이 좋아지는 구간과 배선성이 무너지는 구간의 경계, 그 원인(셀 밀집 지역, 핀 근처 등).

---

## 3. 진행 체크리스트
- [ ] 1-1 V3 4 ns PnR (0~5 + Tempus)
- [ ] 1-2 V2 4 ns PnR (0~5 + Tempus)
- [ ] 1-3 비교표 작성 (10 ns vs 4 ns, V2 vs V3)
- [ ] 1-4 위반 분석과 closure (위반이 있을 때)
- [ ] 1-5 PnR 기준 통과 주기 (필요할 때만)
- [ ] 2 폴더 이름 확인 → 이용률 0.7, 0.8 (→ 0.85, 0.9)
- [ ] README와 포트폴리오 문서(`V3/V3_portfolio.docx`) 갱신
