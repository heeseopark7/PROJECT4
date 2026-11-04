// Instruction memory (read by PC only). Program loaded from HEX file (OI-4).
module scinstmem #(
    parameter INIT_FILE = "prog.hex",
    parameter AW = 8                     // 2^AW words
) (
    input  [31:0] a,
    output [31:0] inst
);
    reg [31:0] rom [0:(1<<AW)-1];
    integer i;
    initial begin
        for (i = 0; i < (1<<AW); i = i + 1) rom[i] = 32'd0;   // nop (sll $0,$0,0)
        $readmemh(INIT_FILE, rom);
    end
    assign inst = rom[a[AW+1:2]];
endmodule
