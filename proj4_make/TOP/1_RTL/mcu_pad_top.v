//==============================================================================
// Module  : mcu_pad_top
// Purpose : Pad wrapper around mcu_top (chip top level). Every signal pin goes
//           through an I/O pad cell of the GPDK045 I/O library:
//             PADDI : input buffer   (.PAD = chip pin, .Y = signal to the core)
//             PADDO : output driver  (.A = signal from the core, .PAD = chip pin)
//           Pad instance names pad1, pad2, ... so that the SDC can use
//           set_dont_touch on them (same naming as the lab design).
//
// Pads in use now : clk, clrn (mcu_top has no other pins at the moment).
// The UART / SPI pads are commented out like their slots in mcu_top.v. To
// connect a peripheral, remove the "//" marks on the lines marked [UART] /
// [SPI] / [SLV] here (ports, wires, pads, mcu_top connections) and do the same
// in mcu_top.v.
//
// Port order: peripheral pins first (commented), clk / clrn last, so the port
// list stays valid with or without the comments.
//
// Not included (done in the PnR step): power / ground pads (PADVDD, PADVSS,
// PADVDDIOR, PADVSSIOR), corner and filler cells.
// The debug outputs of mcu_top (pc, inst, aluout, memout) are not routed to
// pads (too many pins). With no peripheral connected, nothing in mcu_top is
// observable, so synthesis would remove it: connect at least one peripheral
// before synthesis.
//==============================================================================

`timescale 1ns / 1ps

module mcu_pad_top (
//                  UARTRXD                             ,   // [UART]
//                  UARTTXD                             ,   // [UART]
//                  UARTINTR                            ,   // [UART]
//                  SPISCLK                             ,   // [SPI]
//                  SPIMOSI                             ,   // [SPI]
//                  SPIMISO                             ,   // [SPI]
//                  SPICSN                              ,   // [SPI]
//                  SPIINTR                             ,   // [SPI]
//                  SLVSCLK                             ,   // [SLV]
//                  SLVMOSI                             ,   // [SLV]
//                  SLVMISO                             ,   // [SLV]
//                  SLVCSN                              ,   // [SLV]
//                  SLVINTR                             ,   // [SLV]
                    clk                                 ,
                    clrn
);

//------------------------------------------------------------------------------
// External pins
//------------------------------------------------------------------------------
input               clk                                 ;   // clock
input               clrn                                ;   // reset, active-LOW
// input            UARTRXD                             ;   // [UART] serial receive
// output           UARTTXD                             ;   // [UART] serial transmit
// output           UARTINTR                            ;   // [UART] interrupt
// output           SPISCLK                             ;   // [SPI]  serial clock
// output           SPIMOSI                             ;   // [SPI]  master out, slave in
// input            SPIMISO                             ;   // [SPI]  master in, slave out
// output           SPICSN                              ;   // [SPI]  chip select
// output           SPIINTR                             ;   // [SPI]  interrupt
// input            SLVSCLK                             ;   // [SLV]  serial clock from the master
// input            SLVMOSI                             ;   // [SLV]  master out, slave in
// output           SLVMISO                             ;   // [SLV]  master in, slave out
// input            SLVCSN                              ;   // [SLV]  chip select
// output           SLVINTR                             ;   // [SLV]  interrupt

//------------------------------------------------------------------------------
// Internal wires (in_ = pad to core, out_ = core to pad)
//------------------------------------------------------------------------------
wire                in_clk                              ;   // clock after the input pad
wire                in_clrn                             ;   // reset after the input pad
// wire             in_UARTRXD                          ;   // [UART]
// wire             out_UARTTXD                         ;   // [UART]
// wire             out_UARTINTR                        ;   // [UART]
// wire             out_SPISCLK                         ;   // [SPI]
// wire             out_SPIMOSI                         ;   // [SPI]
// wire             in_SPIMISO                          ;   // [SPI]
// wire             out_SPICSN                          ;   // [SPI]
// wire             out_SPIINTR                         ;   // [SPI]
// wire             in_SLVSCLK                          ;   // [SLV]
// wire             in_SLVMOSI                          ;   // [SLV]
// wire             out_SLVMISO                         ;   // [SLV]
// wire             in_SLVCSN                           ;   // [SLV]
// wire             out_SLVINTR                         ;   // [SLV]

//------------------------------------------------------------------------------
// Core
//------------------------------------------------------------------------------
mcu_top     u_mcu_top   (
                .clk            (in_clk          )   ,
                .clrn           (in_clrn         )   ,
//              .UARTRXD        (in_UARTRXD      )   ,   // [UART]
//              .UARTTXD        (out_UARTTXD     )   ,   // [UART]
//              .UARTINTR       (out_UARTINTR    )   ,   // [UART]
//              .SPISCLK        (out_SPISCLK     )   ,   // [SPI]
//              .SPIMOSI        (out_SPIMOSI     )   ,   // [SPI]
//              .SPIMISO        (in_SPIMISO      )   ,   // [SPI]
//              .SPICSN         (out_SPICSN      )   ,   // [SPI]
//              .SPIINTR        (out_SPIINTR     )   ,   // [SPI]
//              .SLVSCLK        (in_SLVSCLK      )   ,   // [SLV]
//              .SLVMOSI        (in_SLVMOSI      )   ,   // [SLV]
//              .SLVMISO        (out_SLVMISO     )   ,   // [SLV]
//              .SLVCSN         (in_SLVCSN       )   ,   // [SLV]
//              .SLVINTR        (out_SLVINTR     )   ,   // [SLV]
                .pc             (                )   ,   // debug, no pads
                .inst           (                )   ,
                .aluout         (                )   ,
                .memout         (                )
);

//------------------------------------------------------------------------------
// Input pads
//------------------------------------------------------------------------------
PADDI pad1 (.PAD(clk),      .Y(in_clk));        // clock
PADDI pad2 (.PAD(clrn),     .Y(in_clrn));       // reset
// PADDI pad3 (.PAD(UARTRXD),  .Y(in_UARTRXD)); // [UART]
// PADDI pad6 (.PAD(SPIMISO),  .Y(in_SPIMISO)); // [SPI]
// PADDI pad11(.PAD(SLVSCLK),  .Y(in_SLVSCLK)); // [SLV]
// PADDI pad12(.PAD(SLVMOSI),  .Y(in_SLVMOSI)); // [SLV]
// PADDI pad14(.PAD(SLVCSN),   .Y(in_SLVCSN));  // [SLV]

//------------------------------------------------------------------------------
// Output pads
//------------------------------------------------------------------------------
// PADDO pad4 (.A(out_UARTTXD),  .PAD(UARTTXD));  // [UART]
// PADDO pad5 (.A(out_UARTINTR), .PAD(UARTINTR)); // [UART]
// PADDO pad7 (.A(out_SPISCLK),  .PAD(SPISCLK));  // [SPI]
// PADDO pad8 (.A(out_SPIMOSI),  .PAD(SPIMOSI));  // [SPI]
// PADDO pad9 (.A(out_SPICSN),   .PAD(SPICSN));   // [SPI]
// PADDO pad10(.A(out_SPIINTR),  .PAD(SPIINTR));  // [SPI]
// PADDO pad13(.A(out_SLVMISO),  .PAD(SLVMISO));  // [SLV]
// PADDO pad15(.A(out_SLVINTR),  .PAD(SLVINTR));  // [SLV]

endmodule
