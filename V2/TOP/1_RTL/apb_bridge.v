//==============================================================================
// Module  : apb_bridge
// Purpose : Turns a CPU load/store to the APB region into an APB transfer.
//           Each transfer takes 2 clocks: SETUP then ACCESS.
//             SETUP  : PSEL=1, PENABLE=0, stall=1 (CPU is held, address/data settle)
//             ACCESS : PSEL=1, PENABLE=1, stall=0 (slave acts, CPU takes read data)
//           PENABLE is high for exactly one clock per transfer.
//           PREADY is assumed to be always 1 (spec OI-10).
//==============================================================================

`timescale 1ns / 1ps

module apb_bridge (
                    clk                                 ,
                    nRst                                ,
                    i_req                               ,
                    o_psel                              ,
                    o_penable                           ,
                    o_stall
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input               clk                                 ;   // clock
input               nRst                                ;   // reset, active-LOW, async assert
input               i_req                               ;   // CPU is doing lw/sw to the APB region
output              o_psel                              ;   // APB select (before slot decode)
output              o_penable                           ;   // APB enable (ACCESS phase)
output              o_stall                             ;   // hold the CPU during SETUP

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
reg                 r_access                            ;   // 1 = ACCESS phase, 0 = SETUP / idle

//------------------------------------------------------------------------------
// Phase register
//   i_req and not in ACCESS -> this clock is SETUP, next clock is ACCESS
//   otherwise               -> back to idle (SETUP of the next transfer follows)
//------------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
    if (!nRst)  begin
        r_access    <=  1'b0            ;
    end
    else if (i_req && !r_access)    begin
        r_access    <=  1'b1            ;
    end
    else    begin
        r_access    <=  1'b0            ;
    end
end

assign  o_psel    = i_req                 ;
assign  o_penable = i_req &  r_access     ;
assign  o_stall   = i_req & ~r_access     ;

endmodule
