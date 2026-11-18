# MCU 설계 문서

대상: `1_RTL/` 전체 (칩 top = `mcu_pad_top`, 코어 = `mcu_top`), 검증 환경 `2_SIM/`

## 1. 개요

| 항목 | 내용 |
|---|---|
| 구조 | 단일 사이클 MIPS CPU + APB 브리지 + 내장 메모리 + APB 슬레이브 3개 (UART, SPI master, SPI slave) |
| CPU | 32bit, 정수 명령어 20개, 분기/점프 지연 슬롯 없음 |
| 명령어 메모리 | 256 word, 프로그램이 RTL에 상수 표(`case`)로 들어 있는 ROM (`scinstmem`) |
| 데이터 메모리 | 32 word (128 B), 비동기 읽기 / 동기 쓰기 (`scdatamem`) |
| 주변장치 | UART (`uart_ex_top`), SPI master (`spi_apb_top`), SPI slave (`spi_slave_apb_top`) |
| 리셋 | 비동기 assert, active-low `clrn` |
| 클럭 | 단일 `clk` (CPU, APB, 모든 주변장치의 PCLK 공용) |
| 칩 top | `mcu_pad_top` = `mcu_top` + I/O 패드 (GPDK045 `PADDI`/`PADDO`) |

## 2. 블록 다이어그램

```
mcu_pad_top = mcu_top + PADDI/PADDO pads
(pads: clk, clrn, UART, SPI master, SPI slave; 48-pad ring, 15 signal pads)

+------------------------------- mcu_top --------------------------------+
|                                                                        |
|  +-------+  pc    +-----------+                                        |
|  | sccpu |------->| scinstmem |   inst goes back to sccpu              |
|  +---+---+        +-----------+                                        |
|      | aluout, wdata, wmem                                             |
|      v                                                                 |
|  address decoder ----+--> scdatamem (RAM)                              |
|      |               +--> uart_ex_top        slot 0   UART pins        |
|  +---+--------+      +--> spi_apb_top        slot 1   SPI master pins  |
|  | apb_bridge |      +--> spi_slave_apb_top  slot 2   SPI slave pins   |
|  +---+--------+                                                        |
|      | stall -> sccpu,  PENABLE -> slaves                              |
|                                                                        |
|  read mux (RAM / UART / SPI master / SPI slave / 0) -> memout          |
|                                                                        |
+------------------------------------------------------------------------+
```

## 3. 파일 구성

| 파일 | 모듈 | 역할 |
|---|---|---|
| `mcu_pad_top.v` | `mcu_pad_top` | 칩 top, 패드 연결 (`add_pad` 포함) |
| `add_pad` | - | 전원/접지 패드 (PnR 단계에서 주석 해제) |
| `mcu_top.v` | `mcu_top` | 코어 top, 디코더, read mux |
| `sccpu.v` | `sccpu` | 단일 사이클 MIPS CPU |
| `scinstmem.v` | `scinstmem` | 명령어 ROM (프로그램 내장) |
| `scdatamem.v` | `scdatamem` | 데이터 RAM |
| `apb_bridge.v` | `apb_bridge` | APB SETUP/ACCESS 생성, CPU stall |
| `uart_ex_top.v` | `uart_ex_top` | UART top (2-FF 동기화, 루프백 선택) |
| `baud_gen.v`, `tx_fifo.v`, `rx_fifo.v`, `tx_logic.v`, `rx_logic.v`, `reg_block.v`, `interrupt_logic.v` | UART 하위 | 보레이트, FIFO, 송수신, 레지스터, 인터럽트 |
| `spi_apb_top.v` | `spi_apb_top` | SPI master top |
| `spi_regs.v`, `sclk_gen.v`, `spi_master.v` | SPI master 하위 | 레지스터, SCLK 분주, 송수신 엔진 |
| `spi_slave_apb_top.v` | `spi_slave_apb_top` | SPI slave top |
| `spis_regs.v`, `spi_slave.v` | SPI slave 하위 | 레지스터, 수신/응답 엔진 |

계층:

```
mcu_pad_top
 └ mcu_top
    ├ uut1 sccpu
    ├ uut2 scinstmem
    ├ uut3 scdatamem
    ├ uut4 apb_bridge
    ├ uut5 uart_ex_top        (baud_gen, tx_fifo, rx_fifo, tx_logic, rx_logic, reg_block, interrupt_logic)
    ├ uut6 spi_apb_top        (spi_regs, sclk_gen, spi_master)
    └ uut7 spi_slave_apb_top  (spis_regs, spi_slave)
```

## 4. 포트

### 4.1 mcu_top

| 포트 | 방향 | 폭 | 설명 |
|---|---|---|---|
| `clk` | in | 1 | 시스템 클럭 |
| `clrn` | in | 1 | 비동기 리셋 (active-low) |
| `UARTRXD` / `UARTTXD` | in / out | 1 | UART 수신 / 송신 |
| `UARTINTR` | out | 1 | UART 통합 인터럽트 (관찰용, CPU에 연결 안 됨) |
| `SPISCLK`, `SPIMOSI`, `SPICSN` | out | 1 | SPI master 클럭, 데이터 출력, 칩 셀렉트(active-low) |
| `SPIMISO` | in | 1 | SPI master 데이터 입력 |
| `SPIINTR` | out | 1 | SPI master 인터럽트 (관찰용) |
| `SLVSCLK`, `SLVMOSI`, `SLVCSN` | in | 1 | SPI slave 클럭, 데이터 입력, 칩 셀렉트 (master가 구동) |
| `SLVMISO` | out | 1 | SPI slave 응답 출력 |
| `SLVINTR` | out | 1 | SPI slave 인터럽트 (관찰용) |
| `pc`, `inst`, `aluout`, `memout` | out | 32 | 디버그 관찰용 (패드에는 연결하지 않음) |

### 4.2 mcu_pad_top (칩 핀 15개)

패드는 48개 링(변마다 12개)이고 신호 슬롯 32개 중 15개를 사용한다. 번호는 왼쪽 변에서 반시계 방향이다.

| 변 | 패드 | 신호 |
|---|---|---|
| 왼쪽 | pad2, pad3, pad4, pad7 | clk, clrn, UARTRXD, UARTTXD |
| 아래 | pad14, pad15, pad16, pad19 | SPISCLK, SPIMOSI, SPIMISO, SPICSN |
| 오른쪽 | pad26, pad27, pad28, pad31 | SLVSCLK, SLVMOSI, SLVMISO, SLVCSN |
| 위 | pad38, pad39, pad40 | UARTINTR, SPIINTR, SLVINTR |

- 변마다 위치 1~12는 `VSSIOR | 신호 3 | VDD | VSS | 신호 5 | VDDIOR` 순서이고 전원 패드 16개는 `add_pad`에 있다 (PnR 단계에서 주석 해제).
- 나머지 17개 신호 슬롯은 예약이다.
- UART의 RX/TX/RT/에러 인터럽트 4개는 코어 안에서 열어두고 통합 `UARTINTR`만 패드로 나간다.
- 코너/필러 셀은 PnR 단계에서 추가한다.

## 5. 메모리 맵

| 주소 범위 | 대상 | 비고 |
|---|---|---|
| `0x0000_0000 ~ 0x0000_007F` | 데이터 RAM (32 word) | `addr[6:2]`로 인덱싱, 범위를 넘으면 alias |
| `0x4000_0000 ~ 0x4000_0FFF` | UART (slot 0) | `aluout[15:12] == 0` |
| `0x4000_1000 ~ 0x4000_1FFF` | SPI master (slot 1) | `aluout[15:12] == 1` |
| `0x4000_2000 ~ 0x4000_2FFF` | SPI slave (slot 2) | `aluout[15:12] == 2` |
| 그 외 `0x4000_xxxx` | 미사용 APB | 읽기 0, 쓰기 무시 |
| 그 외 | RAM으로 alias | 에러 처리 없음 |

- 명령어 메모리는 PC 전용이다 (하버드 구조).
- 디코더: `in_apb = aluout[31:16] == 16'h4000`, `req = in_apb & (is_lw | wmem)`, `psel_x = req & (aluout[15:12] == 슬롯 번호)`
- RAM 쓰기 enable: `wmem & ~in_apb`
- 읽기 mux: `in_apb ? (슬롯별 PRDATA, 선택 없으면 0) : ram_out`
- 슬레이브에는 `PADDR = aluout[11:2]` (워드 주소)가 간다. CPU에 read enable이 없어서 `lw` opcode(0x23)로 읽기를 판별한다.

## 6. CPU (`sccpu`)

| 형식 | 명령어 |
|---|---|
| R-type 산술/논리 | `add`, `sub`, `and`, `or`, `xor` |
| R-type 시프트 | `sll`, `srl`, `sra` |
| R-type 점프 | `jr` |
| I-type | `addi`, `andi`, `ori`, `xori`, `lui` |
| 메모리 | `lw`, `sw` |
| 분기 | `beq`, `bne` |
| J-type | `j`, `jal` |

- 즉시값: `andi/ori/xori`는 zero-extend, 그 외는 sign-extend
- 분기 목표 = `PC+4 + (sign_ext(imm) << 2)`, 점프 목표 = `{PC+4[31:28], addr26, 2'b00}`, `jal`은 `$31 <= PC+4`
- 레지스터 파일 `$1 ~ $31` (`$0`은 상수 0)
- 한 사이클에 fetch, decode, execute, mem, writeback을 모두 수행한다. `stall=1`이면 PC와 레지스터 파일이 동결된다. 리셋 시 `pc=0`.
- 미지원: 곱셈/나눗셈, 바이트/하프워드 접근, `slt` 계열, 예외/인터럽트

## 7. APB 브리지 (`apb_bridge`)

APB 영역에 대한 `lw`/`sw`를 2클럭 트랜잭션으로 바꾸고 그동안 CPU를 멈춘다.

| 단계 | PSEL | PENABLE | stall |
|---|---|---|---|
| IDLE | 0 | 0 | 0 |
| SETUP (req 첫 사이클) | 1 | 0 | **1** |
| ACCESS | 1 | **1 (정확히 1클럭)** | 0 |

- ACCESS 끝 에지에서 PC가 진행한다. `lw`는 같은 사이클에 `memout`이 레지스터에 라이트백된다.
- PREADY는 항상 1로 가정한다 (wait state 없음). UART의 PREADY/PSLVERR 출력은 연결하지 않는다.
- APB 접근 1회 = 2클럭, RAM 접근 = 1클럭

## 8. 주변장치

세 슬레이브는 `PCLK=clk`, `PRESETn=clrn`, `PENABLE`, `PWRITE`, `PADDR=aluout[11:2]`, `PWDATA`를 공유하고 `PSEL`, `PRDATA`만 따로 쓴다.

### 8.1 UART (`uart_ex_top`, slot 0)

8N1 + 옵션 패리티, 송신/수신 FIFO 각 16 entry, 16x 오버샘플링, 루프백 지원.

| 오프셋 | 레지스터 | 설명 |
|---|---|---|
| 0x000 | UARTDR | 쓰기 = TX FIFO push, 읽기 = RX FIFO pop (`[10]` BE, `[9]` PE, `[8]` FE, `[7:0]` 데이터) |
| 0x018 | UARTFR | `[7]` TXFE `[6]` RXFF `[5]` TXFF `[4]` RXFE `[3]` BUSY |
| 0x024 | UARTIBRD | 정수 분주값 (리셋 0x00D9 = 217, 33.333MHz에서 9600bps) |
| 0x02C | UARTLCR_H | `[2]` EPS `[1]` PEN `[0]` BRK |
| 0x030 | UARTCR | `[9]` RXE `[8]` TXE `[7]` LBE(루프백) `[0]` UARTEN, 리셋 0x300 |
| 0x038 | UARTIMSC | 인터럽트 마스크 `[10:4]` |
| 0x03C / 0x040 | UARTRIS / UARTMIS | 원시 / 마스크된 인터럽트 상태 |
| 0x044 | UARTICR | 인터럽트 clear (1을 쓰면 해당 비트 clear) |

보레이트: 비트 시간 = 16 x IBRD 클럭. 인터럽트 5개 (RX, TX, 수신 타임아웃, 에러, 통합).

### 8.2 SPI master (`spi_apb_top`, slot 1)

8bit, MSB first, 모드 0~3, 전이중. 한 바이트는 SCLK 반주기 T_h의 18배 동안 BUSY.

| 오프셋 | 레지스터 | 설명 |
|---|---|---|
| 0x0 | SPCR | `[0]` SPE `[1]` CPOL `[2]` CPHA `[3]` CS `[4]` LOOP `[5]` SPIE |
| 0x4 | SPSR | `[0]` BUSY `[1]` DONE `[2]` WCOL (1을 써서 clear) |
| 0x8 | SPDR | 쓰기 = 전송 시작, 읽기 = 마지막 수신 바이트 |
| 0xC | SPDIV | 리셋 25, 실제 분주 = max(SPDIV, 8) |

### 8.3 SPI slave (`spi_slave_apb_top`, slot 2)

시스템 클럭으로 동작하며 SCLK, CS_N, MOSI는 2-FF 동기화한다. SCLK는 clk보다 8배 이상 느려야 한다.

| 오프셋 | 레지스터 | 설명 |
|---|---|---|
| 0x0 | SSCR | `[0]` SSE `[1]` CPOL `[2]` CPHA `[3]` SSIE |
| 0x4 | SSSR | `[0]` RXNE `[1]` OVR (1을 써서 clear) `[2]` BSY |
| 0x8 | SSDR | 쓰기 = 다음 전송의 응답 바이트, 읽기 = 수신 바이트 (RXNE clear) |

응답 바이트는 master가 CS_N을 내릴 때 읽히므로 SSDR을 먼저 써야 한다.

## 9. 메모리 모듈

### `scinstmem`
- 256 word, 비동기 읽기. 프로그램이 `case` 표로 들어 있어서 합성 시 일반 게이트로 만들어진다 (메모리 라이브러리 불필요).
- 프로그램 뒤의 word는 0x00000000 (nop).
- `$readmemh`/`initial` 방식을 쓰지 않으므로 합성, 게이트 시뮬, PnR 시뮬이 모두 같은 프로그램을 실행한다.

### `scdatamem`
- 32 word x 32bit, 비동기 읽기, 동기 쓰기. 초기값 0.
- 합성하면 플립플롭 약 1024개와 읽기 mux가 된다.

## 10. 내장 프로그램 (`scinstmem`)

| 구간 | 동작 | 결과 |
|---|---|---|
| 1 | 1~10 합계 루프 | `RAM[0] = 0x37` |
| 2 | UART 루프백, `'A'`(0x41) 송신 후 수신 | `RAM[1] = 0x41`, `UARTTXD`에 1프레임 |
| 3 | SPI master가 0xA5 송신, slave가 0x3C 응답 | `RAM[2] = 0x3C`, `RAM[3] = 0xA5` |
| 4 | `j 0xAC` 자기 자신으로 점프 | 종료 (`pc = 0xAC`) |

구간 2 설정: `UARTIBRD = 4`, `UARTCR = 0x381` (UARTEN, TXE, RXE, LBE). 송신 전에 UARTFR의 TXFF가 0이 될 때까지, 수신 전에 RXFE가 0이 될 때까지 폴링한다.

구간 3 설정: slave `SSCR = SSE`, slave `SSDR = 0x3C`, master `SPDIV = 8`, `SPCR = 9` (SPE, CS, 모드 0), `SPDR = 0xA5`. master의 DONE과 slave의 RXNE를 폴링한 뒤 두 쪽의 수신값을 읽는다.

명령어별 어셈블리와 hex는 `1_RTL/scinstmem.v`의 주석에 있다 (명령 44개).

## 11. 검증 (`2_SIM`)

### 구성
| 파일 | 설명 |
|---|---|
| `FUNCTION/run_function.tcl` | xrun으로 RTL 시뮬 (top = `tb_mcu_top`, 소스는 `1_RTL`의 `mcu_top`과 하위 전부) |
| `TESTBENCH/tb_mcu_top.v` | 자기검증 TB 하나로 RTL, 합성 후(pre-layout), PnR 후(post-layout) 시뮬을 모두 돌린다. 프로그램은 ROM에 들어 있어서 TB가 로드하지 않는다 |
| `TESTBENCH/tb_spi_master.v`, `tb_spi_slave.v` | SPI master/slave 단독 TB |

### tb_mcu_top 시뮬 종류 (컴파일 스위치)
| 스위치 | DUT | 시뮬 내용 |
|---|---|---|
| `+define+function_sim` | `mcu_top` | RTL (지연 없음) |
| `+define+sdf_gate` | `mcu_pad_top` | 합성 넷리스트 + SDF (pre-layout) |
| `+define+sdf_post_wst` | `mcu_pad_top` | PnR 넷리스트 + worst-case SDF (post-layout) |
| `+define+sdf_post_bst` | `mcu_pad_top` | PnR 넷리스트 + best-case SDF (post-layout) |

- 넷리스트 시뮬은 `-timescale 1ns/1ps`가 필요하다 (넷리스트에 `timescale`이 없다).
- SDF 경로는 시뮬을 실행하는 폴더 기준이고, post-layout SDF 이름은 5_PNR 결과에 맞춰야 한다.

### tb_mcu_top 검사 항목
SPI master 핀과 slave 핀은 TB에서 서로 연결한다.

| 구분 | 항목 | 기대값 |
|---|---|---|
| 칩 핀 (모든 시뮬) | `UARTTXD` 프레임 수, 데이터 | 1프레임, 0x41 |
| | SPI SCLK 상승 에지, MOSI 바이트, MISO 바이트 | 8회, 0xA5, 0x3C |
| 내부 (RTL 시뮬 `function_sim`) | `RAM[0..3]` | 0x37, 0x41, 0x3C, 0xA5 |
| | 종료 시 `pc` | 0xAC |
| | stall 횟수와 penable 횟수 | 같음 (접근 1회당 1쌍) |
| | penable 길이, stall과 동시 여부 | 1클럭, 겹치지 않음 |

종료 조건은 RTL 시뮬에서는 `pc==0xAC`, 넷리스트 시뮬에서는 8번째 SPI 클럭 에지(칩에 `pc` 핀이 없다)이고, 둘 다 20000클럭 타임아웃이 있다.

### 결과
- iverilog로 RTL 시뮬 결과 `PASS tb_mcu_top` (종료 약 8.6us, APB 접근 204회). `mcu_pad_top`은 컴파일 확인까지 했다.
- xrun으로 확인해야 한다 (`2_SIM/FUNCTION`에서 `run_function.tcl` 실행).
- 같은 TB를 네 가지 스위치로 모두 확인했다. 넷리스트 모드는 RTL의 `mcu_pad_top`과 패드 대용 모델로 TB 구조와 핀 검사가 PASS인 것까지 확인했고, 실제 SDF 적용(`$sdf_annotate`)은 xrun에서 확인해야 한다.

## 12. 구현 현황

| 디렉터리 | 상태 |
|---|---|
| `1_RTL` | 완료 (CPU, 메모리, APB 브리지, UART, SPI master, SPI slave, 패드 래퍼) |
| `2_SIM` | RTL 기능 시뮬 TB 완료 |
| `3_SYN` | 미진행 (top = `mcu_pad_top`) |
| `4_EC` | 미진행 |
| `5_PNR` | 미진행 (`add_pad`의 전원 패드 주석 해제 필요) |

## 13. 알려진 제약 / 미결 사항

1. **긴 조합 경로**: 비동기 읽기 메모리와 단일 사이클 구조라서 `pc → ROM → decode → ALU → RAM/APB mux → 레지스터` 가 한 사이클 critical path이다. 합성 후 주파수 상한을 확인해야 한다.
2. **인터럽트 미연결**: UART/SPI 인터럽트는 외부 핀으로만 나가고 CPU 인터럽트 경로는 없다.
3. **PREADY/PSLVERR 미사용**: 슬레이브 wait state와 에러 응답은 지원하지 않는다.
4. **주소 alias**: RAM 범위 밖이거나 APB가 아닌 주소는 에러 없이 RAM으로 wrap하고, 비정렬 접근도 `addr[1:0]`을 무시한다.
5. **디코더 중복**: `mcu_top`이 `inst[31:26]==0x23`으로 `is_lw`를 따로 디코딩한다 (`sccpu` 내부 `w_lw`와 중복).
6. **디버그 포트**: `pc`, `inst`, `aluout`, `memout`은 패드에 연결하지 않았다. 칩 레벨 시뮬에서는 관찰할 수 없다.
7. **SPI slave 제약**: SCLK는 clk보다 8배 이상 느려야 하고, master는 CS_N을 내리기 전에 CPOL을 정해야 한다.
8. **프로그램이 RTL에 고정**: 프로그램을 바꾸려면 `scinstmem.v`의 `case` 표를 수정해야 한다.
9. **데이터 RAM 면적**: 32 x 32bit 플립플롭 구조라서 UART FIFO(약 300 플립플롭)보다 면적이 크다.
