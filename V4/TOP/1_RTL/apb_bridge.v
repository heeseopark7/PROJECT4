//==============================================================================
// Module  : apb_bridge
// Purpose : Turns a CPU load/store to the APB region into an APB transfer.
//           [V4] Each transfer takes 3 clocks: DECODE, SETUP, ACCESS.
//             DECODE : PSEL=0, PENABLE=0, stall=1 (mcu_top registers the decode
//                      result, address, write data and write flag: o_capture)
//             SETUP  : PSEL=1, PENABLE=0, stall=1 (registered address/data settle)
//             ACCESS : PSEL=1, PENABLE=1, stall=0 (slave acts, CPU takes read data)
//           PSEL / PENABLE come straight from the state register, so the
//           ALU -> address decode -> slave combinational path is cut here.
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
                    o_stall                             ,
                    o_capture
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input               clk                                 ;   // clock
input               nRst                                ;   // reset, active-LOW, async assert
input               i_req                               ;   // CPU is doing lw/sw to the APB region
output              o_psel                              ;   // APB select (before slot decode), SETUP and ACCESS
output              o_penable                           ;   // APB enable (ACCESS phase)
output              o_stall                             ;   // hold the CPU during DECODE and SETUP
output              o_capture                           ;   // [V4] register the decode result (DECODE clock)

//------------------------------------------------------------------------------
// States
//------------------------------------------------------------------------------
localparam  S_IDLE      = 2'd0                          ;   // idle, or DECODE when i_req = 1
localparam  S_SETUP     = 2'd1                          ;   // SETUP
localparam  S_ACCESS    = 2'd2                          ;   // ACCESS

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
reg     [1:0]       r_state                             ;   // transfer phase

//------------------------------------------------------------------------------
// Phase register
//   IDLE   + i_req -> this clock is DECODE, next clock is SETUP
//   SETUP          -> ACCESS
//   ACCESS         -> IDLE always (the CPU moves to the next instruction,
//                     so the same instruction must not start a new transfer)
//------------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
    if (!nRst)  begin
        r_state     <=  S_IDLE          ;
    end
    else    begin
        case (r_state)
            S_IDLE      :   if (i_req)  r_state <=  S_SETUP     ;
            S_SETUP     :               r_state <=  S_ACCESS    ;
            default     :               r_state <=  S_IDLE      ;
        endcase
    end
end

assign  o_capture = i_req & (r_state == S_IDLE)                     ;
assign  o_psel    = (r_state == S_SETUP) | (r_state == S_ACCESS)    ;
assign  o_penable = (r_state == S_ACCESS)                           ;
assign  o_stall   = i_req & (r_state != S_ACCESS)                   ;

endmodule
