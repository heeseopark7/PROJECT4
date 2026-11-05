//==============================================================================
// Testbench : tb_mcu_spi_loop
// Purpose   : SPI master and SPI slave inside one MCU, wired together outside.
//             The CPU program (prog_spi_loop.hex) does:
//               slave : SSCR = SSE, SSDR = 0x3C (reply)
//               master: SPDIV = 8, SPCR = SPE|CS, SPDR = 0xA5, wait DONE
//             Expected result:
//               RAM[1] = 0x3C  (master received the slave reply)
//               RAM[2] = 0xA5  (slave received the master byte)
//
// Needs mcu_top with the [SPI] and [SLV] lines un-commented and the [UART]
// lines left commented (the UART is not connected here).
// Run from this folder:  vvp ... +HEX=prog_spi_loop.hex
//==============================================================================

`timescale 1ns / 1ps

module tb_mcu_spi_loop;

reg                 clk = 0                             ;
reg                 clrn = 0                            ;
wire    [31:0]      pc, inst, aluout, memout            ;
wire                SCLK, MOSI, MISO, CSN, SPIINTR      ;
wire                SLVINTR                             ;
reg     [1023:0]    hex                                 ;

always #10 clk = ~clk;

mcu_top dut (
                .clk            (clk         )   ,
                .clrn           (clrn        )   ,
                .SPISCLK        (SCLK        )   ,
                .SPIMOSI        (MOSI        )   ,
                .SPIMISO        (MISO        )   ,
                .SPICSN         (CSN         )   ,
                .SPIINTR        (SPIINTR     )   ,
                .SLVSCLK        (SCLK        )   ,
                .SLVMOSI        (MOSI        )   ,
                .SLVMISO        (MISO        )   ,
                .SLVCSN         (CSN         )   ,
                .SLVINTR        (SLVINTR     )   ,
                .pc             (pc          )   ,
                .inst           (inst        )   ,
                .aluout         (aluout      )   ,
                .memout         (memout      )
);

initial begin
    if (!$value$plusargs("HEX=%s", hex)) hex = "prog_spi_loop.hex";
    $readmemh(hex, dut.uut2.r_rom);
    #55 clrn = 1;
    repeat (4000) @(posedge clk);
    $display("RAM[1]=%h (exp 3c)  RAM[2]=%h (exp a5)  pc=%h", dut.uut3.r_ram[1], dut.uut3.r_ram[2], pc);
    if (dut.uut3.r_ram[1] === 32'h3C && dut.uut3.r_ram[2] === 32'hA5) $display("PASS");
    else                                                              $display("FAIL");
    $finish;
end

endmodule
