//==============================================================================
// Module  : spis_regs
// Purpose : APB register file of the SPI slave. It lets the CPU configure the
//           slave, set the reply byte and read the received byte.
//           Offset = PADDR[1:0] : 0 SSCR, 1 SSSR, 2 SSDR, 3 reserved
//           (4-byte spacing, the 4 offsets repeat inside the slot).
//           Side effects of a write or read happen only in the ACCESS phase
//           (PSEL & PENABLE). The SETUP clock changes nothing.
//           PRDATA is a 4:1 mux on PADDR[1:0]; PSEL gating is done by the read
//           mux in mcu_top.
//
// Registers:
//   SSCR : [0] SSE (slave enable)  [1] CPOL  [2] CPHA  [3] SSIE (interrupt enable)
//   SSSR : [0] RXNE (byte received, cleared by an SSDR read)
//          [1] OVR  (a byte arrived while RXNE was still 1, write 1 to clear)
//          [2] BSY  (chip select is active)
//   SSDR : write = reply byte for the next transfer
//          read  = last received byte (also clears RXNE)
//   The reply byte is taken by spi_slave when the master pulls CS_N low (and
//   right after each received byte), so write SSDR before the master starts.
//   Several bytes in one CS_N frame repeat the same reply byte, because
//   software cannot change SSDR fast enough between two bytes.
//   The master must set its SCLK idle level (CPOL) before it pulls CS_N low.
//==============================================================================

`timescale 1ns / 1ps

module spis_regs (
                    clk                                 ,
                    nRst                                ,
                    i_psel                              ,
                    i_penable                           ,
                    i_pwrite                            ,
                    i_paddr                             ,
                    i_pwdata                            ,
                    o_prdata                            ,
                    o_cpol                              ,
                    o_cpha                              ,
                    o_sse                               ,
                    o_tx_data                           ,
                    i_rx_data                           ,
                    i_rx_valid                          ,
                    i_cs_n                              ,
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
output              o_cpol                              ;   // clock polarity for spi_slave
output              o_cpha                              ;   // clock phase for spi_slave
output              o_sse                               ;   // slave enable (SSCR.SSE)
output  [7:0]       o_tx_data                           ;   // reply byte for spi_slave
input   [7:0]       i_rx_data                           ;   // received byte from spi_slave
input               i_rx_valid                          ;   // received byte ready, 1-clock pulse
input               i_cs_n                              ;   // chip select pin (asynchronous)
output              o_intr                              ;   // interrupt (SSIE & RXNE)

//------------------------------------------------------------------------------
// Parameters (register offsets)
//------------------------------------------------------------------------------
localparam [1:0]    A_SSCR  = 2'd0                      ;
localparam [1:0]    A_SSSR  = 2'd1                      ;
localparam [1:0]    A_SSDR  = 2'd2                      ;

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
reg     [3:0]       r_sscr                              ;   // control register
reg     [7:0]       r_tx_data                           ;   // reply byte
reg     [7:0]       r_rx_data                           ;   // last received byte
reg                 r_rxne                              ;   // SSSR.RXNE
reg                 r_ovr                               ;   // SSSR.OVR
reg     [1:0]       r_cs_s                              ;   // CS_N synchronizer (for BSY)
reg     [31:0]      r_rdata                             ;   // read mux output

//------------------------------------------------------------------------------
// Internal wires
//------------------------------------------------------------------------------
wire    [1:0]       w_sel                               ;   // register offset
wire                w_acc                               ;   // ACCESS phase
wire                w_wr                                ;   // write in ACCESS
wire                w_rd                                ;   // read in ACCESS
wire                w_rd_ssdr                           ;   // SSDR read
wire                w_ovr_clr                           ;   // write 1 to SSSR.OVR

assign  w_sel       = i_paddr[1:0]                      ;
assign  w_acc       = i_psel & i_penable                ;
assign  w_wr        = w_acc &  i_pwrite                 ;
assign  w_rd        = w_acc & ~i_pwrite                 ;
assign  w_rd_ssdr   = w_rd & (w_sel == A_SSDR)          ;
assign  w_ovr_clr   = w_wr & (w_sel == A_SSSR) & i_pwdata[1] ;

assign  o_sse       = r_sscr[0]                         ;
assign  o_cpol      = r_sscr[1]                         ;
assign  o_cpha      = r_sscr[2]                         ;
assign  o_tx_data   = r_tx_data                         ;
assign  o_intr      = r_sscr[3] & r_rxne                ;

//------------------------------------------------------------------------------
// Register update
//   RXNE : set by a received byte (priority); cleared by an SSDR read
//   OVR  : set when a byte arrives while RXNE is 1 (priority); write-1-to-clear
//   The newest received byte always replaces SSDR.
//------------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
    if (!nRst)  begin
        r_sscr      <=  4'd0            ;
        r_tx_data   <=  8'd0            ;
        r_rx_data   <=  8'd0            ;
        r_rxne      <=  1'b0            ;
        r_ovr       <=  1'b0            ;
        r_cs_s      <=  2'b11           ;
    end
    else    begin
        r_cs_s      <=  {r_cs_s[0], i_cs_n}     ;

        if (w_wr && (w_sel == A_SSCR))  begin
            r_sscr      <=  i_pwdata[3:0]       ;
        end
        if (w_wr && (w_sel == A_SSDR))  begin
            r_tx_data   <=  i_pwdata[7:0]       ;
        end

        if (i_rx_valid) begin
            r_rx_data   <=  i_rx_data           ;
            r_rxne      <=  1'b1                ;
        end
        else if (w_rd_ssdr) begin
            r_rxne      <=  1'b0                ;
        end

        if (i_rx_valid && r_rxne)   begin
            r_ovr       <=  1'b1                ;
        end
        else if (w_ovr_clr) begin
            r_ovr       <=  1'b0                ;
        end
    end
end

//------------------------------------------------------------------------------
// Read mux (combinational, valid in the same ACCESS clock)
//------------------------------------------------------------------------------
always @(*) begin
    case (w_sel)
    A_SSCR  :   r_rdata = {28'd0, r_sscr}                       ;
    A_SSSR  :   r_rdata = {29'd0, ~r_cs_s[1], r_ovr, r_rxne}    ;
    A_SSDR  :   r_rdata = {24'd0, r_rx_data}                    ;
    default :   r_rdata = 32'd0                                 ;
    endcase
end

assign  o_prdata = r_rdata  ;

endmodule
