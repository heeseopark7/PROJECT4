//==============================================================================
// Testbench : tb_mcu_top
// Purpose   : Self-checking test of mcu_top (CPU, memories, APB bridge, UART,
//             SPI master, SPI slave). The program is inside scinstmem (1_RTL),
//             so nothing is loaded here and the same TB can be reused for the
//             gate-level and post-layout runs.
//             Program (see scinstmem.v):
//               1) sum 1..10 -> RAM[0]                         (CPU loop, branch)
//               2) UART loopback, send 'A' (0x41) -> RAM[1]    (APB slot 0)
//               3) SPI master sends 0xA5 to the SPI slave, which answers 0x3C
//                  -> RAM[2] = 0x3C, RAM[3] = 0xA5             (APB slots 1, 2)
//             The SPI master and slave pins are wired together in this TB.
//             Checks on the chip pins (valid in every run):
//               UARTTXD   : one frame, 8N1, data = 0x41
//               SPI       : 8 SCLK rising edges, MOSI byte = 0xA5, MISO byte = 0x3C
//               final pc  = 0xAC  (program finished)
//             Checks on internal signals (RTL run only, "function_sim"):
//               RAM[0] = 0x37, RAM[1] = 0x41, RAM[2] = 0x3C, RAM[3] = 0xA5
//               stall pulses = penable pulses (one pair per APB access)
//               penable is never high together with stall (SETUP / ACCESS)
//               penable is high for exactly 1 clock per access
//==============================================================================

`timescale 1ns / 1ps

module tb_mcu_top;

reg                 clk = 0                             ;
reg                 clrn                                ;
wire    [31:0]      pc, inst, aluout, memout            ;
reg                 uartrxd = 1'b1                      ;   // UART RX pin idle = 1 (loopback is inside)
wire                uarttxd, uartintr                   ;
wire                spisclk, spimosi, spicsn, spiintr   ;
wire                spimiso                             ;   // slave reply, goes to the master
wire                slvmiso, slvintr                    ;
integer             err = 0                             ;
integer             n_stall = 0                         ;
integer             n_pen = 0                           ;
integer             pen_len = 0                         ;

//------------------------------------------------------------------------------
// Clock and reset
//------------------------------------------------------------------------------
parameter           CLK_PERIOD = 10                     ;   // ns
parameter           UART_BIT   = 640                    ;   // ns, 16 ticks x IBRD(4) x CLK_PERIOD

always #(CLK_PERIOD/2) clk = ~clk;

initial begin
    clrn = 1'b0;
    #33 clrn = 1'b1;                                       // release reset
end

//------------------------------------------------------------------------------
// DUT : MCU (CPU + memories + APB bridge + UART + SPI master + SPI slave)
//   SPI master pins are connected straight to the SPI slave pins.
//------------------------------------------------------------------------------
assign  spimiso = slvmiso;

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
                .SLVSCLK        (spisclk     )   ,
                .SLVMOSI        (spimosi     )   ,
                .SLVMISO        (slvmiso     )   ,
                .SLVCSN         (spicsn      )   ,
                .SLVINTR        (slvintr     )   ,
                .pc             (pc          )   ,
                .inst           (inst        )   ,
                .aluout         (aluout      )   ,
                .memout         (memout      )
);

//------------------------------------------------------------------------------
// Pin monitors (work on the chip pins only)
//------------------------------------------------------------------------------
// UART TX : wait for the start bit, sample every bit in the middle of its cell
reg     [7:0]       tx_byte = 8'h00                     ;
integer             tx_frames = 0                       ;
integer             k                                   ;

always @(negedge uarttxd) begin
    if (clrn === 1'b1) begin
        #(UART_BIT + UART_BIT/2);                          // middle of D0
        for (k = 0; k < 8; k = k + 1) begin
            tx_byte[k] = uarttxd;
            #(UART_BIT);
        end
        if (uarttxd !== 1'b1) begin $display("ERROR: UARTTXD stop bit is not 1"); err = err + 1; end
        tx_frames = tx_frames + 1;
    end
end

// SPI : mode 0, the master and the slave sample on the rising edge of SCLK
reg     [7:0]       mosi_sh = 8'h00, miso_sh = 8'h00    ;
reg     [7:0]       mosi_byte = 8'h00, miso_byte = 8'h00;
integer             sclk_rise = 0                       ;

always @(posedge spisclk) begin
    if (spicsn === 1'b0) begin
        mosi_sh   = {mosi_sh[6:0], spimosi};
        miso_sh   = {miso_sh[6:0], spimiso};
        sclk_rise = sclk_rise + 1;
        if (sclk_rise == 8) begin                          // 8th edge: the byte is complete
            mosi_byte = mosi_sh;
            miso_byte = miso_sh;
        end
    end
end

`ifdef function_sim
// APB bridge monitor (internal signals, RTL run only)
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
`endif

task check(input [255:0] name, input [31:0] got, input [31:0] exp);
    begin
        if (got !== exp) begin
            $display("ERROR: %0s got %h exp %h", name, got, exp);
            err = err + 1;
        end
        else $display("ok   : %0s = %h", name, got);
    end
endtask

//------------------------------------------------------------------------------
// Run until the program reaches its end loop (pc = 0xAC), then check
//------------------------------------------------------------------------------
integer             cyc = 0                             ;

initial begin
    wait (clrn === 1'b1);
    while (pc !== 32'hAC && cyc < 20000) begin
        @(posedge clk);
        cyc = cyc + 1;
    end
    repeat (20) @(posedge clk);                            // let the last store settle
    if (cyc >= 20000) begin $display("ERROR: timeout, pc = %h", pc); err = err + 1; end

`ifdef function_sim
    check("RAM[0] (sum)",        u_mcu_top.uut3.r_ram[0], 32'h37);
    check("RAM[1] (UART echo)",  u_mcu_top.uut3.r_ram[1], 32'h41);
    check("RAM[2] (SPI master)", u_mcu_top.uut3.r_ram[2], 32'h3C);
    check("RAM[3] (SPI slave)",  u_mcu_top.uut3.r_ram[3], 32'hA5);
    check("stall = penable",     (n_stall == n_pen) && (n_pen != 0), 1);
    $display("info : APB accesses = %0d", n_pen);
`endif
    check("UARTTXD frames",      tx_frames,         1);
    check("UARTTXD data",        tx_byte,           32'h41);
    check("SCLK rising edges",   sclk_rise,         8);
    check("MOSI byte (master)",  mosi_byte,         32'hA5);
    check("MISO byte (slave)",   miso_byte,         32'h3C);
    check("final pc",            pc,                32'hAC);
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
