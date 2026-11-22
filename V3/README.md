# V3 작업 지침 (매 세션 시작 시 먼저 읽을 것)

## 범위
- **V3 = 계획서의 v2: 32비트 가산기 구조 교체.** 변경은 `1_RTL/sccpu.v`의 ALU add/sub 구현 한 가지뿐이다.
- 기준선은 V2(v1-core, 완료). V2와 같은 SDC, 같은 스크립트, 같은 클럭에서 비교한다.
- EDA 툴은 사용자가 실행한다. Claude는 RTL, 스크립트, 검증, 해석, 문서화를 돕는다.

## 가설과 근거
- 가설: 가산기 구간이 줄어 더 빠른 클럭까지 timing이 닫히고, 면적은 늘어난다. 최악 경로가 다른 구간으로 옮겨갈 수 있다.
- 근거 (V2, post-route Tempus): 최악 setup 경로 `r_pc_reg_7 -> 명령어 ROM -> CPU(가산기) -> 주소 디코드 -> UART -> tx_fifo r_count_reg_4`, 데이터 경로 약 9.43 ns 중 가산기 구간 약 3.2 ns(34%). 합성 넷리스트의 가산기는 ADDFX1 체인이 아니라 AOI2BB1 게이트열(ADDFX1 6개뿐).
- 주의: 10 ns에서는 툴이 slack을 0까지 채워 면적을 줄이므로, 차이는 면적과 더 빠른 클럭에서 드러난다. V1 PPT상 합성은 4 ns, 2.5 ns까지 닫혔으므로(로그 대조 전 수치) 계획서의 10 -> 8 -> 7 ns sweep은 재검토 대상이다.

## 결정 상태 (미확정, 사용자 확인 필요)
| 항목 | 기본값(제안) | 상태 |
|---|---|---|
| 가산기 구조 | Kogge-Stone (대안: CLA) | 미확정 |
| 합성 sweep 주기 | 10, 6, 5, 4, 3.5, 3 ns, v1-core와 V3 둘 다 (계획서 원안: 10, 8, 7) | 미확정 |
| 플로우 깊이 | 합성과 EC 전부, PnR/Tempus는 10 ns와 선택 주기 하나, 시뮬은 pre-layout 한 번 | 미확정 |
| 도구 사용 종료일 | 사용자에게 확인 필요 (계획서: 폴리텍 11월 종료) | 미확인 |

## 폴더 세팅 (V2에서 복사)
| 파일 | V3에서 |
|---|---|
| `1_RTL/*.v` | 복사. `sccpu.v`만 수정, `add32_ks.v`(또는 선택한 구조) 추가 |
| `3_SYN/script/syn_mcu_core_top.tcl` | `RTL_SOURCES`에 새 파일 한 줄 추가 |
| `4_EC/script/script.tcl`, `POST/script/script.tcl` | Golden RTL 목록에 새 파일 추가 |
| 그 외 (SDC, PnR, 시뮬, mmmc) | 복사만, 수정 없음 |
| 최상위 이름 | `mcu_core_top` 그대로 (파일 이름 변경 불필요) |

## RTL 변경 지침
- 현재: `sccpu.v` 158번 줄 `w_a - w_b`, 166번 줄 `w_a + w_b`. Genus가 둘을 합쳐 `sub_158_49_Y_add_166_49` 하나의 가산기로 만든다.
- 변경: `w_bx = w_sub ? ~w_b : w_b`, `cin = w_sub`로 가산기 하나를 쓰고 두 줄 모두 그 결과를 사용한다.
- 건드리지 않는 것: `w_p4 = r_pc + 4`, `w_br_target`, 비교기.
- 검증: 가산기 단독 랜덤 테스트(add, sub, 수만 건) + RTL 회귀 `PASS tb_mcu_top` 8645 ns 종료. 명령은 V2/README.md 참고.

## 진행 체크리스트
- [ ] 결정 확정 (위 표)
- [ ] V3 폴더 세팅, 가산기 RTL, iverilog 검증
- [ ] v1-core 합성 sweep (V2 폴더 SDC에서 주기만 변경)
- [ ] V3 합성 sweep, 비교표 (slack, 면적, 최악 경로, 가산기 구간 지연, 가산기 셀 구성)
- [ ] EC (RTL <-> 합성)
- [ ] PnR + Tempus (선택 주기)
- [ ] pre-layout 시뮬 (필요 시 post-layout)
- [ ] 문서화 (버전 페이지 5칸, 비교표), 태그 `v3`

## 비교표 (계획서 6장, V2 열은 V2/README.md 값)
| 지표 | V2 | V3 |
|---|---|---|
| setup WNS / TNS | +0.348 ns / 0 (postRoute) | |
| hold WNS / TNS | +0.011 ns / 0 | |
| 합성 면적 | 21,819 um2 | |
| PnR 면적 / utilization | 코어 36,368 um2 / 61.839% | |
| 전력 | 0.765 mW (8 ns 기준) | |
| 클럭 트리 sink / skew / latency | 1,816 / 0.097, 0.039 ns / 0.477 ns | |
| DRC | 0 | |
| EC | PASS | |
| RTL / 게이트 시뮬 | PASS | |
| 총 실행 클럭 | 843 | |
| 도달한 최소 클럭 주기 | 미측정 | |
