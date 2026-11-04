// 16x oversampling tick: one tick every IBRD clocks (baud = PCLK / (16*IBRD)); IBRD=0 -> no tick
module uart_baud (
    input         clk,
    input         rstn,
    input  [15:0] ibrd,
    output        tick
);
    reg [15:0] c;
    wire last = (c >= ibrd - 16'd1);
    assign tick = (ibrd != 0) & last;
    always @(posedge clk or negedge rstn)
        if (!rstn)      c <= 16'd0;
        else if (tick || ibrd == 0) c <= 16'd0;
        else            c <= c + 16'd1;
endmodule
