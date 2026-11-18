//==============================================================================
// Module  : scinstmem
// Purpose : Instruction memory (ROM), read by the PC only (not visible in the
//           data address space). The program is part of the RTL (a constant
//           case table), so synthesis, gate-level and post-layout simulation
//           all run the same program. No HEX file and no testbench write needed.
//
// Size    : 256 words (word index = i_addr[9:2]). Words after the program are
//           0x00000000 (nop = sll $0,$0,0).
//
// Program : 1) sum 1..10                      -> RAM[0] = 0x37
//           2) UART loopback, send 'A' (0x41) -> RAM[1] = 0x41
//              (IBRD = 4, UARTCR = 0x381 : UARTEN, TXE, RXE, LBE)
//           3) SPI master <-> SPI slave, byte 0xA5 out, 0x3C back
//              (master and slave pins are wired together outside the chip)
//                                            -> RAM[2] = 0x3C  (master received)
//                                               RAM[3] = 0xA5  (slave received)
//           4) j to itself (pc stays at 0xAC)
// Registers used : t0 $8, t1 $9, t2 $10, t3 $11, t4 $12, t5 $13, t6 $14
//==============================================================================

`timescale 1ns / 1ps

module scinstmem (
                    i_addr                              ,
                    o_inst
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input   [31:0]      i_addr                              ;   // PC (byte address)
output  [31:0]      o_inst                              ;   // instruction at PC

//------------------------------------------------------------------------------
// Internal signals
//------------------------------------------------------------------------------
reg     [31:0]      r_inst                              ;   // ROM output (combinational)
wire    [7:0]       w_widx                              ;   // word index

assign  w_widx  = i_addr[9:2]                           ;
assign  o_inst  = r_inst                                ;

//------------------------------------------------------------------------------
// ROM table
//------------------------------------------------------------------------------
always @(*) begin
    case (w_widx)
        // ---- 1) sum 1..10 -> RAM[0] ------------------------------------------
        8'd0    : r_inst = 32'h2008000A ;   // 0x00 addi t0, $0, 10
        8'd1    : r_inst = 32'h20090000 ;   // 0x04 addi t1, $0, 0
        8'd2    : r_inst = 32'h01284820 ;   // 0x08 add  t1, t1, t0     (loop)
        8'd3    : r_inst = 32'h2108FFFF ;   // 0x0C addi t0, t0, -1
        8'd4    : r_inst = 32'h1500FFFD ;   // 0x10 bne  t0, $0, loop
        8'd5    : r_inst = 32'hAC090000 ;   // 0x14 sw   t1, 0($0)      RAM[0] = 0x37
        // ---- 2) UART loopback: send 0x41, read it back -> RAM[1] -------------
        8'd6    : r_inst = 32'h3C084000 ;   // 0x18 lui  t0, 0x4000     UART base
        8'd7    : r_inst = 32'h20090004 ;   // 0x1C addi t1, $0, 4
        8'd8    : r_inst = 32'hAD090024 ;   // 0x20 sw   t1, 0x24(t0)   UARTIBRD = 4
        8'd9    : r_inst = 32'h20090381 ;   // 0x24 addi t1, $0, 0x381
        8'd10   : r_inst = 32'hAD090030 ;   // 0x28 sw   t1, 0x30(t0)   UARTCR (loopback on)
        8'd11   : r_inst = 32'h8D0A0018 ;   // 0x2C lw   t2, 0x18(t0)   UARTFR      (wait)
        8'd12   : r_inst = 32'h314A0020 ;   // 0x30 andi t2, t2, 0x20   TXFF
        8'd13   : r_inst = 32'h1540FFFD ;   // 0x34 bne  t2, $0, wait   TX FIFO full
        8'd14   : r_inst = 32'h200B0041 ;   // 0x38 addi t3, $0, 0x41
        8'd15   : r_inst = 32'hAD0B0000 ;   // 0x3C sw   t3, 0(t0)      UARTDR = 'A'
        8'd16   : r_inst = 32'h8D0A0018 ;   // 0x40 lw   t2, 0x18(t0)   UARTFR      (wait)
        8'd17   : r_inst = 32'h314A0010 ;   // 0x44 andi t2, t2, 0x10   RXFE
        8'd18   : r_inst = 32'h1540FFFD ;   // 0x48 bne  t2, $0, wait   RX FIFO empty
        8'd19   : r_inst = 32'h8D0C0000 ;   // 0x4C lw   t4, 0(t0)      read UARTDR
        8'd20   : r_inst = 32'hAC0C0004 ;   // 0x50 sw   t4, 4($0)      RAM[1] = 0x41
        // ---- 3) SPI master -> slave, 0xA5 out / 0x3C back -------------------
        8'd21   : r_inst = 32'h35091000 ;   // 0x54 ori  t1, t0, 0x1000 SPI master base
        8'd22   : r_inst = 32'h350A2000 ;   // 0x58 ori  t2, t0, 0x2000 SPI slave base
        8'd23   : r_inst = 32'h200B0001 ;   // 0x5C addi t3, $0, 1
        8'd24   : r_inst = 32'hAD4B0000 ;   // 0x60 sw   t3, 0(t2)      slave SSCR = SSE
        8'd25   : r_inst = 32'h200B003C ;   // 0x64 addi t3, $0, 0x3C
        8'd26   : r_inst = 32'hAD4B0008 ;   // 0x68 sw   t3, 8(t2)      slave reply = 0x3C
        8'd27   : r_inst = 32'h200B0008 ;   // 0x6C addi t3, $0, 8
        8'd28   : r_inst = 32'hAD2B000C ;   // 0x70 sw   t3, 0xC(t1)    master SPDIV = 8
        8'd29   : r_inst = 32'h200B0009 ;   // 0x74 addi t3, $0, 9
        8'd30   : r_inst = 32'hAD2B0000 ;   // 0x78 sw   t3, 0(t1)      SPCR = SPE | CS
        8'd31   : r_inst = 32'h200B00A5 ;   // 0x7C addi t3, $0, 0xA5
        8'd32   : r_inst = 32'hAD2B0008 ;   // 0x80 sw   t3, 8(t1)      SPDR = 0xA5, start
        8'd33   : r_inst = 32'h8D2C0004 ;   // 0x84 lw   t4, 4(t1)      SPSR         (wait)
        8'd34   : r_inst = 32'h318C0002 ;   // 0x88 andi t4, t4, 2      DONE
        8'd35   : r_inst = 32'h1180FFFD ;   // 0x8C beq  t4, $0, wait
        8'd36   : r_inst = 32'h8D2D0008 ;   // 0x90 lw   t5, 8(t1)      master SPDR (= 0x3C)
        8'd37   : r_inst = 32'hAC0D0008 ;   // 0x94 sw   t5, 8($0)      RAM[2] = 0x3C
        8'd38   : r_inst = 32'h8D4C0004 ;   // 0x98 lw   t4, 4(t2)      slave status (wait)
        8'd39   : r_inst = 32'h318C0001 ;   // 0x9C andi t4, t4, 1      RX valid
        8'd40   : r_inst = 32'h1180FFFD ;   // 0xA0 beq  t4, $0, wait
        8'd41   : r_inst = 32'h8D4E0008 ;   // 0xA4 lw   t6, 8(t2)      slave data (= 0xA5)
        8'd42   : r_inst = 32'hAC0E000C ;   // 0xA8 sw   t6, 0xC($0)    RAM[3] = 0xA5
        // ---- 4) end ----------------------------------------------------------
        8'd43   : r_inst = 32'h0800002B ;   // 0xAC j    0xAC           stay here
        default : r_inst = 32'h00000000 ;   // nop
    endcase
end

endmodule
