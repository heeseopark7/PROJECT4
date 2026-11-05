`timescale 1ns/1ps
// mcu_top + SPI 시스템 시뮬레이션. +HEX=<file> +EXP=<hex RAM[1] 기대값> [+EXP2=<hex RAM[2]>] [+NOSLAVE_CSN]
module tb_mcu_spi;
    reg clk = 0, clrn = 0;
    wire [31:0] pc, inst, aluout, memout;
    wire SCLK, MOSI, CSN, INTR, MISO, UTX, UINT;
    always #10 clk = ~clk;

    mcu_top dut (.clk(clk), .clrn(clrn), .UARTRXD(1'b1), .UARTTXD(UTX), .UARTINTR(UINT),
                 .SPISCLK(SCLK), .SPIMOSI(MOSI), .SPIMISO(MISO), .SPICSN(CSN), .SPIINTR(INTR),
                 .pc(pc), .inst(inst), .aluout(aluout), .memout(memout));

    wire [7:0] s_rx; wire s_valid; reg [7:0] echo = 0;
    always @(posedge clk) if (s_valid) echo <= s_rx;
    spi_slave slv (.clk(clk), .rst_n(clrn), .cpol(1'b0), .cpha(1'b0), .sclk(SCLK), .cs_n(CSN),
                   .mosi(MOSI), .miso(MISO), .tx_data(echo), .rx_data(s_rx), .rx_valid(s_valid));

    reg [1023:0] hex; integer exp1, exp2, have2, csn_low_seen = 0, sclk_toggles = 0;
    always @(negedge CSN) csn_low_seen = csn_low_seen + 1;
    always @(SCLK) sclk_toggles = sclk_toggles + 1;

    initial begin
        if (!$value$plusargs("HEX=%s", hex)) hex = "prog_spi.hex";
        if (!$value$plusargs("EXP=%h", exp1)) exp1 = 32'hA5;
        have2 = $value$plusargs("EXP2=%h", exp2);
        $readmemh(hex, dut.uut2.r_rom);
        #55 clrn = 1;
        repeat (3000) @(posedge clk);
        $display("HEX=%0s RAM[1]=%h RAM[2]=%h CSN=%b csn_falls=%0d sclk_toggles=%0d pc=%h",
                 hex, dut.uut3.r_ram[1], dut.uut3.r_ram[2], CSN, csn_low_seen, sclk_toggles, pc);
        if (dut.uut3.r_ram[1] === exp1 && (!have2 || dut.uut3.r_ram[2] === exp2)) $display("PASS");
        else $display("FAIL");
        $finish;
    end
endmodule
