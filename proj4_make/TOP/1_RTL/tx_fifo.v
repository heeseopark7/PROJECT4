//==============================================================================
// Module  : tx_fifo
// Purpose : Synchronous FIFO built as a circular buffer. Software writes bytes
//           in, and tx_logic takes them out oldest-first.
//           Default 16 entries x 8 bits. Written generically so the same module
//           can be reused as the RX FIFO.
//
// Parameters:
//   DATA_WIDTH : bits per entry
//   FIFO_DEPTH : number of entries (power of 2 only, so the pointers wrap
//                by themselves)
//   PTR_W      : pointer width, derived from FIFO_DEPTH
//   CNT_W      : count width, one bit wider than PTR_W so it can hold
//                FIFO_DEPTH
//
// Behavior:
//   - A push is accepted only when the FIFO is not full, a pop only when it is
//     not empty. Otherwise the request is ignored.
//   - Full and push+pop in the same clock: the push is dropped and only the pop
//     is done (count FIFO_DEPTH -> FIFO_DEPTH-1). (Decision: strict rule)
//   - Empty and push+pop in the same clock: the pop is ignored, the push is
//     accepted.
//   - o_rdata is a combinational read of the oldest entry and is valid only
//     while o_empty = 0. i_pop is the "taken" stamp that advances the read side.
//   - Reset clears the pointers and the count. The memory array is not reset.
//==============================================================================
`timescale 1ns / 1ps
 
module tx_fifo #(
	parameter DATA_WIDTH = 8					,	// bits per entry
	parameter FIFO_DEPTH = 16					,	// number of entries (power of 2)
	parameter PTR_W      = $clog2(FIFO_DEPTH)	,	// 4
	parameter CNT_W      = PTR_W+1		  	  		// 5
)(
				clk				,
				nRst			,
				i_push			,
				i_pop			,
				i_wdata			,
				o_rdata			,
				o_empty			,
				o_full			,
				o_count
);
 
	//--------------------------------------------------------------------------
	// Ports
	//--------------------------------------------------------------------------
	input			clk						;	// clock
	input			nRst					;	// asynchronous reset, active-LOW
	input			i_push					;	// write request
	input			i_pop					;	// read request ("taken" stamp)
	input	[DATA_WIDTH-1:0]i_wdata			;	// data to push, valid with i_push
	output	[DATA_WIDTH-1:0]o_rdata			;	// oldest entry, valid while o_empty = 0
	output			o_empty					;	// no entries stored
	output			o_full					;	// FIFO_DEPTH entries stored
	output	[CNT_W-1:0]	o_count				;	// number of entries stored (0 ~ FIFO_DEPTH)
 
	//--------------------------------------------------------------------------
	// Internal signals
	//--------------------------------------------------------------------------
	wire			w_do_push		;	// push actually accepted
	wire			w_do_pop		;	// pop actually accepted
	reg	[CNT_W-1:0]	r_count			;	// entries stored (0 ~ FIFO_DEPTH)
	reg	[PTR_W-1:0]	r_wptr			;	// next slot to write
	reg	[PTR_W-1:0]	r_rptr			;	// slot holding the oldest entry
	reg	[DATA_WIDTH-1:0]r_mem	[0:FIFO_DEPTH-1];	// storage array
 
	//--------------------------------------------------------------------------
	// Accepted requests
	//   Pointers, count and memory are updated by these accepted requests,
	//   not by the raw i_push / i_pop.
	//--------------------------------------------------------------------------
assign w_do_push	= i_push && !(o_full)		;	// ignored when full
assign w_do_pop	= i_pop  && !(o_empty)			;	// ignored when empty
 
	//--------------------------------------------------------------------------
	// Entry count (r_count)
	//   +1 on push only, -1 on pop only, unchanged otherwise (neither or both).
	//   Width is PTR_W+1 so it can hold FIFO_DEPTH; it never wraps because
	//   o_full blocks further pushes.
	//--------------------------------------------------------------------------
always @(posedge clk or negedge nRst)begin
	if (!nRst)
		r_count <= {CNT_W{1'b0}}		;
	else if (w_do_push&&!w_do_pop)
		r_count <= r_count + 1			;
	else if (!w_do_push&&w_do_pop)
		r_count <= r_count - 1			;	
end
 
	//--------------------------------------------------------------------------
	// Status flags
	//   wptr == rptr is true both when empty and when full, so the count is
	//   what tells the two cases apart.
	//--------------------------------------------------------------------------
assign o_empty = (r_count == {CNT_W{1'b0}})		;
assign o_full  = (r_count == FIFO_DEPTH)		;
assign o_count = r_count						;
 
	//--------------------------------------------------------------------------
	// Write pointer (r_wptr)
	//   Advances only when a push is accepted. PTR_W bits wrap from the last
	//   slot back to 0 by themselves (FIFO_DEPTH must be a power of 2).
	//--------------------------------------------------------------------------
always @(posedge clk or negedge nRst)begin
	if(!nRst)
		r_wptr <= {PTR_W{1'b0}}			;
	else if	(w_do_push)
		r_wptr <= r_wptr + 1			;
end
 
	//--------------------------------------------------------------------------
	// Read pointer (r_rptr)
	//   Advances only when a pop is accepted. The slot is not erased; it is
	//   simply treated as already taken and is overwritten later.
	//--------------------------------------------------------------------------
always @(posedge clk or negedge nRst)begin
	if(!nRst)
		r_rptr <= {PTR_W{1'b0}}			;
	else if (w_do_pop)
		r_rptr <= r_rptr +1				;
end
 
	//--------------------------------------------------------------------------
	// Memory write
	//   Written only when a push is accepted (never on a raw i_push, so a full
	//   FIFO cannot overwrite unread data). No reset: a slot is read only after
	//   it has been written, and an array cannot be reset in one statement.
	//--------------------------------------------------------------------------
always @(posedge clk)begin
	if(w_do_push)
		r_mem[r_wptr] <= i_wdata		;
 
end
 
	//--------------------------------------------------------------------------
	// Memory read (combinational)
	//   Always shows the oldest entry. Valid only while o_empty = 0; while empty
	//   the value is stale (X in simulation) and must not be used.
	//--------------------------------------------------------------------------
assign o_rdata = r_mem[r_rptr]			;
 
endmodule
 