# 합성부터 재수행 계획: PD 시나리오와 PI 시나리오

작성 근거: repo(`main` 24f42a3)의 스크립트와 로그, 포트폴리오 PPT/HTML 원본, 사용자가 보낸 Tempus/SDC 캡처.
표기 규칙: **[확인됨]** repo 파일이나 캡처로 직접 본 사실, **[가정]** 아직 확인하지 않은 것, **[문서확인]** 툴 22.17 문서로 명령/옵션을 확인해야 하는 것.
명령은 repo 스크립트에 이미 있는 것만 구체적으로 적었고, 그 밖은 추측하지 않고 [문서확인]으로 남겼다.

---

## 0. 먼저 알아야 할 현재 상태

### 0.1 repo는 서로 다른 실행이 섞여 있다 [확인됨]
| 위치 | 내용 | 가리키는 실행 |
| --- | --- | --- |
| `3_SYN/mapped/mcu_pad_top_syn_final.sdc` | `create_clock -period 5.0`, 포트별 `set_driving_cell PADDI` | 5 ns 재실행 (수정 전 SDC) |
| `5_PNR/innovus.log` 등 | prePlace WNS +3.342 ns | 10 ns 실행 |
| 포트폴리오 본문 수치 | 10 ns 기준 | 10 ns 실행 |

- 합성 산출물은 5 ns 재실행이 덮어썼고 P&R 로그는 10 ns 때 것이 남았다. 10 ns 때의 `mapped/*.sdc`와 넷리스트는 repo에 없다.
- Innovus는 `3_SYN/cons/mcu_pad_top.sdc`가 아니라 **Genus가 쓴 `mapped/mcu_pad_top_syn_final.sdc`** 를 읽는다(`5_PNR/mcu_pad_top.mmmc.view`). 따라서 "어떤 SDC로 돌렸나"는 cons 파일이 아니라 mapped 파일의 해시로 기록해야 한다.
- 결론: 합성부터 다시 하는 판단은 옳다. 지금 repo로는 어떤 수치도 하나의 실행으로 재현되지 않는다.

### 0.2 스크립트를 읽다가 발견한 점 [확인됨]
1. `4_RouteDesign_PowerAnalysis.tcl`의 `set_default_switching_activity -input_activity 0.2 -period 8.0 ;# 8ns operation`. 최종 클럭은 10 ns인데 전력 분석 주기는 8 ns다. 포트폴리오의 "5.36 mW"는 이 조건에서 나온 값이다. 그대로 쓰면 안 된다.
2. 같은 스크립트에서 `setDelayCalMode -SIAware false`. 크로스토크(SI)를 끄고 slack을 보고 있다. 보고한 WNS는 SI 영향이 빠진 값이다.
3. Rail IR-drop 분석이 "Some Errors, Skip This step, Alternatively, Use Voltus"로 주석 처리돼 있다. 대신 `5_PNR/run1/`에 정적 전류 파일(`static_VDD.ptiavg`, `static_VSS.ptiavg`, `voltus_power.ptifiles`)이 이미 만들어져 있다. IR drop 분석의 입력은 있고 분석만 안 했다.
4. Genus는 `syn_generic`(물리 정보 없는 모드)로 돌았다. `syn_generic -physical`은 주석 처리돼 있다. `read_physical`과 `read_qrc`는 읽지만 배치 기반 배선 지연은 반영하지 않는다고 보는 것이 자연스럽다 **[가정: Genus 로그의 wire 모델 항목으로 확인]**.
5. Genus 라이브러리는 slow(SS)만 읽는다(`LIB_LIST`). Innovus는 setup은 `FUNC_SS_WORST`, hold는 `FUNC_FF_BEST` 2코너다.
6. `5_PNR/tempus.tcl`과 `6_ECO.tcl`에 hold ECO 흐름의 뼈대가 이미 있다: Tempus에서 `add_repeater -cell <BUF> -net <net>` → `write_eco -format innovus -output innovus.eco` → Innovus에서 `restoreDesign RouteDesign_ECO.dat` → `source innovus.eco` → `optDesign -postRoute -setup/-hold` → `extractRC` → `timeDesign` → `verify_drc`. 즉 ECO 후 P&R은 처음부터 다시가 아니라 **증분 ECO 라우팅**이다. 이것이 HANDOFF 미결 1번의 답이다 [사용자 확인 요청].
7. 전력 패드: 코어 전원 패드 VDD/VSS가 4면에 쌍으로 수동 배치(pad5/6, 17/18, 29/30, 41/42)돼 있고 파워 플랜은 링 폭 5 µm, Metal10(수직)/Metal11(수평) 스트라이프 폭 5, 간격 5, set-to-set 100 µm이다(`1_PowerPlan.tcl`). PI 실험의 조절 변수가 이미 스크립트에 있다.

---

## 1. 공통: 모든 시나리오 전에 하는 일 (Phase 0)

### 0-A. 현재 상태 보존
- `git tag snapshot-before-resynth` 로 현재를 고정한다.
- 이후 실행은 `runs/<이름>/` 으로 폴더를 분리하고 덮어쓰지 않는다. 예: `runs/pd_5ns_base/`, `runs/pi_grid_p100/`. `TOP` 폴더를 통째로 복사해 상대경로(`../3_SYN/mapped`)가 그대로 유지되게 한다.
- 각 실행 폴더에 `MANIFEST.md`를 둔다: 클럭 주기, `mapped/*.sdc`의 sha256, 넷리스트 sha256, 라이브러리 목록, 툴 버전, 실행 날짜, 단계별 WNS/TNS. 포트폴리오의 모든 수치는 한 manifest에서만 가져온다.

### 0-B. 5 ns 첫 실행 vs 재실행 원인 규명 (합성 재수행 전에 먼저, 로그만으로)
목적: init에서 WNS −6.213 ns였던 이유를 찾는다. 재실행은 같은 5 ns가 닫혔다(setup +0.075, hold +0.052). 이 차이가 이 프로젝트에서 가장 값진 질문이다.
첫 5 ns 실행의 로그가 남아 있어야 하므로 **먼저 사용자에게 로그 존재 여부를 확인한다**. 없으면 0-B는 "재현 불가, 이후 실행에서 같은 지점을 계측"으로 바꾼다.

비교 항목(있는 것만):
1. `mapped/*.sdc` diff (주기, driving cell, uncertainty, latency, 포트 지연)
2. `mcu_pad_top.mmmc.view` diff (라이브러리, 코너, RC 코너)
3. Genus 로그: 읽은 라이브러리와 wire 모델, `check_timing_intent`
4. Innovus init의 `timeDesign -prePlace` 보고서에서 **같은 경로**(`r_pc_reg_2` → `r_mem_reg_7_6/E`)의 단별 지연을 Genus 보고서와 나란히 놓기
5. 그 경로에서 단당 지연이 큰 셀과 net의 fanout, 전달 지연(transition), max_cap 위반 여부

판정표:
| 관찰 | 해석 | 다음 행동 |
| --- | --- | --- |
| 두 실행의 SDC/MMMC가 다름 | 설정 문제 | 무엇이 달랐는지 기록. 이것이 "해결한 문제 2"의 근거 |
| 같은 SDC인데 prePlace 경로 지연이 다름 | 툴 간 지연 모델 차이(wire, 코너, 라이브러리) | 0-C 상관 실험으로 |
| 첫 실행에서만 high-fanout net의 transition이 큼 | 합성이 buffering 없이 넘김 | 합성 설정과 Innovus prePlace 최적화 여부 확인 |

원인을 확정하지 못하면 "확인한 것 / 배제한 것 / 남은 가설"로 쓴다. 추측을 원인처럼 쓰지 않는다.

### 0-C. 합성-PnR 상관 측정 (두 시나리오 공통 기반)
같은 최악 경로 3개를 Genus(`syn_opt` 후), Innovus(`prePlace`, `postRoute`), Tempus에서 뽑아 단별 지연을 표로 만든다. 이것으로 "Genus 51 ps vs Innovus 185 ps" 의문의 실체를 정량화한다. 필요하면 `syn_generic -physical` 계열(주석 처리돼 있음, [문서확인]: 필요한 입력과 옵션)로 합성하고 상관이 개선되는지 비교한다. 이 실험은 PD 쪽에서 본격적으로 쓴다.

### 0-D. SDC를 하나로 고정
- 하나의 SDC 템플릿에서 클럭 주기만 변수로 두고, `set_input_transition 0.1`이 켜진 수정 후 버전을 기준으로 한다(PADDI 줄은 주석).
- 파일 상단에 실행 이름과 날짜를 주석으로 남긴다. 5 ns 재실행의 수정 전 SDC는 "비교용 별도 실행"으로 `runs/`에 보존하고, 본문에서는 명시적으로 다르게 표기한다.

---

## 2. PD 시나리오: "닫히는 최고 주파수를 찾고, hold를 의도적으로 깨서 ECO로 고친다"

대상 직무: Physical Design(P&R, timing closure).
한 줄 서사: 같은 설계를 10 ns로 도망치지 않고 PnR 입구에서 목표 주기를 검증해 닫히는 한계를 찾고, hold 위반을 의도적으로 만들어 ECO로 고친 전후를 수치로 보인다.

### PD-1. 주기 스윕과 PnR 입구 게이트
- 합성 목표 4개: **10, 5, 4 ns**와 한계 탐색용 1개(예: 3.3 ns, 합성에서 닫히는지 먼저 본다. 2.5 ns는 SDC 수정 후 합성에서만 +0.7 ps였으므로 PnR 후보로는 어렵다).
- 각 목표마다 합성 → Innovus init → `timeDesign -prePlace`까지를 **게이트**로 한다. 게이트 기준을 미리 정한다: prePlace WNS ≥ 0이면 전체 flow 진행, 아니면 그 지점에서 멈추고 원인을 적는다.
- 합성 slack과 init slack의 차이(합성-PnR 상관)를 주기별로 표로 만든다. 0-C의 데이터를 쓴다.
- 산출: 주기별 `합성 slack / init WNS / postRoute WNS·hold WNS / 면적 / 셀 수` 표.
- 합격 기준(예): postRoute setup, hold WNS ≥ 0, DRC 0, connectivity 0, Conformal 2회 PASS.

### PD-2. 합성 옵션이 PnR 결과에 미치는 영향 (상관 개선 실험)
- 같은 주기(5 ns)로 일반 합성과 물리 인식 합성(`-physical`, [문서확인])을 비교한다.
- 비교 지표: 합성 slack과 init WNS의 차이, 최종 면적, 합성 시간.
- 결과가 개선이 아니어도 "이 설계에서는 효과가 없었다"로 기록한다.

### PD-3. 의도적 hold 위반과 ECO (처음부터 실험으로 명시)
**의도:** 기본 상태는 hold WNS +0.05 ns로 고칠 위반이 없다. ECO 절차를 보이려면 위반이 필요하므로, 다음을 포트폴리오에 먼저 적는다. "hold 위반은 SDC의 hold uncertainty를 키워서 의도적으로 만들었다. 자연 발생한 위반이 아니다."
1. 기준선: 최종 P&R 상태에서 FF 코너 단일 분석(`FUNC_FF_BEST`)의 hold WNS/TNS/위반 경로 수.
2. 위반 생성: SDC에 `set_clock_uncertainty -hold <값>`을 추가하는 방법을 쓴다(표준 SDC). 값은 위반이 수십 개 나오는 정도로 정한다(미리 정한 값을 문서에 기록, 결과를 보고 값을 바꾸지 않는다).
3. 위반 확인: Tempus `report_timing -early`, `report_analysis_coverage`.
4. 수동 ECO (교수님 방식, repo 템플릿): Tempus에서 위반 경로의 끝점 net에 `add_repeater`로 지연 버퍼 삽입 → `write_eco -format innovus`.
5. 자동 ECO와 비교: 같은 위반에 대해 Innovus `optDesign -postRoute -hold` 결과.
6. 반영: Innovus `restoreDesign` → `source innovus.eco` → `optDesign -postRoute -setup/-hold` → `extractRC` → `timeDesign` → `verify_drc` (`6_ECO.tcl` 순서).
7. 재확인: 같은 조건으로 Tempus STA, setup이 깨지지 않았는지.
8. 영향 확인: ECO 후 넷리스트로 Conformal(합성↔PnR), best 코너 SDF로 post-layout 시뮬(PASS 확인).
- 산출 표: `수동 ECO / 자동 ECO` × `hold WNS, TNS, 위반 수, 삽입 버퍼 수, 면적 증가, setup WNS 변화, DRC`.
- 이 실험은 HANDOFF 7번(ECO 방식 불확실)과 미결 1번을 함께 닫는다. 정확한 Tempus ECO 옵션은 [문서확인].

### PD-4. SI 영향 확인 (가능하면)
- 지금 `-SIAware false`다. SI를 켜고(조건은 [문서확인], mmmc의 `-si` cdb 줄이 주석 처리돼 있어 라이브러리 지원 여부부터 확인) setup/hold WNS가 얼마나 달라지는지 비교한다.
- 지원이 안 되면 "SI 분석은 하지 않았고, 그래서 WNS는 SI 제외 값"이라고 한계에 명시한다. 이 문장은 지금도 필요하다.

### PD-5. (선택) CTS 목표 스큐와 hold의 관계
- `set_ccopt_property target_skew 0.01`로 요청했지만 실제 스큐는 0.165 ns였다. 목표 스큐를 바꿔(예: 0.05, 0.1, 0.2) hold slack과 클럭 버퍼 수가 어떻게 달라지는지 본다. 비용이 크면 생략한다.

### PD-6. (선택, 병목 연구) 가산기 구조 비교
- 최악 경로의 32비트 ripple-carry 가산기(약 1.67 ns). RTL 연산자가 `+`이므로 합성 설정으로 구조를 바꿀 수 있는지는 [문서확인]. RTL을 바꾸면 Conformal 입력이 달라지므로 범위를 정하고 한다.
- 별도 ALU/MAC 프로젝트가 있으니 여기서는 링크 한 줄로 충분하다. 시간이 부족하면 하지 않는다.

### PD 발표 슬라이드 구성 (약 14장)
1. 요약: 닫힌 최고 주파수, hold ECO 전후, 해결한 문제 3개
2. 설계와 조건(스펙, SDC, 코너, 합격 기준)
3. 문제 ①: 입력 구동 SDC 모델 오진(2.5 ns)
4. 문제 ②: 5 ns 첫 실행 −6.2 ns의 원인 추적 (0-B)
5. 합성-PnR 상관 (0-C, PD-2)
6. 주기 스윕과 게이트 결과표 (PD-1)
7. 최종 실행의 P&R 요약(floorplan, CTS, route)
8. 최종 실행의 STA(Tempus)와 Innovus 일치
9. **hold ECO** 설계(의도 명시, 위반 생성 방법)
10. hold ECO 전후와 수동/자동 비교
11. ECO 후 검증(Conformal, 시뮬)
12. 문제 ③: SDF 0.17% → 91.99%
13. 한계(SI 미분석, GDS 서명용 DRC/LVS 없음 등)
14. 부록: flow 단계별 캡처

---

## 3. PI 시나리오: "전원 그리드가 얼마나 얇아져도 버티는지 정량화한다"

대상 직무: Power Integrity(IR drop, EM, 전원망 설계).
한 줄 서사: 정적 전력 분석만 있던 설계에 IR drop 분석을 붙이고, 전원 그리드(스트라이프 간격과 폭, 전원 패드 수)를 바꿔가며 "마진이 얼마나 있고, 어디부터 깨지는지"를 정량화한다.

**정직한 전제:** 코어 밀도 9.5%, 코어 전력이 mW 단위라 기본 그리드의 IR drop은 매우 작을 가능성이 크다 **[가정: 측정 전에는 모름]**. 그래서 이 시나리오의 핵심은 "문제가 있었다"가 아니라 "마진을 측정하고, 그리드를 일부러 줄여 한계 지점을 찾았다"이다. 의도적 스트레스 실험임을 처음부터 적는다.

### PI-0. 전력 기준선 정리 (0.2의 1번 오류 수정)
- 전력 분석 주기를 실제 클럭과 같게 맞춘다(`set_default_switching_activity -period`를 클럭 주기와 동일하게). 기록: 어떤 주기로 분석했는지.
- 활동도: 기본 0.2 가정과 별개로, 가능하면 실제 프로그램의 시뮬레이션 활동도를 사용한다. `2_SIM`에 파형 덤프(.trn)가 있으나 `read_activity_file`이 받는 형식(VCD 등)으로 변환 가능한지는 [문서확인, 확인 필요]. 안 되면 0.2 가정을 그대로 쓰고 한계에 적는다.
- 전력 분해: 패드 대 코어. 5 ns 합성 전력 11.17 mW 중 패드가 78.7%(8.79 mW)이므로, **코어만의 전력**을 따로 보고해야 IR drop 이야기가 맞는다.
- 산출: `주기 × (총, 패드, 코어, 누설)` 표.

### PI-1. 정적 IR drop 기준선 (Voltus, [문서확인])
- 이미 있는 `run1/static_VDD.ptiavg`, `static_VSS.ptiavg`, `voltus_power.ptifiles`를 입력으로 쓴다. Innovus 내장 rail 분석은 이 환경에서 에러가 났으므로 Voltus를 쓴다.
- **먼저 확인할 것:** Voltus 라이선스와 실행 가능 여부, PG 추출에 필요한 기술 파일(`gpdk045.tch`는 QRC 쪽에 있음), 패드 VDD/VSS 핀을 전압원으로 지정하는 방법. 안 되면 시나리오 3 전체를 보류한다(이 부분이 병목이다).
- 합격 기준을 **분석 전에** 정한다. 예: 최악 VDD+VSS drop 합 ≤ 공칭 전압의 5%(이것은 이 프로젝트에서 선택한 기준이지 표준이 아니다. 문서에 그렇게 적는다). 라이브러리 이름이 1v0이고 분석 코너가 0.9 V(SS), 1.1 V(FF)이므로 어느 코너 전압을 기준으로 삼는지도 명시한다.
- 산출: 최악 drop(mV, %), 평균 drop, 최악 위치(맵 이미지), 전류가 큰 영역과의 상관.

### PI-2. 전원 그리드 설계 DOE (핵심 실험)
조절 변수(모두 repo 스크립트에 있음):
| 변수 | 기본값 | 후보 |
| --- | --- | --- |
| 스트라이프 set-to-set 거리 | 100 µm | 50, 100, 200, 400 |
| 스트라이프 폭 | 5 µm | 3, 5, 8 |
| 코어 전원 패드(VDD/VSS 쌍) 수 | 4쌍(8개) | 4쌍, 2쌍(스트레스), 필요시 6쌍(예약 슬롯 이용) |
- 한 번에 한 변수만 바꾼다(OFAT). 조합 폭발을 피하고 비교가 명확하다.
- 변수마다 `1_PowerPlan.tcl`부터 다시 flow를 돌린다(`runs/pi_<변수>_<값>/`). 같은 합성 넷리스트와 SDC, 같은 활동도를 쓴다. 배치가 달라지므로 전류 분포가 조금 달라진다는 한계를 적는다.
- 각 실행에서 기록: 최악 IR drop, 합격 기준 위반 여부, 사용한 Metal10/11 트랙 비율(배선 자원 비용), DRC/connectivity, 타이밍 WNS 변화.
- 핵심 질문과 산출 그래프: "합격 기준을 만족하는 **가장 성긴 그리드**는 무엇이고, 기본 그리드는 얼마나 과설계였나." x축 스트라이프 간격, y축 최악 IR drop, 합격선을 가로선으로.
- 위반이 안 나오는 범위에서 멈추면 "그리드를 이만큼 줄여도 안전"이 결과다. 전원 패드 수를 줄이는 쪽이 가장 먼저 한계를 보일 가능성이 높다 [가정].

### PI-3. EM(전자이동) 점검 (조건부)
- EM 규칙 데이터가 GPDK045 환경에 있는지 [문서확인, 확인 필요]. 있으면 전원 스트라이프와 비아의 전류 밀도를 점검하고 PI-2의 가장 성긴 그리드에서 위반 여부를 본다. 없으면 "EM은 점검하지 않았다"를 한계에 쓴다.

### PI-4. (선택) 디커플링 커패시터와 동적 IR drop
- 라이브러리에 DECAP2~DECAP10이 있다(TECHLIB-302 경고의 대상). 동적 분석은 벡터(활동도 파일)가 필요하고 환경 지원은 [문서확인]. 정적 분석이 끝나고 시간이 있을 때만 한다.

### PI-5. (선택) 주파수에 따른 전력 비교
- 20/10/5/4 ns에서 코어/패드 전력을 같은 조건으로 비교한다(합성 전력은 이미 있음). PD 시나리오의 주기 스윕 결과를 재사용한다.

### PI 발표 슬라이드 구성 (약 14장)
1. 요약: 기준선 IR drop, 가장 성긴 합격 그리드, 전원 패드 수 한계
2. 설계와 조건(스펙, 코너, 전원 구조)
3. 전원 구조 설명(링 폭, 스트라이프, 패드 위치) 
4. 전력 기준선과 정정(8 ns → 10 ns 오류를 직접 고쳤다는 점, 패드/코어 분해)
5. IR drop 기준선 방법과 합격 기준 정의(기준이 선택 값임을 명시)
6. IR drop 기준선 결과(맵)
7. DOE 설계(변수, OFAT, 같은 조건)
8. DOE 결과 그래프(간격 vs IR drop)
9. DOE 결과 표(IR drop, 트랙 사용, 타이밍 영향)
10. 전원 패드 수 스트레스(위반이 나오는 지점)
11. EM 결과 또는 미수행 사유
12. 타이밍 클로징 요약(PD 시나리오의 핵심 한 장)
13. 한계(IR 인지 타이밍 없음, 활동도 가정, GDS 서명 검증 없음)
14. 부록: flow 단계별 캡처

---

## 4. 두 시나리오 공통 설계 원칙

1. **의도 표기:** 인위적으로 만든 조건(hold 위반, 전원 패드 축소)은 처음부터 "의도적으로 만들었다"고 쓴다. 이미 한 결정(실제로 일어난 위반을 실험으로 포장하지 않기)과 같은 규칙이다.
2. **한 실행 = 한 manifest:** 본문 수치는 해당 실행의 `MANIFEST.md`에서만 옮긴다.
3. **본문 대 부록:** 단계별 캡처 나열(지금 23장의 대부분)은 부록으로 보낸다. 앞부분은 문제, 가설, 확인, 결과의 순서로 쓴다.
4. **역할 표:** "MCU RTL은 Claude의 도움을 받아 작성, 이후 flow는 직접 수행" 한두 줄로 줄인다. Conformal, Tempus를 직접 했는지는 사용자 확인 후에만 쓴다.
5. **미해결 항목은 줄인다:** 한계 목록에 "원인 미확인"이 많을수록 불리하다. 0-B, 0-C로 풀 수 있는 항목(Genus/Innovus 지연 차이, 5 ns 위반)은 풀고, 풀지 못한 것만 남긴다.

## 5. 두 시나리오를 둘 다 할지, 하나만 할지
- 합성 재수행, 0-A~0-D, PD-1은 두 시나리오가 공유한다. 이 부분은 항상 한다.
- 지원 직무가 하나로 정해졌다면 그쪽의 핵심 실험(PD-3 또는 PI-2)을 먼저 완성한다. 두 직무 모두 지원한다면 포트폴리오를 하나로 하되 "타이밍 클로징 편"과 "전원 무결성 편"을 같은 설계 위에 구분해 쓴다. 한 문서에 슬라이드를 섞어 넣지는 않는다.

## 6. 진행 순서와 중단 조건
1. 0-A(보존) → 0-B(로그 비교) → 0-D(SDC 고정). 여기까지는 새 툴 실행이 거의 없다.
2. 합성 재수행(`runs/` 별) → 0-C(상관) → PD-1(주기 스윕, 게이트).
3. 선택한 시나리오의 핵심 실험: PD-3(hold ECO) 또는 PI-0 → PI-1 → PI-2.
4. 중단 조건: Voltus가 안 되면 PI-1 이후 전부 보류하고 PD 시나리오로 간다. 5 ns가 게이트를 통과 못 하면 통과한 주기 중 최고를 기준으로 삼는다.

## 7. 사용자에게 필요한 확인 (진행 전)
1. 지원 직무: PD, PI, 둘 다.
2. 5 ns **첫 실행**(−6.213 ns) 때의 `mapped` SDC, MMMC, Genus/Innovus 로그가 PC에 남아 있는가.
3. Voltus를 쓸 수 있는가(라이선스, 설치).
4. Conformal, Tempus STA를 직접 수행했는가(역할 문구용).
5. `assets/*.jpg`와 완성본 HTML(repo에 없음)을 `portfolio/assets/`로 넣을 수 있는가.
6. ECO 후 P&R이 "증분 ECO 라우팅"(0.2의 6번 기준)이 맞는가.
