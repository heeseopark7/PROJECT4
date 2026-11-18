//==============================================================================
// Module  : spi_slave_apb_top
// Purpose : Top level of the SPI slave, an APB slave (synthesis / PnR top).
//           MCU slot 0x4000_2000, PCLK = clk, PRESETn = clrn (async, active-LOW).
//           The CPU configures the slave and reads the received byte through
//           the registers in spis_regs. There is no PREADY / PSLVERR: the slave
//           answers in the same cycle (no wait state).
//           The slave stays deselected while SSCR.SSE = 0 (CS_N is forced high).
//
// Blocks:
//   spis_regs : APB register file
//   spi_slave : SPI slave shift engine (SLVSCLK must be >= 8x slower than PCLK)
//==============================================================================

`timescale 1ns / 1ps

module spi_slave_apb_top (
                    PCLK                                ,
                    PRESETn                             ,
                    PSEL                                ,
                    PENABLE                             ,
                    PWRITE                              ,
                    PADDR                               ,
                    PWDATA                              ,
                    PRDATA                              ,
                    SLVSCLK                             ,
                    SLVMOSI                             ,
                    SLVMISO                             ,
                    SLVCSN                              ,
                    SLVINTR
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
input               SLVSCLK                             ;   // SPI serial clock from the master
input               SLVMOSI                             ;   // SPI master out, slave in
output              SLVMISO                             ;   // SPI master in, slave out
input               SLVCSN                              ;   // SPI chip select, active-LOW
output              SLVINTR                             ;   // slave interrupt (byte received)

//------------------------------------------------------------------------------
// Internal wires (name = what it carries, source block -> destination block)
//------------------------------------------------------------------------------
wire                w_cpol                              ;   // spis_regs -> spi_slave, clock polarity
wire                w_cpha                              ;   // spis_regs -> spi_slave, clock phase
wire                w_sse                               ;   // spis_regs, slave enable
wire    [7:0]       w_tx_data                           ;   // spis_regs -> spi_slave, reply byte
wire    [7:0]       w_rx_data                           ;   // spi_slave -> spis_regs, received byte
wire                w_rx_valid                          ;   // spi_slave -> spis_regs, byte ready pulse
wire                w_cs_n                              ;   // chip select seen by spi_slave (forced high if disabled)

assign  w_cs_n  = SLVCSN | ~w_sse   ;

//------------------------------------------------------------------------------
// spis_regs : APB slave and register file
//------------------------------------------------------------------------------
spis_regs   uut1    (
                .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_psel         (PSEL        )   ,
                .i_penable      (PENABLE     )   ,
                .i_pwrite       (PWRITE      )   ,
                .i_paddr        (PADDR       )   ,
                .i_pwdata       (PWDATA      )   ,
                .o_prdata       (PRDATA      )   ,
                .o_cpol         (w_cpol      )   ,
                .o_cpha         (w_cpha      )   ,
                .o_sse          (w_sse       )   ,
                .o_tx_data      (w_tx_data   )   ,
                .i_rx_data      (w_rx_data   )   ,
                .i_rx_valid     (w_rx_valid  )   ,
                .i_cs_n         (SLVCSN      )   ,
                .o_intr         (SLVINTR     )
);

//------------------------------------------------------------------------------
// spi_slave : shift engine
//------------------------------------------------------------------------------
spi_slave   uut2    (
                .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_cpol         (w_cpol      )   ,
                .i_cpha         (w_cpha      )   ,
                .i_sclk         (SLVSCLK     )   ,
                .i_cs_n         (w_cs_n      )   ,
                .i_mosi         (SLVMOSI     )   ,
                .o_miso         (SLVMISO     )   ,
                .i_tx_data      (w_tx_data   )   ,
                .o_rx_data      (w_rx_data   )   ,
                .o_rx_valid     (w_rx_valid  )
);

endmodule
