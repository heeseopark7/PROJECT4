//==============================================================================
// Module  : scinstmem
// Purpose : Instruction memory, read by the PC only (not visible in the data
//           address space). Loaded from a HEX file at time 0 (spec OI-4).
//
// Parameters:
//   INIT_FILE : HEX file, one 32-bit word per line (path is relative to the
//               directory where the simulator is started)
//   AW        : address width in words, memory has 2^AW words
//==============================================================================

`timescale 1ns / 1ps

module scinstmem #(
    parameter       INIT_FILE   = ""                    ,   // program image ("" = nothing loaded, the testbench loads it)
    parameter       AW          = 8                         // 2^AW words
)(                  i_addr                              ,
                    o_inst
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input   [31:0]      i_addr                              ;   // PC (byte address)
output  [31:0]      o_inst                              ;   // instruction at PC

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
reg     [31:0]      r_rom [0:(1<<AW)-1]                 ;   // instruction storage
integer             i                                   ;   // init loop index

//------------------------------------------------------------------------------
// Storage: fill with nop (sll $0,$0,0), then load the program
//------------------------------------------------------------------------------
initial begin
    for (i = 0; i < (1<<AW); i = i + 1) begin
        r_rom[i]    =   32'd0           ;
    end
    if (INIT_FILE != "")  begin
        $readmemh(INIT_FILE, r_rom);
    end
end

assign  o_inst = r_rom[i_addr[AW+1:2]]  ;

endmodule
