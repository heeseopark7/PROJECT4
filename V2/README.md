# V2: core-only track (no pads)

기준선(v1-core)과 v2(가산기 교체)를 같은 SDC, 같은 스크립트로 비교한다.

## 구성
- `TOP/1_RTL`        : V1 RTL + `mcu_core_top.v` (패드 없는 래퍼, 버전 간 변경 금지)
- `TOP/2_SIM`        : 기존 `tb_mcu_top` (RTL 회귀용, 843클럭 / 8645 ns 종료 기준)
- `TOP/3_SYN/cons`   : `mcu_core_top.sdc` (동결. 변경 가능한 건 `CLK_PERIOD`뿐)
- `TOP/3_SYN/script` : `syn_mcu_core_top.tcl`

## SDC 결정값 (변경하면 모든 버전 재측정)
- 클럭 10 ns, 클럭 모델은 V1과 동일
- 입력 delay max 1.0 / min 0.1 ns, 출력 delay max 1.0 / min 0.0 ns
- 입력 transition 0.1 ns, 출력 load 20 fF

## 실행 순서
1. Step 1 (가산기 확인): v1-core 합성 후 Genus에서
   `report_timing -from u_mcu_top/uut1/r_pc_reg* -through [get_pins u_mcu_top/uut1/*] -nworst 1`
   `report_datapath`, 가산기 셀 수(ADDF/ADDH) 확인
2. `cd TOP/3_SYN && genus -f script/syn_mcu_core_top.tcl`
3. 등가성(EC) -> PnR(utilization 0.6~0.7) -> STA -> 리포트 저장 -> 태그 `v1-core`
4. `sccpu.v` 가산기만 교체 -> RTL 시뮬 -> 같은 플로우 -> 태그 `v2`

RTL 회귀:
```
iverilog -g2012 -o tb.vvp -s tb_mcu_top TOP/1_RTL/*.v TOP/2_SIM/TESTBENCH/tb_mcu_top.v && vvp tb.vvp
```
PASS tb_mcu_top 이 8645000 ps(8645 ns)에서 나와야 한다.
