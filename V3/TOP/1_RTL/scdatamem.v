//==============================================================================
// Module  : scdatamem
// Purpose : Data RAM, 32 words (0x0000_0000 ~ 0x0000_007F).
//           Asynchronous read, synchronous write. Only addr[6:2] is used, so
//           the caller must block writes that are not for this RAM
//           (APB-region stores).
//==============================================================================

`timescale 1ns / 1ps

module scdatamem (
                    clk                                 ,
                    i_we                                ,
                    i_addr                              ,
                    i_wdata                             ,
                    o_rdata
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input               clk                                 ;   // clock
input               i_we                                ;   // write enable
input   [31:0]      i_addr                              ;   // byte address (word aligned)
input   [31:0]      i_wdata                             ;   // write data
output  [31:0]      o_rdata                             ;   // read data (async)

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
reg     [31:0]      r_ram [0:31]                        ;   // 32 x 32-bit storage
integer             i                                   ;   // init loop index

//------------------------------------------------------------------------------
// Storage (cleared at time 0 for simulation)
//------------------------------------------------------------------------------
initial begin
    for (i = 0; i < 32; i = i + 1)  begin
        r_ram[i]    =   32'd0           ;
    end
end

assign  o_rdata = r_ram[i_addr[6:2]]  ;

always @(posedge clk) begin
    if (i_we)   begin
        r_ram[i_addr[6:2]]  <=  i_wdata ;
    end
end

endmodule
