//==============================================================================
// Module  : sclk_gen
// Purpose : Divides PCLK and makes a 1-clock-wide tick every SCLK half period
//           (T_h).
//             i_en = 0 : counter is held at 0
//             i_en = 1 : one tick every i_div clocks (the tick comes on the
//                        i_div-th clock after i_en rises)
//           i_div must not change while i_en = 1 (spi_regs supplies
//           max(SPDIV, 8) and only changes it while idle).
//==============================================================================

`timescale 1ns / 1ps

module sclk_gen (
                    clk                                 ,
                    nRst                                ,
                    i_en                                ,
                    i_div                               ,
                    o_tick
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input               clk                                 ;   // clock (PCLK)
input               nRst                                ;   // reset, active-LOW, async assert
input               i_en                                ;   // run the divider (spi_master busy)
input   [7:0]       i_div                               ;   // clocks per half period
output              o_tick                              ;   // half-period tick, 1 clock wide

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
reg     [7:0]       r_cnt                               ;   // divider counter

//------------------------------------------------------------------------------
// Tick and counter
//------------------------------------------------------------------------------
assign  o_tick = i_en & (r_cnt == (i_div - 8'd1))       ;

always @(posedge clk or negedge nRst) begin
    if (!nRst)  begin
        r_cnt   <=  8'd0                ;
    end
    else if (!i_en || o_tick)   begin
        r_cnt   <=  8'd0                ;
    end
    else    begin
        r_cnt   <=  r_cnt + 8'd1        ;
    end
end

endmodule
