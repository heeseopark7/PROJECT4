//==============================================================================
// Module  : spi_regs
// Purpose : Reads the APB access, keeps the registers (SPCR / SPSR / SPDR /
//           SPDIV) and controls spi_master.
//           Offset = PADDR[1:0] : 0 SPCR, 1 SPSR, 2 SPDR, 3 SPDIV
//           (4-byte spacing, the 4 registers repeat inside the slot).
//           Side effects of a write or read happen only in the ACCESS phase
//           (PSEL & PENABLE). The SETUP clock changes nothing.
//           PRDATA is a 4:1 mux on PADDR[1:0]; PSEL gating is done by the read
//           mux in mcu_top.
//
// Registers:
//   SPCR  : [0] SPE  [1] CPOL  [2] CPHA  [3] CS  [4] LOOP  [5] SPIE
//   SPSR  : [0] BUSY [1] DONE  [2] WCOL (write 1 to clear)
//   SPDR  : write = start a transfer, read = last received byte
//   SPDIV : reset value 25, effective divisor = max(SPDIV, 8)
//==============================================================================

`timescale 1ns / 1ps

module spi_regs (
                    clk                                 ,
                    nRst                                ,
                    i_psel                              ,
                    i_penable                           ,
                    i_pwrite                            ,
                    i_paddr                             ,
                    i_pwdata                            ,
                    o_prdata                            ,
                    o_start                             ,
                    o_tx_data                           ,
                    o_cpol                              ,
                    o_cpha                              ,
                    o_loop                              ,
                    o_div                               ,
                    i_busy                              ,
                    i_done                              ,
                    i_rx_data                           ,
                    o_cs_n                              ,
                    o_intr
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input               clk                                 ;   // clock (PCLK)
input               nRst                                ;   // reset, active-LOW, async assert
input               i_psel                              ;   // APB select
input               i_penable                           ;   // APB enable (ACCESS phase)
input               i_pwrite                            ;   // APB direction, 1 = write
input   [9:0]       i_paddr                             ;   // APB word address (only [1:0] is used)
input   [31:0]      i_pwdata                            ;   // APB write data
output  [31:0]      o_prdata                            ;   // APB read data
output              o_start                             ;   // start a transfer (1-clock pulse)
output  [7:0]       o_tx_data                           ;   // byte to send
output              o_cpol                              ;   // clock polarity
output              o_cpha                              ;   // clock phase
output              o_loop                              ;   // internal loopback
output  [7:0]       o_div                               ;   // effective divisor for sclk_gen
input               i_busy                              ;   // spi_master busy
input               i_done                              ;   // spi_master done pulse
input   [7:0]       i_rx_data                           ;   // spi_master received byte
output              o_cs_n                              ;   // chip select, active-LOW
output              o_intr                              ;   // interrupt (SPIE & DONE)

//------------------------------------------------------------------------------
// Parameters (register offsets)
//------------------------------------------------------------------------------
localparam [1:0]    A_SPCR  = 2'd0                      ;
localparam [1:0]    A_SPSR  = 2'd1                      ;
localparam [1:0]    A_SPDR  = 2'd2                      ;
localparam [1:0]    A_SPDIV = 2'd3                      ;

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
reg     [5:0]       r_spcr                              ;   // control register
reg     [7:0]       r_spdiv                             ;   // clock divisor, reset value 25
reg                 r_done_flag                         ;   // SPSR.DONE
reg                 r_wcol                              ;   // SPSR.WCOL
reg                 r_busy_flag                         ;   // 1 from start to done (covers the clock before i_busy rises)
reg     [31:0]      r_rdata                             ;   // read mux output

//------------------------------------------------------------------------------
// Internal wires
//------------------------------------------------------------------------------
wire    [1:0]       w_sel                               ;   // register offset
wire                w_acc                               ;   // ACCESS phase
wire                w_wr                                ;   // write in ACCESS
wire                w_rd                                ;   // read in ACCESS
wire                w_busy_eff                          ;   // busy seen by software
wire                w_spe                               ;   // SPI enable (SPCR.SPE)
wire                w_wr_spdr                           ;   // SPDR write
wire                w_rd_spdr                           ;   // SPDR read
wire                w_wcol_set                          ;   // write to SPDR while busy
wire                w_wcol_clr                          ;   // write 1 to SPSR.WCOL

assign  w_sel       = i_paddr[1:0]                      ;
assign  w_acc       = i_psel & i_penable                ;
assign  w_wr        = w_acc &  i_pwrite                 ;
assign  w_rd        = w_acc & ~i_pwrite                 ;
assign  w_busy_eff  = i_busy | r_busy_flag              ;
assign  w_spe       = r_spcr[0]                         ;
assign  w_wr_spdr   = w_wr & (w_sel == A_SPDR)          ;
assign  w_rd_spdr   = w_rd & (w_sel == A_SPDR)          ;

//------------------------------------------------------------------------------
// SPDR write
//   SPE=1 & not busy -> start a transfer
//   SPE=1 & busy     -> WCOL, the write is ignored
//------------------------------------------------------------------------------
assign  o_start     = w_wr_spdr & w_spe & ~w_busy_eff   ;
assign  w_wcol_set  = w_wr_spdr & w_spe &  w_busy_eff   ;
assign  w_wcol_clr  = w_wr & (w_sel == A_SPSR) & i_pwdata[2] ;

//------------------------------------------------------------------------------
// Outputs to spi_master / sclk_gen / pins
//------------------------------------------------------------------------------
assign  o_tx_data   = i_pwdata[7:0]                     ;
assign  o_cpol      = r_spcr[1]                         ;
assign  o_cpha      = r_spcr[2]                         ;
assign  o_loop      = r_spcr[4]                         ;
assign  o_cs_n      = ~r_spcr[3]                        ;
assign  o_div       = (r_spdiv < 8'd8) ? 8'd8 : r_spdiv ;   // effective divisor = max(SPDIV, 8)
assign  o_intr      = r_spcr[5] & r_done_flag           ;

//------------------------------------------------------------------------------
// Register update
//   busy_flag : set at start, cleared by the done pulse
//   DONE      : set has priority; cleared by an SPDR read or a new start
//   WCOL      : set has priority; write-1-to-clear
//------------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
    if (!nRst)  begin
        r_spcr      <=  6'd0            ;
        r_spdiv     <=  8'd25           ;
        r_done_flag <=  1'b0            ;
        r_wcol      <=  1'b0            ;
        r_busy_flag <=  1'b0            ;
    end
    else    begin
        if (w_wr && (w_sel == A_SPCR))  begin
            r_spcr      <=  i_pwdata[5:0]   ;
        end
        if (w_wr && (w_sel == A_SPDIV)) begin
            r_spdiv     <=  i_pwdata[7:0]   ;
        end

        if (o_start)    begin
            r_busy_flag <=  1'b1            ;
        end
        else if (i_done)    begin
            r_busy_flag <=  1'b0            ;
        end

        if (i_done) begin
            r_done_flag <=  1'b1            ;
        end
        else if (w_rd_spdr || o_start)  begin
            r_done_flag <=  1'b0            ;
        end

        if (w_wcol_set) begin
            r_wcol      <=  1'b1            ;
        end
        else if (w_wcol_clr)    begin
            r_wcol      <=  1'b0            ;
        end
    end
end

//------------------------------------------------------------------------------
// Read mux (combinational, valid in the same ACCESS clock)
//------------------------------------------------------------------------------
always @(*) begin
    case (w_sel)
    A_SPCR  :   r_rdata = {26'd0, r_spcr}                           ;
    A_SPSR  :   r_rdata = {29'd0, r_wcol, r_done_flag, w_busy_eff}  ;
    A_SPDR  :   r_rdata = {24'd0, i_rx_data}                        ;
    default :   r_rdata = {24'd0, r_spdiv}                          ;
    endcase
end

assign  o_prdata = r_rdata  ;

endmodule
