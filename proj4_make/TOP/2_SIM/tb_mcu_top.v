//==============================================================================
// Testbench : tb_mcu_top
// Purpose   : Self-checking test of mcu_top in its default state (CPU, memories,
//             APB bridge; UART / SPI slots commented out).
//             Program (prog_mcu_top.hex):
//               1) sum 1..10 -> RAM[0]            (CPU loop, branch, add, sw)
//               2) sw to the APB region 0x4000_0000 (no slave)
//               3) lw from the APB region -> RAM[1]
//             Checks:
//               RAM[0] = 0x37   sum is right, APB store did not hit RAM word 0
//               RAM[1] = 0x00   APB read with no slave returns 0
//               stall pulses = 2, penable pulses = 2   (one per APB access)
//               penable is never high together with stall (SETUP / ACCESS)
//               penable is high for exactly 1 clock per access
// Run from this folder (hex path is relative to where the simulator starts).
//==============================================================================

`timescale 1ns / 1ps

module tb_mcu_top;

reg                 clk = 0                             ;
reg                 clrn = 0                            ;
wire    [31:0]      pc, inst, aluout, memout            ;
integer             err = 0                             ;
integer             n_stall = 0                         ;
integer             n_pen = 0                           ;
integer             pen_len = 0                         ;

always #5 clk = ~clk;

mcu_top dut (
                .clk            (clk         )   ,
                .clrn           (clrn        )   ,
                .pc             (pc          )   ,
                .inst           (inst        )   ,
                .aluout         (aluout      )   ,
                .memout         (memout      )
);

// bridge monitor
always @(posedge clk) begin
    if (clrn) begin
        if (dut.w_stall && !dut.w_penable) n_stall = n_stall + 1;
        if (dut.w_penable) begin
            pen_len = pen_len + 1;
            if (pen_len == 1) n_pen = n_pen + 1;
            if (pen_len > 1) begin $display("ERROR: PENABLE longer than 1 clock"); err = err + 1; end
            if (dut.w_stall) begin $display("ERROR: PENABLE together with stall"); err = err + 1; end
        end
        else pen_len = 0;
    end
end

task check(input [255:0] name, input [31:0] got, input [31:0] exp);
    begin
        if (got !== exp) begin
            $display("ERROR: %0s got %h exp %h", name, got, exp);
            err = err + 1;
        end
        else $display("ok   : %0s = %h", name, got);
    end
endtask

initial begin
    #1 $readmemh("prog_mcu_top.hex", dut.uut2.r_rom, 0, 12);   // after scinstmem's own init
    #32 clrn = 1;
    repeat (400) @(posedge clk);
    check("RAM[0] (sum)",        dut.uut3.r_ram[0], 32'h37);
    check("RAM[1] (APB read)",   dut.uut3.r_ram[1], 32'h00);
    check("stall pulses",        n_stall,           2);
    check("penable pulses",      n_pen,             2);
    check("final pc",            pc,                32'h30);
    if (err == 0) $display("PASS tb_mcu_top");
    else          $display("FAIL tb_mcu_top (%0d errors)", err);
    $finish;
end

endmodule
