// MCU top: single-cycle MIPS + APB bridge + Extended UART + SPI master (0x4000_1000)
module mcu_top (
    input         clk,
    input         clrn,
    input         UARTRXD,
    output        UARTTXD,
    output        UARTINTR,
    output        SPISCLK,
    output        SPIMOSI,
    input         SPIMISO,
    output        SPICSN,
    output        SPIINTR,
    output [31:0] pc,
    output [31:0] inst,
    output [31:0] aluout,
    output [31:0] memout
);
    wire [31:0] data, ram_out, prdata, prdata_spi;
    wire        wmem, stall, penable;

    // address decoder
    wire is_lw     = (inst[31:26] == 6'h23);
    wire in_apb    = (aluout[31:16] == 16'h4000);
    wire req       = in_apb & (is_lw | wmem);
    wire psel_uart = req & (aluout[15:12] == 4'h0);
    wire psel_spi  = req & (aluout[15:12] == 4'h1);

    sccpu u_cpu (.clk(clk), .clrn(clrn), .inst(inst), .memout(memout), .stall(stall),
                 .pc(pc), .wmem(wmem), .aluout(aluout), .data(data));

    scinstmem u_imem (.a(pc), .inst(inst));

    scdatamem u_dmem (.clk(clk), .we(wmem & ~in_apb), .addr(aluout),
                      .datain(data), .dataout(ram_out));

    apb_bridge u_bridge (.clk(clk), .clrn(clrn), .req(req),
                         .psel(), .penable(penable), .stall(stall));

    uart_ex_top u_uart (
        .PCLK(clk), .PRESETn(clrn),
        .PSEL(psel_uart), .PENABLE(penable), .PWRITE(wmem),
        .PADDR(aluout[11:2]), .PWDATA(data), .PRDATA(prdata),
        .PREADY(), .PSLVERR(),
        .UARTRXD(UARTRXD), .UARTTXD(UARTTXD),
        .UARTRXINTR(), .UARTTXINTR(), .UARTRTINTR(), .UARTEINTR(),
        .UARTINTR(UARTINTR));

    spi_apb_top u_spi (
        .PCLK(clk), .PRESETn(clrn),
        .PSEL(psel_spi), .PENABLE(penable), .PWRITE(wmem),
        .PADDR(aluout[11:2]), .PWDATA(data), .PRDATA(prdata_spi),
        .SPISCLK(SPISCLK), .SPIMOSI(SPIMOSI), .SPIMISO(SPIMISO),
        .SPICSN(SPICSN), .SPIINTR(SPIINTR));

    // read mux: RAM / UART / SPI / unmapped APB = 0
    assign memout = in_apb ? (psel_uart ? prdata : psel_spi ? prdata_spi : 32'd0) : ram_out;
endmodule
