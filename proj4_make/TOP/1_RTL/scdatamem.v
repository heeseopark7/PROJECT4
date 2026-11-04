// Data RAM: 32 words (0x0000_0000 ~ 0x0000_007F), async read, sync write (OI-3)
module scdatamem (
    input         clk,
    input         we,
    input  [31:0] addr,
    input  [31:0] datain,
    output [31:0] dataout
);
    reg [31:0] ram [0:31];
    integer i;
    initial for (i = 0; i < 32; i = i + 1) ram[i] = 32'd0;
    assign dataout = ram[addr[6:2]];
    always @(posedge clk) if (we) ram[addr[6:2]] <= datain;
endmodule
