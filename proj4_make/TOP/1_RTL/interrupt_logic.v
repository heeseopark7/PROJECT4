`timescale 1ns / 1ps
 
//------------------------------------------------------------------------------
// interrupt_logic
//   Builds the interrupt status of the Extended UART.
//   - RIS : raw status (7 bits), independent of the mask
//   - MIS : masked status = RIS & IMSC
//   - 5 interrupt outputs (RX, TX, RT, error, combined), all derived from MIS
//
//   7-bit vector order (same for i_imsc, i_icr, o_ris, o_mis, w_ris, w_mis):
//     [6]=OE  [5]=BE  [4]=PE  [3]=FE  [2]=RT  [1]=TX  [0]=RX
//
//   Interrupt types:
//     level type (no flop) : RX, TX    - follow the FIFO count
//     latch type (flop)    : OE, BE, PE, FE, RT
//                            set by an event, cleared by ICR
//                            (RT is also cleared when the RX FIFO is empty)
//------------------------------------------------------------------------------
module interrupt_logic #(
parameter           FIFO_DEPTH  = 16    ,                   // FIFO depth (power of 2)
parameter           CNT_W       = $clog2(FIFO_DEPTH)+1      // width of the FIFO count ports (0..FIFO_DEPTH)
)(
                    clk                 ,
                    nRst                ,
                    i_tx_count          ,
                    i_rx_count          ,
                    i_rx_empty          ,
                    i_rx_push           ,
                    i_rx_err            ,
                    i_overrun           ,
                    i_tick_16x          ,
                    i_imsc              ,
                    i_icr               ,
                    o_ris               ,
                    o_mis               ,
                    o_rxintr            ,
                    o_txintr            ,
                    o_rtintr            ,
                    o_eintr             ,
                    o_intr
);
 
// Receive timeout limit in tick_16x units (512 ticks = 32 bit times). Fixed by the spec.
localparam          RT_CNT      = 512   ;
 
input                   clk             ;   // single clock (PCLK)
input                   nRst            ;   // active-LOW reset
input   [CNT_W-1:0]     i_tx_count      ;   // number of characters in the TX FIFO
input   [CNT_W-1:0]     i_rx_count      ;   // number of characters in the RX FIFO
input                   i_rx_empty      ;   // RX FIFO is empty
input                   i_rx_push       ;   // 1-clk pulse: a character is written into the RX FIFO
input   [2:0]           i_rx_err        ;   // error flags of the pushed character: [2]=BE [1]=PE [0]=FE (valid only when i_rx_push=1)
input                   i_overrun       ;   // 1-clk pulse: a character was dropped because the RX FIFO was full
input                   i_tick_16x      ;   // 1-clk pulse from baud_gen, counted by the RT timer
input   [6:0]           i_imsc          ;   // interrupt mask (1 = enable the interrupt)
input   [6:0]           i_icr           ;   // 1-clk pulse: 1 clears the matching latch (bits [1:0] are always 0)
output  [6:0]           o_ris           ;   // raw interrupt status
output  [6:0]           o_mis           ;   // masked interrupt status
output                  o_rxintr        ;   // RX interrupt   (MIS[0])
output                  o_txintr        ;   // TX interrupt   (MIS[1])
output                  o_rtintr        ;   // RT interrupt   (MIS[2])
output                  o_eintr         ;   // error interrupt (OR of MIS[6:3])
output                  o_intr          ;   // combined interrupt (OR of all MIS bits)
 
// ---- combinational signals ----
wire                    w_rx_lvl        ;   // RX FIFO is at least half full
wire                    w_tx_lvl        ;   // TX FIFO is at most half full
wire                    w_fe_set        ;   // set event: framing error character pushed
wire                    w_pe_set        ;   // set event: parity error character pushed
wire                    w_be_set        ;   // set event: break error character pushed
wire                    w_oe_set        ;   // set event: overrun occurred
wire                    w_rt_set        ;   // set event: RT timer reaches the limit in this clock
wire    [6:0]           w_ris           ;   // raw status vector
wire    [6:0]           w_mis           ;   // masked status vector
 
// ---- registers ----
reg                     r_fe            ;   // FE latch
reg                     r_pe            ;   // PE latch
reg                     r_be            ;   // BE latch
reg                     r_oe            ;   // OE latch
reg     [9:0]           r_rt_cnt        ;   // RT timer (counts tick_16x, 0..512, needs 10 bits)
reg                     r_rt            ;   // RT latch
 
// Level type: compare the FIFO count only, no flop.
assign  w_rx_lvl    = (i_rx_count >= FIFO_DEPTH/2)  ;   // RX: count >= half
assign  w_tx_lvl    = (i_tx_count <= FIFO_DEPTH/2)  ;   // TX: count <= half
 
// Set events of the error latches.
// FE/PE/BE are valid only in the clock where the character is pushed.
// A dropped (overrun) character has no push, so only OE is set for it.
assign  w_fe_set    = i_rx_push && i_rx_err[0]      ;
assign  w_pe_set    = i_rx_push && i_rx_err[1]      ;
assign  w_be_set    = i_rx_push && i_rx_err[2]      ;
assign  w_oe_set    = i_overrun                     ;
 
// RT set event: the timer moves from 511 to 512 in this clock.
// All four conditions are needed so that this event always matches the timer:
//   tick          : the timer only counts on a tick
//   cnt == 511    : this tick is the 512th one
//   !i_rx_empty   : nothing to collect when the FIFO is empty
//   !i_rx_push    : a push in the same clock restarts the timer, so no set
assign  w_rt_set    = i_tick_16x && (r_rt_cnt == RT_CNT-1) && !i_rx_empty && !i_rx_push ;
 
// Raw status vector: OE, BE, PE, FE, RT, TX, RX (bit 6 down to bit 0).
assign  w_ris       = {r_oe, r_be, r_pe, r_fe, r_rt, w_tx_lvl, w_rx_lvl}                ;
 
// Masked status: bitwise AND, an interrupt is visible only if its mask bit is 1.
assign  w_mis       = w_ris & i_imsc                ;
 
// Status outputs to reg_block.
assign  o_ris       = w_ris                         ;
assign  o_mis       = w_mis                         ;
 
// Interrupt outputs, all made from MIS (not RIS).
assign  o_rxintr    = w_mis[0]                      ;
assign  o_txintr    = w_mis[1]                      ;
assign  o_rtintr    = w_mis[2]                      ;
assign  o_eintr     = |w_mis[6:3]                   ;   // reduction OR of OE, BE, PE, FE
assign  o_intr      = |w_mis                        ;   // reduction OR of all 7 bits
 
// ---- error latches ----
// Priority (top wins): reset > set event > ICR clear > hold.
// Set beats clear, so a new error in the same clock as an ICR write is not lost.
 
// FE latch (ICR bit 3)
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_fe    <= 1'b0                 ;
    else if (w_fe_set)
        r_fe    <= 1'b1                 ;
    else if (i_icr[3])
        r_fe    <= 1'b0                 ;
end
 
// PE latch (ICR bit 4)
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_pe    <= 1'b0                 ;
    else if (w_pe_set)
        r_pe    <= 1'b1                 ;
    else if (i_icr[4])
        r_pe    <= 1'b0                 ;
end
 
// BE latch (ICR bit 5)
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_be    <= 1'b0                 ;
    else if (w_be_set)
        r_be    <= 1'b1                 ;
    else if (i_icr[5])
        r_be    <= 1'b0                 ;
end
 
// OE latch (ICR bit 6)
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_oe        <= 1'b0                 ;
    else if (w_oe_set)
        r_oe        <= 1'b1                 ;
    else if (i_icr[6])
        r_oe        <= 1'b0                 ;
end
 
// ---- RT timer ----
// Priority (top wins): reset > push > FIFO empty > count a tick > hold.
//   push        : a new character restarts the timer from 0
//   FIFO empty  : keep the timer at 0 and do not count
//   tick        : +1, but stop at RT_CNT (no wrap-around, so RT is not set again)
//   otherwise   : hold (no else branch)
// The push and empty lines must stay above the tick line, so that a tick in the
// same clock as a push does not add 1.
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_rt_cnt    <= 10'd0            ;
    else if (i_rx_push)
        r_rt_cnt    <= 10'd0            ;
    else if (i_rx_empty)
        r_rt_cnt    <= 10'd0            ;
    else if (i_tick_16x && r_rt_cnt != RT_CNT)
        r_rt_cnt    <= r_rt_cnt + 1     ;
end
 
// ---- RT latch (ICR bit 2) ----
// Priority (top wins): reset > set event > clear > hold.
// Clear conditions: ICR bit 2 is 1, or the RX FIFO is empty (nothing left to collect).
// The latch does not depend on i_imsc (RIS is the raw status for all 7 interrupts).
// After an ICR clear, RT is not set again until a new character restarts the timer,
// because the timer stays at RT_CNT and never passes 511 -> 512 again.
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_rt        <= 1'b0             ;
    else if (w_rt_set)
        r_rt        <= 1'b1             ;
    else if (i_icr[2] || i_rx_empty)
        r_rt        <= 1'b0             ;
end
 
 
endmodule