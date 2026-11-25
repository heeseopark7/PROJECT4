`timescale 1ns / 1ps

module rx_fifo #(
        parameter   FIFO_DEPTH =    16      
)(
                    clk             ,
                    nRst            , 
                    i_push          ,
                    i_pop           ,
                    i_wdata         ,
                    o_rdata         ,
                    o_empty         ,
                    o_full          ,
                    o_count         
);

localparam                      DATA_WIDTH  =   11                      ;
localparam                      CNT_W       =   $clog2(FIFO_DEPTH) + 1  ;

input                           clk             ;
input                           nRst            ;
input                           i_push          ;
input                           i_pop           ;
input       [DATA_WIDTH-1:0]    i_wdata         ;
output      [DATA_WIDTH-1:0]    o_rdata         ;
output                          o_empty         ;
output                          o_full          ;
output      [CNT_W-1:0]         o_count         ;

tx_fifo #(
        .DATA_WIDTH ( DATA_WIDTH ),
        .FIFO_DEPTH ( FIFO_DEPTH )
) dut   (
                .clk			(clk    ),
		.nRst			(nRst   ),
		.i_push			(i_push ),
		.i_pop			(i_pop  ),
		.i_wdata		(i_wdata),
		.o_rdata		(o_rdata),
		.o_empty		(o_empty),
		.o_full			(o_full ),
		.o_count                (o_count)
);

endmodule