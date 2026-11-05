`timescale 1ns / 1ps 

module baud_gen (
		clk			,
		nRst		,
		i_ibrd		,
		o_tick_16x
);

input			clk			;
input			nRst		;
input	[15:0]	i_ibrd		;
output			o_tick_16x	;

reg		[15:0]	r_count		;

always @( posedge clk or negedge nRst )begin
	if	(!nRst) 
		r_count <= 16'd0			;
	else if	(i_ibrd == 16'd0) 
		r_count <= 16'd0			;
	else if (r_count >= i_ibrd-16'd1) 
		r_count <= 16'd0			;
	else		
		r_count <= r_count + 16'd1	; 	 
end		

assign o_tick_16x = (i_ibrd != 16'd0)&&(r_count == i_ibrd-16'd1)	;

endmodule
