// MCU top: single-cycle MIPS + APB bridge (peripheral slots reserved: UART removed, SPI TBD)
module mcu_top (
    input         clk,
    input         clrn,
    output [31:0] pc,
    output [31:0] inst,
    output [31:0] aluout,
    output [31:0] memout
);
    wire [31:0] data, ram_out;
    wire        wmem, stall, penable;

    // address decoder
    wire is_lw  = (inst[31:26] == 6'h23);
    wire in_apb = (aluout[31:16] == 16'h4000);
    wire req    = in_apb & (is_lw | wmem);
    // peripheral slot selects: aluout[15:12] (0 = former UART, 1 = SPI) -- none connected yet

    sccpu u_cpu (.clk(clk), .clrn(clrn), .inst(inst), .memout(memout), .stall(stall),
                 .pc(pc), .wmem(wmem), .aluout(aluout), .data(data));

    scinstmem u_imem (.a(pc), .inst(inst));

    scdatamem u_dmem (.clk(clk), .we(wmem & ~in_apb), .addr(aluout),
                      .datain(data), .dataout(ram_out));

    apb_bridge u_bridge (.clk(clk), .clrn(clrn), .req(req),
                         .psel(), .penable(penable), .stall(stall));

    // read mux: RAM / unmapped APB = 0
    assign memout = in_apb ? 32'd0 : ram_out;
endmodule
