//==============================================================================
// Module  : tx_logic
// Purpose : Serializes a byte taken from the TX FIFO into a UART frame and
//           drives it on o_txd. (8N1 / even or odd parity / break supported)
//
// Frame   : idle(1) -> start(0) -> D0~D7 (LSB first) -> [parity] -> stop(1)
//           One bit time = 16 pulses of i_tick_16x.
//           The parity bit exists only when i_pen = 1.
//
// States  : IDLE -> START -> DATA -> (PARITY) -> STOP -> (IDLE | START | BREAK)
//           IDLE / STOP -> BREAK -> STOP
//
// Hookup  : i_tick_16x   <- baud_gen  o_tick_16x
//           i_fifo_empty <- tx_fifo   o_empty
//           i_fifo_rdata <- tx_fifo   o_rdata
//           o_fifo_pop   -> tx_fifo   i_pop
//
// Rules   : - Every state transition and counter update happens only on a
//             clock where i_tick_16x is 1.
//           - A frame in progress is always finished, even if i_tx_en drops.
//             i_tx_en is checked only when a new frame (or break) is started.
//           - Break (decision D1): enter only when i_tx_en = 1,
//             leave only when i_brk = 0.
//           - o_tx_busy stays 1 during break (decision D2: r_state != IDLE).
//==============================================================================
`timescale 1ns / 1ps
 
module tx_logic (
				clk				,
				nRst			,
				i_tick_16x		,
				i_tx_en			,
				i_brk			,
				i_fifo_empty	,
				i_pen			,
				i_fifo_rdata	,
				i_eps			,
				o_fifo_pop		,
				o_txd			,
				o_tx_busy
);
 
	//--------------------------------------------------------------------------
	// Ports
	//--------------------------------------------------------------------------
	input				clk				;	// PCLK
	input				nRst			;	// asynchronous reset, active-LOW
	input				i_tick_16x		;	// baud_gen tick, 1-clock pulse, 16 per bit
	input				i_tx_en			;	// transmit enable (UARTEN & TXE, ANDed in the register block)
	input				i_brk			;	// LCR_H.BRK : 1 = break requested
	input				i_fifo_empty	;	// TX FIFO is empty
	input				i_pen			;	// LCR_H.PEN : 1 = parity bit enabled
	input		[7:0]	i_fifo_rdata	;	// oldest FIFO entry, valid only while i_fifo_empty = 0
	input				i_eps			;	// LCR_H.EPS : 1 = even parity, 0 = odd parity
	output				o_fifo_pop		;	// tells the FIFO "taken"; 1 clock, only when a frame starts
	output				o_txd			;	// value driven on the wire (UARTTXD)
	output				o_tx_busy		;	// frame/break in progress (1 whenever not IDLE)
 
	//--------------------------------------------------------------------------
	// State encoding
	//--------------------------------------------------------------------------
	localparam	[2:0]	IDLE	= 3'b000;	// resting; wire = 1, waiting for a start moment
	localparam	[2:0]	START	= 3'b001;	// start bit; wire = 0, 16 ticks
	localparam	[2:0]	DATA	= 3'b010;	// 8 data bits; wire = r_shift[0], 8 x 16 ticks
	localparam	[2:0]	PARITY	= 3'b011;	// parity bit (only if i_pen = 1); wire = r_par, 16 ticks
	localparam	[2:0]	STOP	= 3'b100;	// stop bit; wire = 1, 16 ticks
	localparam	[2:0]	BREAK	= 3'b101;	// break; wire = 0 until i_brk goes low
 
	//--------------------------------------------------------------------------
	// Internal signals
	//--------------------------------------------------------------------------
	wire				w_can_start		;	// permission to start a new frame
	wire				w_bit_end		;	// this clock ends the current bit (16th tick)
	wire				w_load			;	// this clock is the start moment (permission + timing)
	reg 		[3:0]	r_tick_cnt		;	// ticks counted in the current bit (0~15)
	reg			[2:0]	r_state			;	// current state
	reg			[2:0]	r_bit_cnt		;	// data bit index (D0 = 0 ... D7 = 7)
	reg			[7:0]	r_shift			;	// byte being sent; r_shift[0] is the "window"
	reg					o_txd			;	// combinational output (driven in always @(*))
	wire				w_parity		;	// parity bit value computed from the FIFO head
	reg					r_par			;	// parity bit value captured at the start moment
 
	//--------------------------------------------------------------------------
	// Combinational signals
	//--------------------------------------------------------------------------
	// Permission to start: transmit enabled && FIFO has data && no break request
	assign	w_can_start	= i_tx_en && !i_fifo_empty && !i_brk	; // new character start
 
	// End of bit: a tick arrives && 15 ticks already counted (so this is the 16th)
	assign	w_bit_end	= i_tick_16x && (r_tick_cnt == 4'd15)	; // 
 
	// Start moment: 1 only in the two cases below. On this clock the pop, the
	// r_shift/r_par load and the START transition all happen together.
	//   case 1) in IDLE when a tick arrives (permission granted)
	//   case 2) when STOP ends (permission granted) -> chain the next frame
	//           without going through IDLE
	assign	w_load		= ((r_state == IDLE) && i_tick_16x && w_can_start) || ((r_state == STOP) && w_bit_end && w_can_start);
 
	//--------------------------------------------------------------------------
	// State transitions (r_state)
	//   IDLE   -> START  : w_load
	//   IDLE   -> BREAK  : tick && i_brk && i_tx_en
	//   START  -> DATA   : w_bit_end
	//   DATA   -> PARITY : w_bit_end && last data bit (r_bit_cnt==7) && i_pen
	//   DATA   -> STOP   : w_bit_end && last data bit (r_bit_cnt==7) && !i_pen
	//   PARITY -> STOP   : w_bit_end
	//   STOP   -> START  : w_load (chain the next byte if one is waiting)
	//   STOP   -> BREAK  : w_bit_end && i_brk && i_tx_en
	//   STOP   -> IDLE   : w_bit_end (when neither of the above applies)
	//   BREAK  -> STOP   : tick && !i_brk (STOP then holds the wire at 1 for
	//                      16 ticks)
	//   * In STOP the checks must be ordered: w_load, break, then IDLE.
	//--------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
	if (!nRst)
		r_state <= IDLE					;
	else begin
		case (r_state)
			IDLE	: 	if(w_load) 
							r_state <= START					;
						else if(i_tick_16x&&i_brk&&i_tx_en)
							r_state <= BREAK					;
			START	: 	if(w_bit_end)
							r_state <= DATA						;
			DATA	: 	if(w_bit_end&&(r_bit_cnt==3'd7))
							if(i_pen)
								r_state <= PARITY				;
							else
							r_state <= STOP	;
			PARITY	: 	if(w_bit_end)
							r_state <= STOP						;
			STOP	: 	if(w_load) 
							r_state <= START					;
					  	else if(w_bit_end&&i_brk&&i_tx_en)
							r_state <= BREAK					;
						else if(w_bit_end) 
					  		r_state <= IDLE						;
			BREAK	:	if(i_tick_16x&&!i_brk)
							r_state <= STOP						;
			default	: r_state <= IDLE							;
 
		endcase
	end
end
 
	//--------------------------------------------------------------------------
	// Tick counter (r_tick_cnt)
	//   Cleared when a bit ends, otherwise +1 on every tick.
	//   It does not count in IDLE or BREAK:
	//   - IDLE : the 0 left by w_bit_end at the end of STOP is kept, so START
	//            always begins at 0.
	//   - BREAK: if it counted, the value on returning to STOP would be random
	//            and STOP would not last 16 ticks.
	//   w_bit_end must be checked first so the counter wraps from 15 to 0.
	//--------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
	if (!nRst)
		r_tick_cnt <= 4'd0				;
	else if (w_bit_end)
		r_tick_cnt <= 4'd0				;
	else if (i_tick_16x && (r_state != IDLE) && (r_state!= BREAK))
		r_tick_cnt <= r_tick_cnt + 1	;
end
 
	//--------------------------------------------------------------------------
	// Data bit index (r_bit_cnt)
	//   +1 each time a data bit ends in DATA.
	//   After D7 it wraps 111 + 1 = 000 (3 bits), so the next byte starts at 0.
	//--------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
	if (!nRst)
		r_bit_cnt	<= 3'd0				;
	else if ((r_state == DATA) && w_bit_end)
		r_bit_cnt	<= r_bit_cnt + 1	;
end
 
	//--------------------------------------------------------------------------
	// Data shift register (r_shift)
	//   load : at the start moment, copy the whole FIFO head byte
	//          (the value just before the edge = the value before the pop)
	//   shift: in DATA, shift right by one each time a bit ends
	//          (zero fill on the left) -> D0, D1, ... (LSB first) come down to
	//          the window r_shift[0]
	//   It is not shifted during START; the byte is simply held.
	//--------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
	if (!nRst)
		r_shift <= 8'd0					;
	else if (w_load)
		r_shift <= i_fifo_rdata			;
	else if ((r_state == DATA) && w_bit_end)
		r_shift <= r_shift >> 1			;
end
 
	//--------------------------------------------------------------------------
	// Wire value (o_txd): combinational output decided by the state
	//   IDLE=1, START=0, DATA=window bit, PARITY=r_par, STOP=1, BREAK=0
	//--------------------------------------------------------------------------
always @(*) begin
	case (r_state)
		IDLE	: o_txd = 1				;
		START	: o_txd = 0				;
		DATA	: o_txd = r_shift[0]	;
		STOP	: o_txd = 1				;
		PARITY	: o_txd = r_par			;
		BREAK	: o_txd = 0				;
		default : o_txd = 1				;
	endcase
end
 
	//--------------------------------------------------------------------------
	// Parity
	//   ^i_fifo_rdata : XOR reduction, 1 when the number of 1s is odd
	//                   = the even-parity bit value
	//   i_eps = 1 : even parity -> use as is,  i_eps = 0 : odd parity -> invert
	//   r_par : captured only at the start moment, because the FIFO shows the
	//           next entry right after the pop.
	//--------------------------------------------------------------------------
assign	w_parity	= i_eps ? (^i_fifo_rdata) : ~(^i_fifo_rdata);
 
always @(posedge clk or negedge nRst) begin
	if(!nRst)
		r_par	<= 1'b0					;
	else if (w_load)
		r_par	<= w_parity				;
end
 
	//--------------------------------------------------------------------------
	// Outputs
	//--------------------------------------------------------------------------
	// Tell the FIFO "taken": same signal as the start moment (1-clock pulse)
assign	o_fifo_pop	= w_load			;
	// 1 while a frame or a break is in progress
assign	o_tx_busy	= (r_state != IDLE)	;
 
endmodule