// 16-deep synchronous FIFO, async read (front value visible before pop)
module uart_fifo #(parameter W = 8) (
    input          clk,
    input          rstn,
    input          push,
    input          pop,
    input  [W-1:0] din,
    output [W-1:0] dout,
    output         empty,
    output         full
);
    reg [W-1:0] mem [0:15];
    reg [3:0] wp, rp;
    reg [4:0] cnt;
    assign empty = (cnt == 0);
    assign full  = (cnt == 16);
    assign dout  = mem[rp];
    wire do_push = push & ~full;
    wire do_pop  = pop  & ~empty;
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin wp <= 0; rp <= 0; cnt <= 0; end
        else begin
            if (do_push) begin mem[wp] <= din; wp <= wp + 1; end
            if (do_pop)  rp <= rp + 1;
            cnt <= cnt + do_push - do_pop;
        end
    end
endmodule
