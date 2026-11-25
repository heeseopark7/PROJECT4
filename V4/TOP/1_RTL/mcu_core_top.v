//==============================================================================
// Module  : mcu_core_top
// Purpose : Pad-less wrapper around mcu_top for the core-only experiment track.
//           Same 15 signal pins as mcu_pad_top, but no I/O pad cells, so the
//           PnR can run at a meaningful utilization. The debug outputs of
//           mcu_top (pc, inst, aluout, memout) are left unconnected, exactly
//           like in mcu_pad_top.
//           Do NOT change this wrapper between versions (v1-core, v2, v3 ...).
//==============================================================================

`timescale 1ns / 1ps

module mcu_core_top (
                    UARTRXD , UARTTXD , UARTINTR ,
                    SPISCLK , SPIMOSI , SPIMISO , SPICSN , SPIINTR ,
                    SLVSCLK , SLVMOSI , SLVMISO , SLVCSN , SLVINTR ,
                    clk     , clrn
);

input               clk      ;
input               clrn     ;
input               UARTRXD  ;
output              UARTTXD  ;
output              UARTINTR ;
output              SPISCLK  ;
output              SPIMOSI  ;
input               SPIMISO  ;
output              SPICSN   ;
output              SPIINTR  ;
input               SLVSCLK  ;
input               SLVMOSI  ;
output              SLVMISO  ;
input               SLVCSN   ;
output              SLVINTR  ;

mcu_top u_mcu_top (
    .clk        (clk)       , .clrn     (clrn)      ,
    .UARTRXD    (UARTRXD)   , .UARTTXD  (UARTTXD)   , .UARTINTR (UARTINTR)  ,
    .SPISCLK    (SPISCLK)   , .SPIMOSI  (SPIMOSI)   , .SPIMISO  (SPIMISO)   ,
    .SPICSN     (SPICSN)    , .SPIINTR  (SPIINTR)   ,
    .SLVSCLK    (SLVSCLK)   , .SLVMOSI  (SLVMOSI)   , .SLVMISO  (SLVMISO)   ,
    .SLVCSN     (SLVCSN)    , .SLVINTR  (SLVINTR)   ,
    .pc         ()          , .inst     ()          , .aluout   ()          , .memout ()
);

endmodule
