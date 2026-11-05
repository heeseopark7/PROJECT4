`timescale 1ns / 1ps
 
//------------------------------------------------------------------------------
// rx_logic : Extended UART receive logic (8 data bits, optional parity, 1 stop)
//
//   - Watches the synchronized RXD line, finds the start bit, samples every
//     bit at the middle of its cell (16 ticks per bit), and rebuilds one
//     character.
//   - At the middle of the stop bit the character is complete:
//       FIFO has room -> o_fifo_push = 1 for one clock, with o_fifo_wdata
//       FIFO is full  -> o_overrun   = 1 for one clock, the character is dropped
//   - o_fifo_wdata = {BE, PE, FE, DATA[7:0]}  (same layout as UARTDR[10:0])
//   - i_rxd must already be synchronized to clk (2-FF synchronizer and the
//     loopback mux are outside this module).
//------------------------------------------------------------------------------
module rx_logic (
            clk             ,
            nRst            ,
            i_rxd           ,
            i_tick_16x      ,
            i_rx_en         ,
            i_pen           ,
            i_eps           ,
            i_fifo_full     ,
            o_fifo_push     ,
            o_fifo_wdata    ,
            o_overrun   
);
 
input                   clk             ;   // single clock
input                   nRst            ;   // active-LOW asynchronous reset
input                   i_rxd           ;   // synchronized RXD, idle = 1
input                   i_tick_16x      ;   // 1-clock pulse, 16 per bit time
input                   i_rx_en         ;   // UARTEN & RXE, checked only in IDLE
input                   i_pen           ;   // 1: a parity cell exists
input                   i_eps           ;   // 1: even parity, 0: odd parity
input                   i_fifo_full     ;   // RX FIFO is full
output                  o_fifo_push     ;   // push the finished character
output      [10:0]      o_fifo_wdata    ;   // {BE, PE, FE, DATA[7:0]}
output                  o_overrun       ;   // character finished but FIFO full
 
// FSM states: each state is named after the cell we are waiting to sample
localparam  [2:0]       IDLE    = 3'b000;   // waiting for a start edge
localparam  [2:0]       START   = 3'b001;   // checking the start cell (8 ticks)
localparam  [2:0]       DATA    = 3'b010;   // sampling D0..D7
localparam  [2:0]       PARITY  = 3'b011;   // sampling the parity cell (PEN=1 only)
localparam  [2:0]       STOP    = 3'b100;   // sampling the stop cell
 
reg                     r_rxd_d         ;   // i_rxd delayed by one clock
wire                    w_start_edge    ;   // 1 -> 0 edge on i_rxd
reg         [3:0]       r_tick_cnt      ;   // ticks counted inside the current cell
wire                    w_half          ;   // 8th tick (middle of the start cell)
wire                    w_bit_end       ;   // 16th tick (middle of the next cell)
reg         [2:0]       r_bit_cnt       ;   // index of the data bit being waited for
wire                    w_last_bit      ;   // waiting for D7
reg         [2:0]       r_state         ;   // current state
wire                    w_shift_en      ;   // sample moment of a data bit
wire                    w_par_end       ;   // sample moment of the parity bit
wire                    w_stop_end      ;   // sample moment of the stop bit
wire                    w_fe            ;   // framing error (stop bit = 0)
wire                    w_exp_par       ;   // parity bit we expect to receive
reg         [7:0]       r_shift         ;   // received data bits
wire                    w_pe_raw        ;   // parity mismatch before break masking
reg                     r_pbit          ;   // received parity bit
wire                    w_be            ;   // break (data, parity, stop all 0)
wire                    w_pe            ;   // final parity error (masked by break)
 
// r_rxd_d : remember the previous i_rxd so a falling edge can be detected
// reset value 1 = idle level, so reset cannot create a fake start edge
always @(posedge clk or negedge nRst) begin
    if  (!nRst)
        r_rxd_d <= 1'b1                 ;
    else
        r_rxd_d <= i_rxd                ;
end
 
// start edge is checked on every clk (not only on ticks) to keep the phase error small
assign  w_start_edge    = r_rxd_d && (!i_rxd)                   ;
// r_tick_cnt counts from 0, so the k-th tick sees r_tick_cnt = k-1
assign  w_half          = i_tick_16x && (r_tick_cnt == 4'd7)    ;   // 8th tick
assign  w_bit_end       = i_tick_16x && (r_tick_cnt == 4'd15)   ;   // 16th tick
assign  w_last_bit      = (r_bit_cnt == 3'd7)                   ;   // still 7 at the D7 sample clock
// same sample moment, split per state
assign  w_shift_en      = (r_state == DATA) && (w_bit_end)      ;
assign  w_par_end       = (r_state == PARITY) && (w_bit_end)    ;
assign  w_stop_end      = (r_state == STOP) && (w_bit_end)      ;
// framing error: the stop cell must be 1 (only meaningful when w_stop_end = 1)
assign  w_fe            = (r_state == STOP) && (!i_rxd)         ;
// expected parity: XOR of all data bits = 1 when the number of 1s is odd
// even parity -> same as the XOR, odd parity -> inverted
assign  w_exp_par       = i_eps ? (^r_shift) : !(^r_shift)      ; 
assign  w_pe_raw        = (i_pen) && (w_exp_par != r_pbit)      ;
// break: data all 0, parity cell 0 (or no parity cell), stop cell 0
assign  w_be            = (w_fe) && (r_shift == 8'h00) && (!i_pen || !r_pbit);
// a break frame is reported as BE=1, FE=1, PE=0 (odd parity would raise PE by accident)
assign  w_pe            = (w_pe_raw) && (!w_be)                 ;
 
// r_tick_cnt : tick counter inside one cell
//   - restart at 0 at the start-cell middle (START -> DATA) and at every cell end
//   - +1 on every other tick while a frame is running
//   - holds in IDLE (it is always 0 there)
// the clear branches are above the +1 branches because both can be true in the same clock
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_tick_cnt  <= 4'd0             ;
    else if ((r_state == START)&&w_half)
        r_tick_cnt  <= 4'd0             ;
    else if (w_shift_en||w_stop_end||((r_state == PARITY)&&(w_bit_end)))
        r_tick_cnt  <= 4'd0             ;
    else if ((r_state == START)&&(!w_half)&&(i_tick_16x))
        r_tick_cnt  <= r_tick_cnt + 1   ;
    else if (((r_state == DATA)||(r_state == PARITY)||(r_state == STOP))&&(i_tick_16x))
        r_tick_cnt  <= r_tick_cnt + 1   ;
    else if (r_state == IDLE)
        r_tick_cnt  <= r_tick_cnt       ;
end
 
// r_state : FSM, every transition happens on a tick except IDLE -> START
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_state <= IDLE     ;
    else begin
        case (r_state)
            // start edge seen and receiving is enabled
            IDLE    :   if (w_start_edge&&i_rx_en)
                            r_state <=  START       ;
            // at the 8th tick the line must still be 0, otherwise it was a glitch
            START   :   if (w_half&&(!i_rxd))
                            r_state <=  DATA        ;
                        else if (w_half&&i_rxd)
                            r_state <=  IDLE        ;                 
            // after D7: go to PARITY if a parity cell exists, else to STOP
            DATA    :   if (w_bit_end) begin
                            if (w_last_bit&&i_pen)
                                r_state <=  PARITY  ;
                            else if (w_last_bit&&(!i_pen))
                                r_state <=  STOP    ; 
                        end
            PARITY  :   if  (w_bit_end)
                            r_state <=  STOP        ;
            // back to IDLE at the middle of the stop cell, so a fast next start is not missed
            STOP    :   if  (w_bit_end)
                            r_state <=  IDLE        ;
        endcase
    end
end
 
// r_bit_cnt : which data cell is next (0..7), cleared when DATA begins
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_bit_cnt   <=  3'd0            ;
    else if ((r_state==START)&&(w_half))
        r_bit_cnt   <=  3'd0            ;
    else if (w_shift_en)
        r_bit_cnt   <=  r_bit_cnt + 1   ; 
end
 
// r_shift : new bit enters at the left end, old bits move right
// data is sent LSB first, so after 8 shifts D0 sits at bit 0
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_shift <= 8'b0                     ;
    else if (w_shift_en)
        r_shift <= {i_rxd,{r_shift[7:1]}}   ;
end
 
// r_pbit : keep the received parity bit until the stop cell is judged
always @(posedge clk or negedge nRst) begin
    if (!nRst)
        r_pbit  <=  1'b0    ;
    else if (w_par_end)
        r_pbit  <=  i_rxd   ;
end
 
// character complete at w_stop_end: push it, or report overrun if the FIFO is full
// both outputs are 1-clock pulses because w_stop_end is a 1-clock pulse
// o_fifo_wdata is only valid while o_fifo_push = 1
assign  o_fifo_push     = (w_stop_end)&&(!i_fifo_full)  ;
assign  o_overrun       = (w_stop_end)&&(i_fifo_full)   ;
assign  o_fifo_wdata    = {w_be, w_pe, w_fe, r_shift}   ;
 
 
endmodule