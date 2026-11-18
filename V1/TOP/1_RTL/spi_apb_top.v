//==============================================================================
// Module  : spi_apb_top
// Purpose : Top level of the SPI master, an APB slave (synthesis / PnR top).
//           MCU slot 0x4000_1000, PCLK = clk, PRESETn = clrn (async, active-LOW).
//           There is no PREADY / PSLVERR: the slave answers in the same cycle
//           (no wait state).
//
// Blocks:
//   spi_regs   : APB register file and transfer control
//   sclk_gen   : half-period tick generator
//   spi_master : shift engine and SCLK / MOSI / MISO
//==============================================================================

`timescale 1ns / 1ps

module spi_apb_top (
                    PCLK                                ,
                    PRESETn                             ,
                    PSEL                                ,
                    PENABLE                             ,
                    PWRITE                              ,
                    PADDR                               ,
                    PWDATA                              ,
                    PRDATA                              ,
                    SPISCLK                             ,
                    SPIMOSI                             ,
                    SPIMISO                             ,
                    SPICSN                              ,
                    SPIINTR
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input               PCLK                                ;   // clock (inside: clk)
input               PRESETn                             ;   // reset, active-LOW, async assert (inside: nRst)
input               PSEL                                ;   // APB select
input               PENABLE                             ;   // APB enable (2nd phase of a transfer)
input               PWRITE                              ;   // APB direction, 1 = write
input   [9:0]       PADDR                               ;   // APB word address (aluout[11:2]); only [1:0] is used
input   [31:0]      PWDATA                              ;   // APB write data
output  [31:0]      PRDATA                              ;   // APB read data
output              SPISCLK                             ;   // SPI serial clock
output              SPIMOSI                             ;   // SPI master out, slave in
input               SPIMISO                             ;   // SPI master in, slave out
output              SPICSN                              ;   // SPI chip select, active-LOW
output              SPIINTR                             ;   // SPI interrupt

//------------------------------------------------------------------------------
// Internal wires (name = what it carries, source block -> destination block)
//------------------------------------------------------------------------------
wire                w_start                             ;   // spi_regs -> spi_master, start a transfer
wire                w_busy                              ;   // spi_master -> spi_regs, sclk_gen
wire                w_done                              ;   // spi_master -> spi_regs, transfer finished
wire                w_tick                              ;   // sclk_gen -> spi_master, half-period tick
wire    [7:0]       w_tx_data                           ;   // spi_regs -> spi_master, byte to send
wire    [7:0]       w_rx_data                           ;   // spi_master -> spi_regs, received byte
wire    [7:0]       w_div                               ;   // spi_regs -> sclk_gen, effective divisor
wire                w_cpol                              ;   // spi_regs -> spi_master, clock polarity
wire                w_cpha                              ;   // spi_regs -> spi_master, clock phase
wire                w_loop                              ;   // spi_regs -> spi_master, internal loopback

//------------------------------------------------------------------------------
// spi_regs : APB slave and register file
//------------------------------------------------------------------------------
spi_regs    uut1    (
                .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_psel         (PSEL        )   ,
                .i_penable      (PENABLE     )   ,
                .i_pwrite       (PWRITE      )   ,
                .i_paddr        (PADDR       )   ,
                .i_pwdata       (PWDATA      )   ,
                .o_prdata       (PRDATA      )   ,
                .o_start        (w_start     )   ,
                .o_tx_data      (w_tx_data   )   ,
                .o_cpol         (w_cpol      )   ,
                .o_cpha         (w_cpha      )   ,
                .o_loop         (w_loop      )   ,
                .o_div          (w_div       )   ,
                .i_busy         (w_busy      )   ,
                .i_done         (w_done      )   ,
                .i_rx_data      (w_rx_data   )   ,
                .o_cs_n         (SPICSN      )   ,
                .o_intr         (SPIINTR     )
);

//------------------------------------------------------------------------------
// sclk_gen : half-period tick while a transfer is running
//------------------------------------------------------------------------------
sclk_gen    uut2    (
                .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_en           (w_busy      )   ,
                .i_div          (w_div       )   ,
                .o_tick         (w_tick      )
);

//------------------------------------------------------------------------------
// spi_master : shift engine
//------------------------------------------------------------------------------
spi_master  uut3    (
                .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_tick         (w_tick      )   ,
                .i_start        (w_start     )   ,
                .i_tx_data      (w_tx_data   )   ,
                .i_cpol         (w_cpol      )   ,
                .i_cpha         (w_cpha      )   ,
                .i_loop         (w_loop      )   ,
                .o_busy         (w_busy      )   ,
                .o_done         (w_done      )   ,
                .o_rx_data      (w_rx_data   )   ,
                .o_sclk         (SPISCLK     )   ,
                .o_mosi         (SPIMOSI     )   ,
                .i_miso         (SPIMISO     )
);

endmodule
