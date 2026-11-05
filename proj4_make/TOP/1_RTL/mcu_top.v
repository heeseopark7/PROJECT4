//==============================================================================
// Module  : mcu_top
// Purpose : Top level of the MCU. Single-cycle MIPS CPU, instruction memory,
//           data RAM, address decoder and APB bridge.
//           The UART and SPI slots are present only as commented-out code:
//             UART : APB slot 0, 0x4000_0000 ~ 0x4000_0FFF
//             SPI  : APB slot 1, 0x4000_1000 ~ 0x4000_1FFF (spi_apb_top, master)
//             SLV  : APB slot 2, 0x4000_2000 ~ 0x4000_2FFF (spi_slave_apb_top, slave)
//           To connect a peripheral, remove the "//" marks on the lines marked
//           [UART] / [SPI] / [SLV] (ports, wires, psel, instance) and use the matching
//           read mux line at the bottom instead of the active one.
//
// Memory map:
//   0x0000_0000 ~ 0x0000_007F : data RAM (any address outside the APB region)
//   0x4000_xxxx               : APB region, slot = address[15:12] (0 = UART, 1 = SPI master, 2 = SPI slave)
//   An APB address with no connected slave reads 0 and ignores writes.
//
// Data paths:
//   (1) fetch  : pc -> scinstmem -> inst -> sccpu
//   (2) RAM    : sccpu -> aluout/data/wmem -> scdatamem -> ram_out -> memout
//   (3) APB    : sccpu -> decoder (req) -> apb_bridge -> stall / penable
//   (4) read   : RAM data or APB read data -> memout -> sccpu
//==============================================================================

`timescale 1ns / 1ps

module mcu_top (
                    clk                                 ,
                    clrn                                ,
//                  UARTRXD                             ,   // [UART]
//                  UARTTXD                             ,   // [UART]
//                  UARTINTR                            ,   // [UART]
//                  SPISCLK                             ,   // [SPI]
//                  SPIMOSI                             ,   // [SPI]
//                  SPIMISO                             ,   // [SPI]
//                  SPICSN                              ,   // [SPI]
//                  SPIINTR                             ,   // [SPI]
                    SLVSCLK                             ,   // [SLV]
                    SLVMOSI                             ,   // [SLV]
                    SLVMISO                             ,   // [SLV]
                    SLVCSN                              ,   // [SLV]
                    SLVINTR                             ,   // [SLV]
                    pc                                  ,
                    inst                                ,
                    aluout                              ,
                    memout
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input               clk                                 ;   // single clock (UART: PCLK)
input               clrn                                ;   // reset, active-LOW, async assert (UART: PRESETn)
// input            UARTRXD                             ;   // [UART] serial receive input
// output           UARTTXD                             ;   // [UART] serial transmit output
// output           UARTINTR                            ;   // [UART] combined interrupt (observe only)
// output           SPISCLK                             ;   // [SPI] serial clock
// output           SPIMOSI                             ;   // [SPI] master out, slave in
// input            SPIMISO                             ;   // [SPI] master in, slave out
// output           SPICSN                              ;   // [SPI] chip select, active-LOW
// output           SPIINTR                             ;   // [SPI] interrupt (observe only)
input               SLVSCLK                             ;   // [SLV] serial clock from the master
input               SLVMOSI                             ;   // [SLV] master out, slave in
output              SLVMISO                             ;   // [SLV] master in, slave out
input               SLVCSN                              ;   // [SLV] chip select, active-LOW
output              SLVINTR                             ;   // [SLV] interrupt (observe only)
output  [31:0]      pc                                  ;   // debug: program counter
output  [31:0]      inst                                ;   // debug: current instruction
output  [31:0]      aluout                              ;   // debug: data address / ALU result
output  [31:0]      memout                              ;   // debug: load data returned to the CPU

//------------------------------------------------------------------------------
// Internal wires
//------------------------------------------------------------------------------
wire    [31:0]      w_data                              ;   // sccpu -> RAM / APB, store data
wire    [31:0]      w_ram_out                           ;   // scdatamem -> read mux, RAM read data
// wire [31:0]      w_prdata                            ;   // [UART] UART -> read mux, APB read data
// wire [31:0]      w_prdata_spi                        ;   // [SPI]  SPI master -> read mux, APB read data
wire    [31:0]      w_prdata_slv                        ;   // [SLV]  SPI slave -> read mux, APB read data
wire                w_wmem                              ;   // sccpu -> RAM / APB, store strobe
wire                w_stall                             ;   // apb_bridge -> sccpu, hold the CPU
wire                w_penable                           ;   // apb_bridge -> slaves, ACCESS phase
wire                w_is_lw                             ;   // current instruction is lw (opcode 0x23)
wire                w_in_apb                            ;   // data address upper 16 bits == 0x4000
wire                w_req                               ;   // lw/sw to the APB region in progress
// wire             w_psel_uart                         ;   // [UART] slot 0 select
// wire             w_psel_spi                          ;   // [SPI]  slot 1 select
wire                w_psel_slv                          ;   // [SLV]  slot 2 select

//------------------------------------------------------------------------------
// Address decoder
//   The CPU has no read enable, so a read is recognized by the opcode.
//------------------------------------------------------------------------------
assign  w_is_lw      = (inst[31:26] == 6'h23)               ;
assign  w_in_apb     = (aluout[31:16] == 16'h4000)          ;
assign  w_req        = w_in_apb & (w_is_lw | w_wmem)        ;
// assign  w_psel_uart  = w_req & (aluout[15:12] == 4'h0)   ;   // [UART]
// assign  w_psel_spi   = w_req & (aluout[15:12] == 4'h1)   ;   // [SPI]
assign  w_psel_slv   = w_req & (aluout[15:12] == 4'h2)   ;   // [SLV]

//------------------------------------------------------------------------------
// sccpu : single-cycle MIPS CPU
//------------------------------------------------------------------------------
sccpu       uut1    (
                .clk            (clk         )   ,
                .nRst           (clrn        )   ,
                .i_inst         (inst        )   ,
                .i_memout       (memout      )   ,
                .i_stall        (w_stall     )   ,
                .o_pc           (pc          )   ,
                .o_wmem         (w_wmem      )   ,
                .o_aluout       (aluout      )   ,
                .o_data         (w_data      )
);

//------------------------------------------------------------------------------
// scinstmem : instruction memory (read by pc only)
//------------------------------------------------------------------------------
scinstmem   uut2    (
                .i_addr         (pc          )   ,
                .o_inst         (inst        )
);

//------------------------------------------------------------------------------
// scdatamem : data RAM. Stores to the APB region are blocked (w_in_apb),
//   otherwise address bits [6:2] would overwrite RAM word 0.
//------------------------------------------------------------------------------
scdatamem   uut3    (
                .clk            (clk                )   ,
                .i_we           (w_wmem & ~w_in_apb )   ,
                .i_addr         (aluout             )   ,
                .i_wdata        (w_data             )   ,
                .o_rdata        (w_ram_out          )
);

//------------------------------------------------------------------------------
// apb_bridge : makes the SETUP / ACCESS timing and stalls the CPU
//------------------------------------------------------------------------------
apb_bridge  uut4    (
                .clk            (clk         )   ,
                .nRst           (clrn        )   ,
                .i_req          (w_req       )   ,
                .o_psel         (            )   ,
                .o_penable      (w_penable   )   ,
                .o_stall        (w_stall     )
);

//------------------------------------------------------------------------------
// uart_ex_top : [UART] APB slave, slot 0 (PADDR is the word address [11:2])
//------------------------------------------------------------------------------
// uart_ex_top uut5    (
//                 .PCLK           (clk            )   ,
//                 .PRESETn        (clrn           )   ,
//                 .PSEL           (w_psel_uart    )   ,
//                 .PENABLE        (w_penable      )   ,
//                 .PWRITE         (w_wmem         )   ,
//                 .PADDR          (aluout[11:2]   )   ,
//                 .PWDATA         (w_data         )   ,
//                 .PRDATA         (w_prdata       )   ,
//                 .PREADY         (               )   ,
//                 .PSLVERR        (               )   ,
//                 .UARTRXD        (UARTRXD        )   ,
//                 .UARTTXD        (UARTTXD        )   ,
//                 .UARTRXINTR     (               )   ,
//                 .UARTTXINTR     (               )   ,
//                 .UARTRTINTR     (               )   ,
//                 .UARTEINTR      (               )   ,
//                 .UARTINTR       (UARTINTR       )
// );

//------------------------------------------------------------------------------
// spi_apb_top : [SPI] APB slave, slot 1 (PADDR is the word address [11:2])
//------------------------------------------------------------------------------
// spi_apb_top uut6    (
//                 .PCLK           (clk            )   ,
//                 .PRESETn        (clrn           )   ,
//                 .PSEL           (w_psel_spi     )   ,
//                 .PENABLE        (w_penable      )   ,
//                 .PWRITE         (w_wmem         )   ,
//                 .PADDR          (aluout[11:2]   )   ,
//                 .PWDATA         (w_data         )   ,
//                 .PRDATA         (w_prdata_spi   )   ,
//                 .SPISCLK        (SPISCLK        )   ,
//                 .SPIMOSI        (SPIMOSI        )   ,
//                 .SPIMISO        (SPIMISO        )   ,
//                 .SPICSN         (SPICSN         )   ,
//                 .SPIINTR        (SPIINTR        )
// );

//------------------------------------------------------------------------------
// spi_slave_apb_top : [SLV] APB slave, slot 2 (PADDR is the word address [11:2])
//   Needs its own pins: connect SLVSCLK / SLVMOSI / SLVCSN to a master and
//   SLVMISO back to it (outside this chip, or to the master pins on the board).
//------------------------------------------------------------------------------
spi_slave_apb_top uut7 (
                .PCLK           (clk            )   ,
                .PRESETn        (clrn           )   ,
                .PSEL           (w_psel_slv     )   ,
                .PENABLE        (w_penable      )   ,
                .PWRITE         (w_wmem         )   ,
                .PADDR          (aluout[11:2]   )   ,
                .PWDATA         (w_data         )   ,
                .PRDATA         (w_prdata_slv   )   ,
                .SLVSCLK        (SLVSCLK        )   ,
                .SLVMOSI        (SLVMOSI        )   ,
                .SLVMISO        (SLVMISO        )   ,
                .SLVCSN         (SLVCSN         )   ,
                .SLVINTR        (SLVINTR        )
);

//------------------------------------------------------------------------------
// Read data mux
//   RAM address     : scdatamem output
//   APB, no slave   : 0
//------------------------------------------------------------------------------
// assign  memout = w_in_apb ? 32'd0 : w_ram_out ;   // no peripheral connected
assign  memout = w_in_apb ? (w_psel_slv ? w_prdata_slv : 32'd0) : w_ram_out ;   // [SLV] only
// assign  memout = w_in_apb ? (w_psel_uart ? w_prdata : w_psel_spi ? w_prdata_spi : w_psel_slv ? w_prdata_slv : 32'd0) : w_ram_out ;   // [UART]+[SPI]+[SLV]: use this line instead

endmodule
