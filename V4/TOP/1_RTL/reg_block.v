`timescale 1ns / 1ps
 
//==============================================================================
// reg_block : APB slave + register block of the Extended UART
//
//   Role   : Receives APB read/write requests from the CPU and connects them
//            to the settings, the FIFOs and the status of the inner modules.
//   Drawers: three kinds of registers
//              - setting  (stored in flip-flops) : UARTIBRD, UARTLCR_H, UARTCR, UARTIMSC
//              - status   (not stored, look only): UARTFR, UARTRIS, UARTMIS
//              - pass-thru(not stored, act only) : UARTDR (to/from FIFOs), UARTICR
//   Note   : PREADY is always 1 and PSLVERR is always 0 (no wait, no error).
//            i_paddr carries PADDR[11:2], i.e. byte offset / 4.
//==============================================================================
 
module reg_block (
                        clk             ,
                        nRst            ,
                        // APB bus side
                        i_psel          ,
                        i_penable       ,
                        i_pwrite        ,
                        i_paddr         ,
                        i_pwdata        ,
                        // status from FIFOs / tx_logic / interrupt logic
                        i_tx_full       ,
                        i_tx_empty      ,
                        i_rx_rdata      ,
                        i_rx_empty      ,
                        i_rx_full       ,
                        i_tx_busy       ,
                        i_ris           ,
                        i_mis           ,
                        // APB bus side (outputs)
                        o_prdata        ,
                        o_pready        ,
                        o_pslverr       ,
                        // to FIFOs / tx_logic / rx_logic / baud_gen / top / interrupt logic
                        o_tx_push       ,
                        o_tx_wdata      ,
                        o_rx_pop        ,
                        o_tx_en         ,
                        o_brk           ,
                        o_rx_en         ,
                        o_pen           ,
                        o_eps           ,
                        o_ibrd          ,
                        o_lbe           ,
                        o_imsc          ,
                        o_icr
);
input                   clk             ;   // single clock (same as PCLK)
input                   nRst            ;   // active-LOW reset (same as PRESETn)
input                   i_psel          ;   // this slave is selected
input                   i_penable       ;   // 1 only in the ACCESS phase
input                   i_pwrite        ;   // 1: write, 0: read
input       [9:0]       i_paddr         ;   // PADDR[11:2] (byte offset / 4)
input       [31:0]      i_pwdata        ;   // write data from CPU
input                   i_tx_full       ;   // TX FIFO is full
input                   i_tx_empty      ;   // TX FIFO is empty
input       [10:0]      i_rx_rdata      ;   // RX FIFO head {BE, PE, FE, DATA[7:0]}
input                   i_rx_empty      ;   // RX FIFO is empty
input                   i_rx_full       ;   // RX FIFO is full
input                   i_tx_busy       ;   // tx_logic is working (also during break)
input       [6:0]       i_ris           ;   // raw interrupt status from interrupt logic
input       [6:0]       i_mis           ;   // masked interrupt status from interrupt logic
output      [31:0]      o_prdata        ;   // read data to CPU
output                  o_pready        ;   // always 1
output                  o_pslverr       ;   // always 0
output                  o_tx_push       ;   // push request to TX FIFO (1 clock)
output      [7:0]       o_tx_wdata      ;   // character to push into TX FIFO
output                  o_rx_pop        ;   // pop request to RX FIFO (1 clock)
output                  o_tx_en         ;   // UARTEN && TXE, to tx_logic
output                  o_brk           ;   // LCR_H.BRK, to tx_logic
output                  o_rx_en         ;   // UARTEN && RXE, to rx_logic
output                  o_pen           ;   // LCR_H.PEN, shared by tx_logic and rx_logic
output                  o_eps           ;   // LCR_H.EPS, shared by tx_logic and rx_logic
output      [15:0]      o_ibrd          ;   // integer baud divisor, to baud_gen
output                  o_lbe           ;   // loopback enable, to uart_top
output      [6:0]       o_imsc          ;   // interrupt mask, to interrupt logic
output      [6:0]       o_icr           ;   // interrupt clear pulses, to interrupt logic
 
//------------------------------------------------------------------------------
// Drawer numbers = byte offset / 4  (this is what arrives on i_paddr)
//------------------------------------------------------------------------------
localparam  [9:0]       UARTDR      = 10'd0     ;   // offset 0x000
localparam  [9:0]       UARTFR      = 10'd6     ;   // offset 0x018
localparam  [9:0]       UARTIBRD    = 10'd9     ;   // offset 0x024
localparam  [9:0]       UARTLCR_H   = 10'd11    ;   // offset 0x02C
localparam  [9:0]       UARTCR      = 10'd12    ;   // offset 0x030
localparam  [9:0]       UARTIMSC    = 10'd14    ;   // offset 0x038
localparam  [9:0]       UARTRIS     = 10'd15    ;   // offset 0x03C
localparam  [9:0]       UARTMIS     = 10'd16    ;   // offset 0x040
localparam  [9:0]       UARTICR     = 10'd17    ;   // offset 0x044
 
//------------------------------------------------------------------------------
// Declarations (regs are declared before the read mux that uses them)
//------------------------------------------------------------------------------
wire                    w_wr_en         ;   // a write is confirmed (ACCESS phase, 1 clock)
wire                    w_rd_en         ;   // a read is confirmed  (ACCESS phase, 1 clock)
wire                    w_sel_dr        ;   // i_paddr points to UARTDR
wire                    w_sel_fr        ;   // i_paddr points to UARTFR
wire                    w_sel_ibrd      ;   // i_paddr points to UARTIBRD
wire                    w_sel_lcr_h     ;   // i_paddr points to UARTLCR_H
wire                    w_sel_cr        ;   // i_paddr points to UARTCR
wire                    w_sel_imsc      ;   // i_paddr points to UARTIMSC
wire                    w_sel_ris       ;   // i_paddr points to UARTRIS
wire                    w_sel_mis       ;   // i_paddr points to UARTMIS
wire                    w_sel_icr       ;   // i_paddr points to UARTICR
wire                    w_busy          ;   // UARTFR.BUSY
wire        [31:0]      w_fr            ;   // UARTFR value
wire        [31:0]      w_dr_rdata      ;   // value seen when reading UARTDR
wire        [31:0]      w_rdata         ;   // value chosen by the read mux
reg         [15:0]      r_ibrd          ;   // UARTIBRD storage
reg                     r_eps           ;   // UARTLCR_H[2] storage
reg                     r_pen           ;   // UARTLCR_H[1] storage
reg                     r_brk           ;   // UARTLCR_H[0] storage
reg                     r_rxe           ;   // UARTCR[9] storage
reg                     r_txe           ;   // UARTCR[8] storage
reg                     r_lbe           ;   // UARTCR[7] storage
reg                     r_uarten        ;   // UARTCR[0] storage
reg         [6:0]       r_imsc          ;   // UARTIMSC[10:4] storage
 
//------------------------------------------------------------------------------
// APB transfer decode
//   SETUP phase : PSEL=1, PENABLE=0 -> only the paper is on the desk, do nothing
//   ACCESS phase: PSEL=1, PENABLE=1 -> the real transfer happens here
//------------------------------------------------------------------------------
assign  w_wr_en     = i_psel && i_penable && i_pwrite       ;
assign  w_rd_en     = i_psel && i_penable && (!i_pwrite)    ;
 
// which drawer is addressed
assign  w_sel_dr    = (UARTDR == i_paddr)                   ;
assign  w_sel_fr    = (UARTFR == i_paddr)                   ;
assign  w_sel_ibrd  = (UARTIBRD == i_paddr)                 ;
assign  w_sel_lcr_h = (UARTLCR_H == i_paddr)                ;
assign  w_sel_cr    = (UARTCR == i_paddr)                   ;
assign  w_sel_imsc  = (UARTIMSC == i_paddr)                 ;
assign  w_sel_ris   = (UARTRIS == i_paddr)                  ;
assign  w_sel_mis   = (UARTMIS == i_paddr)                  ;
assign  w_sel_icr   = (UARTICR == i_paddr)                  ;
 
//------------------------------------------------------------------------------
// UARTFR (status, not stored)
//   [7]=TXFE [6]=RXFF [5]=TXFF [4]=RXFE [3]=BUSY, other bits are 0
//   BUSY = TX FIFO not empty OR tx_logic working.
//   The FIFO alone is not enough: the last character has already left the
//   FIFO while it is still being sent on the wire.
//------------------------------------------------------------------------------
assign  w_busy      = (!i_tx_empty) || i_tx_busy            ;
assign  w_fr        = {24'b0, i_tx_empty, i_rx_full, i_tx_full, i_rx_empty, w_busy, 3'b0};
 
// UARTDR read value: RX FIFO head {BE, PE, FE, DATA}; 0 when the FIFO is empty
// (the FIFO output is garbage when empty, so it must be masked here)
assign  w_dr_rdata  = i_rx_empty ? 32'b0 : {21'b0, i_rx_rdata}  ;
 
//------------------------------------------------------------------------------
// Read mux: choose one drawer by address. Unknown / write-only / reserved
// addresses read as 0. Each value is placed at its register bit position.
//------------------------------------------------------------------------------
assign  w_rdata     = w_sel_dr  ?   w_dr_rdata  :   
                      w_sel_fr  ?   w_fr        :   
                      w_sel_ibrd?   {16'b0,r_ibrd}  :   
                      w_sel_lcr_h?  {29'b0, r_eps, r_pen, r_brk}    :   
                      w_sel_cr  ?   {22'b0, r_rxe, r_txe, r_lbe, 6'b0, r_uarten} :  
                      w_sel_imsc?   {21'b0, r_imsc, 4'b0}   :   
                      w_sel_ris ?   {21'b0, i_ris, 4'b0}    :   
                      w_sel_mis ?   {21'b0, i_mis, 4'b0}    : 32'b0   ;   
 
//------------------------------------------------------------------------------
// Setting drawers (stored in flip-flops)
//   A value is stored only when a write is confirmed AND that drawer is
//   addressed. Otherwise the value is kept.
//------------------------------------------------------------------------------
 
// UARTIBRD : integer baud divisor (reset 0x00D9 = 217, 9600 bps at 33.333 MHz)
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_ibrd  <= 16'hD9               ;
    else if (w_wr_en && w_sel_ibrd)
        r_ibrd  <= i_pwdata[15:0]       ;
end
 
// UARTLCR_H : [2]=EPS even parity, [1]=PEN parity enable, [0]=BRK send break
always @(posedge clk or negedge nRst) begin
    if(!nRst) begin
        r_eps   <= 1'b0                 ;
        r_pen   <= 1'b0                 ;
        r_brk   <= 1'b0                 ;
    end
    else if (w_wr_en && w_sel_lcr_h) begin
        r_eps   <= i_pwdata[2]          ;
        r_pen   <= i_pwdata[1]          ;
        r_brk   <= i_pwdata[0]          ;
    end
end
 
// UARTCR : [9]=RXE, [8]=TXE, [7]=LBE loopback, [0]=UARTEN master switch
//          reset value is 0x300 (RXE=1, TXE=1), so the reset values differ
always @(posedge clk or negedge nRst) begin
    if (!nRst) begin    
        r_rxe       <= 1'b1             ;
        r_txe       <= 1'b1             ;
        r_lbe       <= 1'b0             ;
        r_uarten    <= 1'b0             ;
    end
    else if (w_wr_en && w_sel_cr) begin
        r_rxe       <= i_pwdata[9]      ;
        r_txe       <= i_pwdata[8]      ;
        r_lbe       <= i_pwdata[7]      ;
        r_uarten    <= i_pwdata[0]      ;
    end
end
 
// UARTIMSC : [10:4] interrupt mask bits (1 = interrupt allowed)
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_imsc      <= 7'd0             ;
    else if (w_wr_en && w_sel_imsc)
        r_imsc      <= i_pwdata[10:4]   ;
end
 
//------------------------------------------------------------------------------
// Outputs to the inner modules
//------------------------------------------------------------------------------
// settings go out as they are
assign  o_ibrd      = r_ibrd                ;
assign  o_pen       = r_pen                 ;
assign  o_eps       = r_eps                 ;
assign  o_brk       = r_brk                 ;
assign  o_lbe       = r_lbe                 ;
assign  o_imsc      = r_imsc                ;
 
// no wait state and no error response on APB
assign  o_pready    = 1'b1                  ;
assign  o_pslverr   = 1'b0                  ;
 
// master switch AND individual switch: both must be 1
assign  o_tx_en     = r_uarten && r_txe     ;
assign  o_rx_en     = r_uarten && r_rxe     ;
 
// UARTDR pass-thru: write -> push into TX FIFO, read -> pop from RX FIFO.
// Using w_wr_en / w_rd_en (ACCESS phase only) gives exactly 1 clock per transfer.
// A push into a full FIFO or a pop from an empty FIFO is filtered by the FIFO.
assign  o_tx_push   = w_wr_en && w_sel_dr   ;
assign  o_tx_wdata  = i_pwdata[7:0]         ;   // only the low 8 bits are the character
assign  o_rx_pop    = w_rd_en && w_sel_dr   ;
 
// read data to CPU
assign  o_prdata    = w_rdata               ;
 
// UARTICR pass-thru: a 1 written to a bit becomes a 1-clock clear pulse.
// Bits [1:0] (TX, RX level interrupts) cannot be cleared by ICR, so they stay 0.
assign  o_icr       = (w_sel_icr && w_wr_en) ? {i_pwdata[10:6], 2'b0} : 7'b0;
 
endmodule