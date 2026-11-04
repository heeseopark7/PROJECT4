# MCU 설계 문서

대상 RTL: `1_RTL/` (mcu_top, sccpu, apb_bridge, scinstmem, scdatamem, prog.hex)

## 1. 개요

| 항목 | 내용 |
|---|---|
| 구조 | 단일 사이클(single-cycle) MIPS CPU + APB 마스터 브릿지 + 내장 메모리 + Extended UART |
| CPU | 32bit, 정수 명령어 20개 (Yamin Li ch.5 스타일), 분기/점프 지연 슬롯 없음 |
| 명령어 메모리 | 256 word (1 KB), `prog.hex` 로 초기화, 비동기 읽기 |
| 데이터 메모리 | 32 word (128 B), 비동기 읽기 / 동기 쓰기 |
| 주변장치 | UART (`uart_ex_top`, APB 슬레이브) — **RTL이 이 레포에 없음(외부 IP)** |
| 예약 | SPI 슬롯 `0x4000_1000` (현재 미구현, `psel_spi` 주석 처리) |
| 리셋 | 비동기 active-low `clrn` |
| 클럭 | 단일 `clk` (CPU/APB/UART의 PCLK 공용) |

## 2. 블록 다이어그램

```
          +------------------- mcu_top --------------------+
          |                                                 |
 clk,clrn |   +-------+  pc   +---------+  inst             |
 ---------+-->| sccpu |------>| scinstmem|-----+            |
          |   |       |<------+---------+     |            |
          |   |       | aluout,data,wmem      |            |
          |   |       |---+-------------------+            |
          |   +---^---+   |                                 |
          |  stall|memout |   address decoder               |
          |       |   ^   |   (in_apb / psel_uart)          |
          |   +---+---+   +--> scdatamem (RAM, ~in_apb)     |
          |   |apb_    |   +--> uart_ex_top (psel_uart)  --> UARTTXD / <-- UARTRXD
          |   |bridge  |        PENABLE <- bridge           --> UARTINTR
          |   +--------+   read mux: RAM / UART / 0         |
          +-------------------------------------------------+
```

## 3. 포트 (mcu_top)

| 포트 | 방향 | 폭 | 설명 |
|---|---|---|---|
| `clk` | in | 1 | 시스템 클럭 |
| `clrn` | in | 1 | 비동기 리셋 (active-low) |
| `UARTRXD` | in | 1 | UART 수신 |
| `UARTTXD` | out | 1 | UART 송신 |
| `UARTINTR` | out | 1 | UART 통합 인터럽트 (CPU에는 연결되지 않음, 외부 출력만) |
| `pc` | out | 32 | 프로그램 카운터 (디버그/관찰용) |
| `inst` | out | 32 | 현재 명령어 (디버그) |
| `aluout` | out | 32 | ALU 결과 = 데이터 주소 (디버그) |
| `memout` | out | 32 | 로드 데이터 (RAM 또는 UART PRDATA) |

## 4. 메모리 맵

| 주소 범위 | 대상 | 비고 |
|---|---|---|
| `0x0000_0000 ~ 0x0000_007F` | 데이터 RAM (32 word) | `addr[6:2]` 로 인덱싱, 그 이상 주소는 alias (wrap) |
| `0x4000_0000 ~ 0x4000_0FFF` | UART (APB) | `aluout[31:16]==0x4000` 이고 `aluout[15:12]==0` |
| `0x4000_1000 ~ 0x4000_1FFF` | SPI (예약) | 미구현. 접근 시 읽기 0, 쓰기 무시 |
| 그 외 `0x4000_xxxx` | 미사용 APB | 읽기 0 반환 |
| 그 외 (APB 아님) | RAM으로 alias | 별도 에러 처리 없음 |

- 명령어 메모리는 PC 전용(하버드 구조). 데이터 버스로 접근 불가.
- 주소 디코더(`mcu_top`):
  - `in_apb = aluout[31:16] == 16'h4000`
  - `req = in_apb & (is_lw | wmem)` — APB 영역에 대한 lw/sw 일 때만 트랜잭션 발생
  - `psel_uart = req & (aluout[15:12] == 0)`
- RAM 쓰기 enable: `wmem & ~in_apb`
- 읽기 mux: `in_apb ? (psel_uart ? prdata : 0) : ram_out`
- UART 레지스터 주소: `PADDR = aluout[11:2]` (워드 주소, 10bit)

## 5. CPU (`sccpu`)

### 5.1 지원 명령어 (20개)

| 형식 | 명령어 |
|---|---|
| R-type 산술/논리 | `add`, `sub`, `and`, `or`, `xor` |
| R-type 시프트 | `sll`, `srl`, `sra` (shamt 사용) |
| R-type 점프 | `jr` |
| I-type 산술/논리 | `addi`, `andi`, `ori`, `xori`, `lui` |
| 메모리 | `lw`, `sw` |
| 분기 | `beq`, `bne` |
| J-type | `j`, `jal` |

- 즉시값 확장: `andi/ori/xori` = zero-extend, 그 외 = sign-extend
- 분기 목표 = `PC+4 + (sign_ext(imm) << 2)`
- 점프 목표 = `{PC+4[31:28], addr26, 2'b00}`, `jal` 은 `$31 <= PC+4`
- 레지스터 파일: `$1~$31` (32bit × 31), `$0` 은 항상 0 (읽기 시 상수 0, 쓰기 무시)
- 미지원: 곱셈/나눗셈, 바이트/하프워드 접근(`lb/lh/sb/sh`), `slt` 계열, 예외/인터럽트, CP0

### 5.2 구조

- 한 사이클에 fetch → decode → execute → mem → writeback 모두 수행
- PC와 레지스터 파일은 `posedge clk`에서 갱신, **`stall=1` 이면 둘 다 동결**
- 리셋 시 `pc=0`, 모든 레지스터 0
- ALU: add/sub/and/or/xor/shift/lui. 주소 계산(lw/sw)에도 add 사용
- 라이트백 데이터: `jal→PC+4`, `lw→memout`, 그 외 `alu`
- 라이트백 대상: `jal→$31`, R-type 산술→`rd`, 그 외→`rt`

## 6. APB 브릿지 (`apb_bridge`)

CPU가 APB 영역에 lw/sw 를 실행하면 2 사이클 트랜잭션으로 변환하고 그동안 CPU를 stall 시킨다.

```
clk      : _/‾\_/‾\_/‾\_
req      : ____/‾‾‾‾‾‾\____   (명령이 APB 접근인 동안)
access   : ________/‾‾‾\___
PSEL     : ____/‾‾‾‾‾‾\____
PENABLE  : ________/‾‾‾\___   (ACCESS 단계, 정확히 1 clock)
stall    : ____/‾‾‾\_______   (SETUP 단계에서만 1)
            IDLE SETUP ACCESS
```

| 단계 | access | stall | PENABLE |
|---|---|---|---|
| IDLE | 0 | 0 | 0 |
| SETUP (req 첫 사이클) | 0 | **1** | 0 |
| ACCESS | 1 | 0 | **1** |

- ACCESS 사이클에 stall 이 풀려 PC가 진행하고, `lw` 의 경우 같은 사이클에 PRDATA(`memout`)가 레지스터에 라이트백된다.
- `PREADY` 는 항상 1 로 가정 (wait state 없음), `PSLVERR` 는 무시. 브릿지의 `psel` 출력은 top 에서 사용하지 않고(`mcu_top` 이 직접 `psel_uart` 생성), `PREADY/PSLVERR` 는 미연결.
- 따라서 APB 접근 1회 = 2 clock, RAM 접근 = 1 clock.

## 7. 메모리 모듈

### `scinstmem` (파라미터: `INIT_FILE="prog.hex"`, `AW=8`)
- 256 word, 비동기 읽기: `inst = rom[a[9:2]]`
- 초기화: 전체 0(nop = `sll $0,$0,0`) 후 `$readmemh(prog.hex)`
- 합성 시 ROM/LUT 로 매핑되므로 `prog.hex` 경로 관리 필요

### `scdatamem`
- 32 word, 비동기 읽기: `dataout = ram[addr[6:2]]`, 동기 쓰기 (`we`)
- 초기값 전부 0

## 8. 내장 테스트 프로그램 (`prog.hex`)

UART 를 루프백 모드로 설정해 문자 `'A'` 를 보내고 받아서 RAM[0] 에 저장한다.

| PC | HEX | 어셈블리 | 설명 |
|---|---|---|---|
| 00 | 3C084000 | `lui  $8, 0x4000` | UART 베이스 주소 |
| 04 | 20090004 | `addi $9, $0, 4` | |
| 08 | AD090024 | `sw   $9, 0x24($8)` | UARTIBRD = 4 |
| 0C | 20090381 | `addi $9, $0, 0x381` | UARTEN + LBE(루프백) + TXE + RXE |
| 10 | AD090030 | `sw   $9, 0x30($8)` | UARTCR |
| 14 | 8D0A0018 | `lw   $10, 0x18($8)` | UARTFR 읽기 |
| 18 | 314A0020 | `andi $10, $10, 0x20` | TXFF (송신 FIFO full) |
| 1C | 1540FFFD | `bne  $10, $0, -3` | full 이면 14로 반복 |
| 20 | 200B0041 | `addi $11, $0, 0x41` | `'A'` |
| 24 | AD0B0000 | `sw   $11, 0($8)` | UARTDR 송신 |
| 28 | 8D0A0018 | `lw   $10, 0x18($8)` | UARTFR 읽기 |
| 2C | 314A0010 | `andi $10, $10, 0x10` | RXFE (수신 FIFO empty) |
| 30 | 1540FFFD | `bne  $10, $0, -3` | 비었으면 28로 반복 |
| 34 | 8D0C0000 | `lw   $12, 0($8)` | UARTDR 수신 |
| 38 | AC0C0000 | `sw   $12, 0($0)` | RAM[0] ← 수신값 |
| 3C | 0800000F | `j    0x3C` | 무한 루프(종료) |

> 레지스터 오프셋(DR=0x00, FR=0x18, IBRD=0x24, CR=0x30)은 PL011 계열 UART 기준이며, 외부 `uart_ex_top` 의 실제 레지스터 정의와 일치하는지 확인이 필요하다.

기대 결과: 종료 시 `RAM[0] == 0x41`.

## 9. 검증/구현 현황

| 디렉터리 | 상태 |
|---|---|
| `1_RTL` | 완료 (위 6개 파일) |
| `2_SIM` | 비어있음 (`2.v` 0 byte) — 테스트벤치 미작성 |
| `3_SYN` | 비어있음 — 합성 스크립트/결과 없음 |
| `4_EC` | 비어있음 — equivalence check 없음 |
| `5_PNR` | 비어있음 — P&R 없음 |

## 10. 알려진 제약 / 미결 사항

1. **`uart_ex_top` RTL 부재**: 레포에 없어 시뮬/합성 시 별도 추가 필요.
2. **SPI 미구현**: `0x4000_1000` 슬롯만 예약 (OI-5). 현재 접근 시 읽기 0.
3. **PREADY/PSLVERR 미사용**: 슬레이브 wait state·에러 응답 지원 안 함 (OI-10).
4. **인터럽트 미연결**: `UARTINTR` 는 외부 핀으로만 나가고 CPU 인터럽트 경로 없음.
5. **주소 alias**: RAM 범위(0x80) 밖/비 APB 주소는 에러 없이 RAM 에 wrap. 비정렬 접근도 `addr[1:0]` 무시.
6. **combinational path**: 비동기 읽기 메모리 + 단일 사이클이므로 `pc → imem → decode → ALU → dmem/APB mux → regfile` 가 한 사이클 critical path. 합성 시 주파수 상한 확인 필요.
7. **디코더 중복**: `mcu_top` 이 `inst[31:26]==0x23` 으로 `is_lw` 를 별도 디코딩 (sccpu 의 `i_lw` 와 중복, 포트로 빼면 정리 가능).
8. 포트 `pc/inst/aluout/memout` 은 디버그용이라 실제 칩 핀으로는 제거 대상.
9. 이력상 UART/SPI 삭제·재추가가 있었음(`git log`) — 최종 구성은 UART 만 포함.
