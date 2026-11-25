//==============================================================================
// Testbench : tb_spi_master
// Purpose   : Self-checking test of spi_apb_top (SPI master, APB slave).
//             An APB master model (tasks apb_write / apb_read, SETUP + ACCESS)
//             drives the registers. For every mode (CPOL, CPHA = 00 01 10 11):
//               - SCLK idles at CPOL, CS_N is low during the byte
//               - SCLK makes exactly 16 edges
//               - the bits seen on MOSI at the sampling edges equal the byte sent
//               - loopback (SPCR.LOOP) returns the same byte in SPDR
//               - DONE is set when finished and cleared by an SPDR read
//               - SPIINTR follows SPCR.SPIE & DONE
//             Extra: an SPDR write while busy sets WCOL (write-1-to-clear),
//             an SPDR write with SPE = 0 does not start a transfer.
// Register offsets (PADDR[1:0]): 0 SPCR, 1 SPSR, 2 SPDR, 3 SPDIV
//==============================================================================

`timescale 1ns / 1ps

module tb_spi_master;

reg                 PCLK = 0                            ;
reg                 PRESETn                             ;
reg                 PSEL = 0                            ;
reg                 PENABLE = 0                         ;
reg                 PWRITE = 0                          ;
reg     [9:0]       PADDR = 0                           ;
reg     [31:0]      PWDATA = 0                          ;
wire    [31:0]      PRDATA                              ;
wire                SPISCLK, SPIMOSI, SPICSN, SPIINTR   ;
reg                 SPIMISO = 0                         ;

localparam          SPCR = 0, SPSR = 1, SPDR = 2, SPDIV = 3 ;

integer             err = 0                             ;
reg     [31:0]      rd                                  ;

//------------------------------------------------------------------------------
// Clock and reset
//------------------------------------------------------------------------------
parameter           CLK_PERIOD = 10                     ;   // ns

always #(CLK_PERIOD/2) PCLK = ~PCLK;

initial begin
    PRESETn = 1'b0;
    #33 PRESETn = 1'b1;                                       // release reset
end

//------------------------------------------------------------------------------
// DUT : SPI master (APB slave)
//------------------------------------------------------------------------------
spi_apb_top u_dut (
                .PCLK           (PCLK        )   ,
                .PRESETn        (PRESETn     )   ,
                .PSEL           (PSEL        )   ,
                .PENABLE        (PENABLE     )   ,
                .PWRITE         (PWRITE      )   ,
                .PADDR          (PADDR       )   ,
                .PWDATA         (PWDATA      )   ,
                .PRDATA         (PRDATA      )   ,
                .SPISCLK        (SPISCLK     )   ,
                .SPIMOSI        (SPIMOSI     )   ,
                .SPIMISO        (SPIMISO     )   ,
                .SPICSN         (SPICSN      )   ,
                .SPIINTR        (SPIINTR     )
);

//------------------------------------------------------------------------------
// APB master model: SETUP clock, then ACCESS clock
//------------------------------------------------------------------------------
task apb_write(input [1:0] a, input [31:0] d);
    begin
        @(posedge PCLK); #1 PSEL = 1; PENABLE = 0; PWRITE = 1; PADDR = a; PWDATA = d;
        @(posedge PCLK); #1 PENABLE = 1;
        @(posedge PCLK); #1 PSEL = 0; PENABLE = 0; PWRITE = 0;
    end
endtask

task apb_read(input [1:0] a, output [31:0] d);
    begin
        @(posedge PCLK); #1 PSEL = 1; PENABLE = 0; PWRITE = 0; PADDR = a;
        @(posedge PCLK); #1 PENABLE = 1;
        #2 d = PRDATA;                         // valid in the ACCESS clock
        @(posedge PCLK); #1 PSEL = 0; PENABLE = 0;
    end
endtask

task check(input [255:0] name, input [31:0] got, input [31:0] exp);
    begin
        if (got !== exp) begin
            $display("ERROR: %0s got %h exp %h", name, got, exp);
            err = err + 1;
        end
    end
endtask

//------------------------------------------------------------------------------
// SCLK / MOSI monitor: counts edges and rebuilds the byte at sampling edges
//   edge index even = leading, odd = trailing; sample at leading if CPHA=0,
//   at trailing if CPHA=1
//------------------------------------------------------------------------------
reg                 mon_cpol = 0, mon_cpha = 0          ;
integer             edges = 0                           ;
reg     [7:0]       mon_byte = 0                        ;
reg                 mon_run = 0                         ;

always @(SPISCLK) begin
    if (mon_run) begin
        if ((edges % 2) == (mon_cpha ? 1 : 0)) mon_byte = {mon_byte[6:0], SPIMOSI};
        edges = edges + 1;
    end
end

//------------------------------------------------------------------------------
// One full transfer in a given mode; loopback on
//------------------------------------------------------------------------------
task xfer(input cpol, input cpha, input [7:0] tx);
    integer to;
    begin
        mon_cpol = cpol; mon_cpha = cpha; edges = 0; mon_byte = 0;
        // SPE | CPOL | CPHA | CS | LOOP
        apb_write(SPCR, {27'd0, 1'b1, 1'b1, cpha, cpol, 1'b1});
        repeat (3) @(posedge PCLK);
        check("SCLK idle level", SPISCLK, cpol);
        check("CS_N low", SPICSN, 1'b0);
        mon_run = 1;
        apb_write(SPDR, {24'd0, tx});
        to = 0; rd = 0;
        while (!rd[1] && to < 400) begin apb_read(SPSR, rd); to = to + 1; end
        mon_run = 0;
        if (to >= 400) begin $display("ERROR: timeout waiting for DONE"); err = err + 1; end
        check("SPSR.DONE", rd[1], 1'b1);
        check("SPSR.BUSY", rd[0], 1'b0);
        check("SCLK edges", edges, 16);
        check("MOSI byte", mon_byte, tx);
        check("SCLK idle after", SPISCLK, cpol);
        apb_read(SPDR, rd);
        check("loopback RX byte", rd[7:0], tx);
        apb_read(SPSR, rd);
        check("DONE cleared by SPDR read", rd[1], 1'b0);
        apb_write(SPCR, 32'd0);                // deselect (CS_N high)
        repeat (2) @(posedge PCLK);
        check("CS_N high", SPICSN, 1'b1);
    end
endtask

integer m;
initial begin
    wait (PRESETn === 1'b1);
    repeat (2) @(posedge PCLK);

    // reset values
    apb_read(SPCR, rd);  check("reset SPCR",  rd, 32'h00);
    apb_read(SPDIV, rd); check("reset SPDIV", rd, 32'd25);
    check("reset CS_N high", SPICSN, 1'b1);

    apb_write(SPDIV, 32'd8);                   // fastest (effective min 8)
    for (m = 0; m < 4; m = m + 1) begin
        xfer(m[1], m[0], 8'hA5);
        xfer(m[1], m[0], 8'h3C);
        $display("mode CPOL=%0d CPHA=%0d done", m[1], m[0]);
    end

    // interrupt: SPIE & DONE, cleared by SPDR read
    apb_write(SPCR, 32'b11_1001);               // SPIE | LOOP | CS | SPE
    apb_write(SPDR, 32'h5A);
    repeat (400) @(posedge PCLK);
    check("SPIINTR after DONE", SPIINTR, 1'b1);
    apb_read(SPDR, rd);
    check("SPIINTR cleared by read", SPIINTR, 1'b0);

    // WCOL: write SPDR while busy
    apb_write(SPCR, 32'b01_1001);               // LOOP | CS | SPE
    apb_write(SPDR, 32'h11);
    apb_write(SPDR, 32'h22);
    apb_read(SPSR, rd);
    check("WCOL set", rd[2], 1'b1);
    repeat (400) @(posedge PCLK);
    apb_write(SPSR, 32'h4);                     // write 1 to clear WCOL
    apb_read(SPSR, rd);
    check("WCOL cleared (W1C)", rd[2], 1'b0);
    apb_read(SPDR, rd);
    check("first byte survives WCOL", rd[7:0], 8'h11);

    // SPE = 0: no transfer
    apb_write(SPCR, 32'd0);
    edges = 0; mon_run = 1;
    apb_write(SPDR, 32'hFF);
    repeat (100) @(posedge PCLK);
    mon_run = 0;
    check("no SCLK edges with SPE=0", edges, 0);

    if (err == 0) $display("PASS tb_spi_master");
    else          $display("FAIL tb_spi_master (%0d errors)", err);
    $finish;
end

initial begin
    #5000000;
    $display("FAIL tb_spi_master (watchdog)");
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
    $shm_open("./dump/tb_spi_master");
    $shm_probe(tb_spi_master, "AC");
`endif

`ifdef sdf_gate
    $sdf_annotate("./spi_apb_top_delays.sdf", tb_spi_master.u_dut);
    $shm_open("./dump/tb_spi_master_sdf_gate");
    $shm_probe(tb_spi_master, "AC");
`endif

`ifdef sdf_post_wst
    $sdf_annotate("./spi_apb_top_post_wst.sdf", tb_spi_master.u_dut);
    $shm_open("./dump/tb_spi_master_sdf_post_wst");
    $shm_probe(tb_spi_master, "AC");
`endif

`ifdef sdf_post_bst
    $sdf_annotate("./spi_apb_top_post_bst.sdf", tb_spi_master.u_dut);
    $shm_open("./dump/tb_spi_master_sdf_post_bst");
    $shm_probe(tb_spi_master, "AC");
`endif
end

endmodule
