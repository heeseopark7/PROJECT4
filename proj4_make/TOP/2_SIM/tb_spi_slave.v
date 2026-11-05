//==============================================================================
// Testbench : tb_spi_slave
// Purpose   : Self-checking test of spi_slave_apb_top (SPI slave, APB slave).
//             An APB master model (tasks apb_write / apb_read, SETUP + ACCESS)
//             drives the registers, and a behavioral SPI master model (task
//             spi_byte) drives SLVSCLK / SLVMOSI / SLVCSN.
//             For every mode (CPOL, CPHA = 00 01 10 11):
//               - the reply byte written to SSDR comes out on MISO
//               - the byte sent by the master is read back from SSDR
//               - SSSR.RXNE is set after the byte and cleared by an SSDR read
//             Extra:
//               - BSY follows the chip select
//               - SLVINTR follows SSCR.SSIE & RXNE
//               - two bytes in one CS frame without a read set OVR (W1C); the
//                 second byte reuses the reply byte held in SSDR (the slave takes
//                 it right after the first byte, too soon for software to change)
//               - SSE = 0: the slave ignores the master
// Register offsets (PADDR[1:0]): 0 SSCR, 1 SSSR, 2 SSDR
// SCLK is 10x slower than PCLK (slave synchronizes the SPI pins).
// The master model sets the SCLK idle level (CPOL) before it pulls CS_N low.
//==============================================================================

`timescale 1ns / 1ps

module tb_spi_slave;

reg                 PCLK = 0                            ;
reg                 PRESETn = 0                         ;
reg                 PSEL = 0                            ;
reg                 PENABLE = 0                         ;
reg                 PWRITE = 0                          ;
reg     [9:0]       PADDR = 0                           ;
reg     [31:0]      PWDATA = 0                          ;
wire    [31:0]      PRDATA                              ;
reg                 SLVSCLK = 0                         ;
reg                 SLVMOSI = 0                         ;
wire                SLVMISO                             ;
reg                 SLVCSN = 1                          ;
wire                SLVINTR                             ;

localparam          SSCR = 0, SSSR = 1, SSDR = 2        ;
localparam          HP = 50                             ;   // SCLK half period in ns

integer             err = 0                             ;
reg     [31:0]      rd                                  ;
reg     [7:0]       m_rx                                ;

always #5 PCLK = ~PCLK;

spi_slave_apb_top dut (
                .PCLK           (PCLK        )   ,
                .PRESETn        (PRESETn     )   ,
                .PSEL           (PSEL        )   ,
                .PENABLE        (PENABLE     )   ,
                .PWRITE         (PWRITE      )   ,
                .PADDR          (PADDR       )   ,
                .PWDATA         (PWDATA      )   ,
                .PRDATA         (PRDATA      )   ,
                .SLVSCLK        (SLVSCLK     )   ,
                .SLVMOSI        (SLVMOSI     )   ,
                .SLVMISO        (SLVMISO     )   ,
                .SLVCSN         (SLVCSN      )   ,
                .SLVINTR        (SLVINTR     )
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
// SPI master model: one byte, CS_N must already be low
//   CPHA=0 : MOSI set before the leading edge, MISO sampled at leading edge,
//            MOSI changes at trailing edge
//   CPHA=1 : MOSI changes at leading edge, MISO sampled at trailing edge
//------------------------------------------------------------------------------
task spi_byte(input cpol, input cpha, input [7:0] tx, output [7:0] rx);
    integer i;
    begin
        SLVSCLK = cpol;
        if (!cpha) SLVMOSI = tx[7];
        #HP;
        for (i = 0; i < 8; i = i + 1) begin
            SLVSCLK = ~cpol;                              // leading edge
            if (cpha) SLVMOSI = tx[7-i]; else rx[7-i] = SLVMISO;
            #HP;
            SLVSCLK = cpol;                               // trailing edge
            if (cpha) rx[7-i] = SLVMISO; else if (i < 7) SLVMOSI = tx[6-i];
            #HP;
        end
    end
endtask

task cs_low;  begin SLVCSN = 0; #(HP); end endtask
task cs_high; begin SLVCSN = 1; repeat (6) @(posedge PCLK); end endtask

integer m;
reg     [7:0] txb, rpl;
initial begin
    #33 PRESETn = 1;
    repeat (2) @(posedge PCLK);

    apb_read(SSCR, rd); check("reset SSCR", rd, 32'h0);
    apb_read(SSSR, rd); check("reset SSSR", rd, 32'h0);

    for (m = 0; m < 4; m = m + 1) begin
        txb = 8'hA5 ^ m; rpl = 8'h3C ^ (m << 4);
        apb_write(SSCR, {28'd0, 1'b0, m[0], m[1], 1'b1});   // [3]SSIE [2]CPHA [1]CPOL [0]SSE
        apb_write(SSDR, {24'd0, rpl});
        SLVSCLK = m[1];                                      // master sets the idle level before CS
        repeat (6) @(posedge PCLK);
        cs_low;
        apb_read(SSSR, rd); check("BSY while CS low", rd[2], 1'b1);
        spi_byte(m[1], m[0], txb, m_rx);
        cs_high;
        check("master got reply", m_rx, rpl);
        apb_read(SSSR, rd);
        check("RXNE set", rd[0], 1'b1);
        check("OVR clear", rd[1], 1'b0);
        check("BSY clear after CS high", rd[2], 1'b0);
        apb_read(SSDR, rd);
        check("slave got byte", rd[7:0], txb);
        apb_read(SSSR, rd);
        check("RXNE cleared by SSDR read", rd[0], 1'b0);
        $display("mode CPOL=%0d CPHA=%0d done", m[1], m[0]);
    end

    // interrupt follows SSIE & RXNE
    apb_write(SSCR, 32'b1001);                       // SSIE | SSE, mode 0
    apb_write(SSDR, 32'h77);
    cs_low; spi_byte(1'b0, 1'b0, 8'h5A, m_rx); cs_high;
    check("SLVINTR after byte", SLVINTR, 1'b1);
    apb_read(SSDR, rd);
    check("SLVINTR cleared by read", SLVINTR, 1'b0);

    // two bytes in one frame without a read -> OVR; 2nd reply byte is used
    apb_write(SSCR, 32'b0001);                       // SSE, mode 0, no interrupt
    apb_write(SSDR, 32'hC1);
    cs_low;
    spi_byte(1'b0, 1'b0, 8'h11, m_rx);
    check("frame byte 1 reply", m_rx, 8'hC1);
    repeat (8) @(posedge PCLK);                      // SSDR cannot be updated in time for byte 2
    spi_byte(1'b0, 1'b0, 8'h22, m_rx);
    cs_high;
    check("frame byte 2 reuses SSDR reply", m_rx, 8'hC1);
    apb_read(SSSR, rd);
    check("OVR set (2 bytes, no read)", rd[1], 1'b1);
    check("RXNE set", rd[0], 1'b1);
    apb_read(SSDR, rd);
    check("SSDR holds newest byte", rd[7:0], 8'h22);
    apb_write(SSSR, 32'h2);                          // write 1 to clear OVR
    apb_read(SSSR, rd);
    check("OVR cleared (W1C)", rd[1], 1'b0);

    // SSE = 0: ignored
    apb_write(SSCR, 32'd0);
    apb_write(SSDR, 32'h99);
    cs_low; spi_byte(1'b0, 1'b0, 8'hEE, m_rx); cs_high;
    apb_read(SSSR, rd);
    check("no RXNE with SSE=0", rd[0], 1'b0);
    check("BSY low with SSE=0 (CS high again)", rd[2], 1'b0);

    if (err == 0) $display("PASS tb_spi_slave");
    else          $display("FAIL tb_spi_slave (%0d errors)", err);
    $finish;
end

initial begin
    #5000000;
    $display("FAIL tb_spi_slave (watchdog)");
    $finish;
end

endmodule
