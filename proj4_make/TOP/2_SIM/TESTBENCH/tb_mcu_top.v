//==============================================================================
// Testbench : tb_mcu_top
// Purpose   : Self-checking test of mcu_top (CPU, memories, APB bridge, UART,
//             SPI master, SPI slave). The peripheral pins are tied to their idle
//             levels here; the program only touches APB slot 0 (UART base).
//             Program (written into the instruction memory below, no hex file):
//               1) sum 1..10 -> RAM[0]            (CPU loop, branch, add, sw)
//               2) sw to the APB region 0x4000_0000 (UARTDR; UART is disabled, so nothing is sent)
//               3) lw from the APB region -> RAM[1] (UARTDR, RX FIFO empty reads 0)
//             Checks:
//               RAM[0] = 0x37   sum is right, APB store did not hit RAM word 0
//               RAM[1] = 0x00   UARTDR read with an empty RX FIFO returns 0
//               stall pulses = 2, penable pulses = 2   (one per APB access)
//               penable is never high together with stall (SETUP / ACCESS)
//               penable is high for exactly 1 clock per access
//==============================================================================

`timescale 1ns / 1ps

module tb_mcu_top;

reg                 clk = 0                             ;
reg                 clrn                                ;
wire    [31:0]      pc, inst, aluout, memout            ;
reg                 uartrxd = 1'b1                      ;   // UART RX idle = 1
reg                 spimiso = 1'b0                      ;   // SPI master MISO
reg                 slvsclk = 1'b0                      ;   // SPI slave pins, idle
reg                 slvmosi = 1'b0                      ;
reg                 slvcsn  = 1'b1                      ;   // not selected
wire                uarttxd, uartintr                   ;
wire                spisclk, spimosi, spicsn, spiintr   ;
wire                slvmiso, slvintr                    ;
integer             err = 0                             ;
integer             n_stall = 0                         ;
integer             n_pen = 0                           ;
integer             pen_len = 0                         ;

//------------------------------------------------------------------------------
// Clock and reset
//------------------------------------------------------------------------------
parameter           CLK_PERIOD = 10                     ;   // ns

always #(CLK_PERIOD/2) clk = ~clk;

initial begin
    clrn = 1'b0;
    #33 clrn = 1'b1;                                       // release reset
end

//------------------------------------------------------------------------------
// DUT : MCU (CPU + memories + APB bridge)
//------------------------------------------------------------------------------
mcu_top u_mcu_top (
                .clk            (clk         )   ,
                .clrn           (clrn        )   ,
                .UARTRXD        (uartrxd     )   ,
                .UARTTXD        (uarttxd     )   ,
                .UARTINTR       (uartintr    )   ,
                .SPISCLK        (spisclk     )   ,
                .SPIMOSI        (spimosi     )   ,
                .SPIMISO        (spimiso     )   ,
                .SPICSN         (spicsn      )   ,
                .SPIINTR        (spiintr     )   ,
                .SLVSCLK        (slvsclk     )   ,
                .SLVMOSI        (slvmosi     )   ,
                .SLVMISO        (slvmiso     )   ,
                .SLVCSN         (slvcsn      )   ,
                .SLVINTR        (slvintr     )   ,
                .pc             (pc          )   ,
                .inst           (inst        )   ,
                .aluout         (aluout      )   ,
                .memout         (memout      )
);

// bridge monitor
always @(posedge clk) begin
    if (clrn) begin
        if (u_mcu_top.w_stall && !u_mcu_top.w_penable) n_stall = n_stall + 1;
        if (u_mcu_top.w_penable) begin
            pen_len = pen_len + 1;
            if (pen_len == 1) n_pen = n_pen + 1;
            if (pen_len > 1) begin $display("ERROR: PENABLE longer than 1 clock"); err = err + 1; end
            if (u_mcu_top.w_stall) begin $display("ERROR: PENABLE together with stall"); err = err + 1; end
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
    #1;                                              // after scinstmem's own init
    u_mcu_top.uut2.r_rom[0] = 32'h2008000A;
    u_mcu_top.uut2.r_rom[1] = 32'h20090000;
    u_mcu_top.uut2.r_rom[2] = 32'h01284820;
    u_mcu_top.uut2.r_rom[3] = 32'h2108FFFF;
    u_mcu_top.uut2.r_rom[4] = 32'h1500FFFD;
    u_mcu_top.uut2.r_rom[5] = 32'hAC090000;
    u_mcu_top.uut2.r_rom[6] = 32'h3C084000;
    u_mcu_top.uut2.r_rom[7] = 32'h200A0055;
    u_mcu_top.uut2.r_rom[8] = 32'hAD0A0000;
    u_mcu_top.uut2.r_rom[9] = 32'h200B0077;
    u_mcu_top.uut2.r_rom[10] = 32'h8D0B0000;
    u_mcu_top.uut2.r_rom[11] = 32'hAC0B0004;
    u_mcu_top.uut2.r_rom[12] = 32'h0800000C;
    wait (clrn === 1'b1);
    repeat (400) @(posedge clk);
    check("RAM[0] (sum)",        u_mcu_top.uut3.r_ram[0], 32'h37);
    check("RAM[1] (APB read)",   u_mcu_top.uut3.r_ram[1], 32'h00);
    check("stall pulses",        n_stall,           2);
    check("penable pulses",      n_pen,             2);
    check("final pc",            pc,                32'h30);
    if (err == 0) $display("PASS tb_mcu_top");
    else          $display("FAIL tb_mcu_top (%0d errors)", err);
    $finish;
end

//------------------------------------------------------------------------------
// Misc : time format, waveform dump, SDF annotation
//   Same compile switches as the lab testbench (run with xrun):
//     function_sim : RTL simulation, dump all signals to ./dump
//     sdf_gate     : gate-level netlist after synthesis, max delays
//     sdf_post_wst : post-layout netlist, worst-case (max) delays
//     sdf_post_bst : post-layout netlist, best-case (min) delays
//   The SDF file names below are placeholders: use the names written by the
//   3_SYN / 5_PNR steps.
//------------------------------------------------------------------------------
initial    $timeformat(-9, 0, " ns", 0);

initial begin
`ifdef function_sim
    $shm_open("./dump/tb_mcu_top");
    $shm_probe(tb_mcu_top, "AC");
`endif

`ifdef sdf_gate
    $sdf_annotate("./mcu_top_delays.sdf", tb_mcu_top.u_mcu_top);
    $shm_open("./dump/tb_mcu_top_sdf_gate");
    $shm_probe(tb_mcu_top, "AC");
`endif

`ifdef sdf_post_wst
    $sdf_annotate("./mcu_top_post_wst.sdf", tb_mcu_top.u_mcu_top);
    $shm_open("./dump/tb_mcu_top_sdf_post_wst");
    $shm_probe(tb_mcu_top, "AC");
`endif

`ifdef sdf_post_bst
    $sdf_annotate("./mcu_top_post_bst.sdf", tb_mcu_top.u_mcu_top);
    $shm_open("./dump/tb_mcu_top_sdf_post_bst");
    $shm_probe(tb_mcu_top, "AC");
`endif
end

endmodule
