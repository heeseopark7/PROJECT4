//==============================================================================
// Module  : uart_ex_top
// Purpose : Top level of the Extended UART. It mostly connects the blocks and
//           adds two small circuits on the receive input path: a 2-FF
//           synchronizer for UARTRXD and a loopback selector.
//           (No I/O pad cells: ports connect directly to the core logic.)
//
// Parameters:
//   FIFO_DEPTH : entries of the TX/RX FIFO (power of 2). One value is passed
//                down to tx_fifo, rx_fifo and interrupt_logic.
//   CNT_W      : width of the FIFO count wires, = $clog2(FIFO_DEPTH)+1
//
// Data paths:
//   (1) send    : APB write -> reg_block -> tx_fifo -> tx_logic -> UARTTXD
//   (2) receive : UARTRXD -> synchronizer -> selector -> rx_logic -> rx_fifo
//                 -> reg_block -> APB read
//   (3) notify  : FIFO counts / errors -> interrupt_logic -> 5 interrupt pins
//   (4) timing  : reg_block (IBRD) -> baud_gen -> w_tick (16x) -> TX, RX, IRQ
//==============================================================================

`timescale 1ns / 1ps

module uart_ex_top #(
    parameter       FIFO_DEPTH  = 16                    ,   // FIFO entries (power of 2)
    parameter       CNT_W       = $clog2(FIFO_DEPTH)+1      // FIFO count width
)(                  PCLK                                ,
                    PRESETn                             ,
                    PSEL                                ,
                    PENABLE                             ,
                    PWRITE                              ,
                    PADDR                               ,
                    PWDATA                              ,
                    PRDATA                              ,
                    PREADY                              ,
                    PSLVERR                             ,
                    UARTRXD                             ,
                    UARTTXD                             ,
                    UARTRXINTR                          ,
                    UARTTXINTR                          ,
                    UARTRTINTR                          ,
                    UARTEINTR                           ,
                    UARTINTR
);
 
//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input               PCLK                                ;   // clock (inside: clk)
input               PRESETn                             ;   // reset, active-LOW, async assert (inside: nRst)
input               PSEL                                ;   // APB select
input               PENABLE                             ;   // APB enable (2nd phase of a transfer)
input               PWRITE                              ;   // APB direction, 1 = write
input   [11:2]      PADDR                               ;   // APB word address (bits [1:0] not present)
input   [31:0]      PWDATA                              ;   // APB write data
output  [31:0]      PRDATA                              ;   // APB read data
output              PREADY                              ;   // APB ready (always 1, from reg_block)
output              PSLVERR                             ;   // APB slave error (always 0, from reg_block)
input               UARTRXD                             ;   // serial receive input
output              UARTTXD                             ;   // serial transmit output
output              UARTRXINTR                          ;   // RX interrupt
output              UARTTXINTR                          ;   // TX interrupt
output              UARTRTINTR                          ;   // receive-timeout interrupt
output              UARTEINTR                           ;   // error interrupt (FE/PE/BE/OE)
output              UARTINTR                            ;   // combined interrupt
 
//------------------------------------------------------------------------------
// Internal registers: 2-FF synchronizer for the asynchronous UARTRXD input
//------------------------------------------------------------------------------
reg                 r_rxd_s1                            ;   // 1st stage (may be metastable)
reg                 r_rxd_s2                            ;   // 2nd stage (safe to use)
 
//------------------------------------------------------------------------------
// Internal wires (name = what it carries, source block -> destination block)
//------------------------------------------------------------------------------
wire                w_rxd                               ;   // RX line seen by rx_logic (after loopback select)
wire                w_txd                               ;   // TX line from tx_logic
wire                w_lbe                               ;   // loopback enable (CR.LBE) from reg_block
wire    [15:0]      w_ibrd                              ;   // integer baud divisor from reg_block
wire                w_tick                              ;   // 16x baud tick from baud_gen
wire                w_tx_push                           ;   // reg_block -> tx_fifo, write a byte
wire                w_tx_pop                            ;   // tx_logic -> tx_fifo, take a byte
wire    [7:0]       w_tx_wdata                          ;   // reg_block -> tx_fifo, byte to send
wire    [7:0]       w_tx_rdata                          ;   // tx_fifo -> tx_logic, oldest byte
wire                w_tx_empty                          ;   // tx_fifo empty flag (to tx_logic, reg_block)
wire                w_tx_full                           ;   // tx_fifo full flag (to reg_block)
wire    [CNT_W-1:0] w_tx_count                          ;   // tx_fifo entry count (to interrupt_logic)
wire                w_rx_push                           ;   // rx_logic -> rx_fifo, store a received frame
wire                w_rx_pop                            ;   // reg_block -> rx_fifo, UARTDR read
wire    [10:0]      w_rx_wdata                          ;   // rx_logic -> rx_fifo, {BE,PE,FE,DATA[7:0]}
wire    [10:0]      w_rx_rdata                          ;   // rx_fifo -> reg_block, oldest frame
wire                w_rx_empty                          ;   // rx_fifo empty flag (to reg_block, interrupt_logic)
wire                w_rx_full                           ;   // rx_fifo full flag (to rx_logic, reg_block)
wire    [CNT_W-1:0] w_rx_count                          ;   // rx_fifo entry count (to interrupt_logic)
wire                w_tx_en                             ;   // TX enable (UARTEN & TXE) from reg_block
wire                w_brk                               ;   // send break (LCR_H.BRK)
wire                w_pen                               ;   // parity enable (to tx_logic and rx_logic)
wire                w_eps                               ;   // even parity select (to tx_logic and rx_logic)
wire                w_tx_busy                           ;   // tx_logic busy (to reg_block, for UARTFR.BUSY)
wire                w_rx_en                             ;   // RX enable (UARTEN & RXE) from reg_block
wire                w_overrun                           ;   // rx_logic -> interrupt_logic, overrun event
wire    [6:0]       w_ris                               ;   // raw interrupt status
wire    [6:0]       w_mis                               ;   // masked interrupt status
wire    [6:0]       w_imsc                              ;   // interrupt mask from reg_block
wire    [6:0]       w_icr                               ;   // interrupt clear pulses from reg_block

//------------------------------------------------------------------------------
// 2-FF synchronizer
//   UARTRXD changes at any time relative to PCLK. Two flip-flops in series
//   give the first one time to settle, so only r_rxd_s2 is used inside.
//   Reset value is 1 (idle level) so no false start bit appears after reset.
//------------------------------------------------------------------------------
always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)   begin
        r_rxd_s1    <=  1'b1            ;
        r_rxd_s2    <=  1'b1            ;
    end
    else    begin
        r_rxd_s1    <=  UARTRXD       ;
        r_rxd_s2    <=  r_rxd_s1        ;
    end
end
 
//------------------------------------------------------------------------------
// Loopback selector and TX pin
//   w_lbe = 1 : rx_logic receives our own w_txd (external pin is ignored)
//   w_lbe = 0 : rx_logic receives the synchronized external UARTRXD
//   The UARTTXD pin always shows w_txd, also during loopback.
//------------------------------------------------------------------------------
assign  w_rxd     = w_lbe ? w_txd : r_rxd_s2  ;
assign  UARTTXD   = w_txd                     ;
 
//------------------------------------------------------------------------------
// baud_gen : makes the 16x tick from the divisor in reg_block
//------------------------------------------------------------------------------
baud_gen    uut1    (
                .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_ibrd         (w_ibrd      )   ,
                .o_tick_16x     (w_tick      )
);
 
//------------------------------------------------------------------------------
// tx_fifo : holds bytes written by software until tx_logic takes them
//------------------------------------------------------------------------------
tx_fifo     #(
                .FIFO_DEPTH     (FIFO_DEPTH  )
)           uut2
(               .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_push         (w_tx_push   )   ,
                .i_pop          (w_tx_pop    )   ,
                .i_wdata        (w_tx_wdata  )   ,
                .o_rdata        (w_tx_rdata  )   ,
                .o_empty        (w_tx_empty  )   ,
                .o_full         (w_tx_full   )   ,
                .o_count        (w_tx_count  )
);
 
//------------------------------------------------------------------------------
// rx_fifo : holds received frames (11 bits: error flags + data) for software
//------------------------------------------------------------------------------
rx_fifo     #(
                .FIFO_DEPTH     (FIFO_DEPTH  )
)           uut3
(               .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_push         (w_rx_push   )   ,
                .i_pop          (w_rx_pop    )   ,
                .i_wdata        (w_rx_wdata  )   ,
                .o_rdata        (w_rx_rdata  )   ,
                .o_empty        (w_rx_empty  )   ,
                .o_full         (w_rx_full   )   ,
                .o_count        (w_rx_count  )
);
 
//------------------------------------------------------------------------------
// tx_logic : takes a byte from tx_fifo and sends it bit by bit on w_txd
//------------------------------------------------------------------------------
tx_logic    uut4    (
                .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_tick_16x     (w_tick      )   ,
                .i_tx_en        (w_tx_en     )   ,
                .i_brk          (w_brk       )   ,
                .i_fifo_empty   (w_tx_empty  )   ,
                .i_pen          (w_pen       )   ,
                .i_fifo_rdata   (w_tx_rdata  )   ,
                .i_eps          (w_eps       )   ,
                .o_fifo_pop     (w_tx_pop    )   ,
                .o_txd          (w_txd       )   ,
                .o_tx_busy      (w_tx_busy   )
);
 
//------------------------------------------------------------------------------
// rx_logic : samples w_rxd, builds a frame with error flags, pushes it to rx_fifo
//------------------------------------------------------------------------------
rx_logic    uut5    (
                .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_rxd          (w_rxd       )   ,
                .i_tick_16x     (w_tick      )   ,
                .i_rx_en        (w_rx_en     )   ,
                .i_pen          (w_pen       )   ,
                .i_eps          (w_eps       )   ,
                .i_fifo_full    (w_rx_full   )   ,
                .o_fifo_push    (w_rx_push   )   ,
                .o_fifo_wdata   (w_rx_wdata  )   ,
                .o_overrun      (w_overrun   )
);
 
//------------------------------------------------------------------------------
// reg_block : APB slave and register file (also builds UARTFR, enables, etc.)
//------------------------------------------------------------------------------
reg_block   uut6    (
                .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_psel         (PSEL        )   ,
                .i_penable      (PENABLE     )   ,
                .i_pwrite       (PWRITE      )   ,
                .i_paddr        (PADDR       )   ,
                .i_pwdata       (PWDATA      )   ,
                .i_tx_full      (w_tx_full   )   ,
                .i_tx_empty     (w_tx_empty  )   ,
                .i_rx_rdata     (w_rx_rdata  )   ,
                .i_rx_empty     (w_rx_empty  )   ,
                .i_rx_full      (w_rx_full   )   ,
                .i_tx_busy      (w_tx_busy   )   ,
                .i_ris          (w_ris       )   ,
                .i_mis          (w_mis       )   ,
                .o_prdata       (PRDATA      )   ,
                .o_pready       (PREADY      )   ,
                .o_pslverr      (PSLVERR     )   ,
                .o_tx_push      (w_tx_push   )   ,
                .o_tx_wdata     (w_tx_wdata  )   ,
                .o_rx_pop       (w_rx_pop    )   ,
                .o_tx_en        (w_tx_en     )   ,
                .o_brk          (w_brk       )   ,
                .o_rx_en        (w_rx_en     )   ,
                .o_pen          (w_pen       )   ,
                .o_eps          (w_eps       )   ,
                .o_ibrd         (w_ibrd      )   ,
                .o_lbe          (w_lbe       )   ,
                .o_imsc         (w_imsc      )   ,
                .o_icr          (w_icr       )
);
 
//------------------------------------------------------------------------------
// interrupt_logic : status bits (RIS/MIS) and the 5 interrupt output pins
//   i_rx_err takes the 3 error bits of the pushed frame: [8]=FE, [9]=PE, [10]=BE
//------------------------------------------------------------------------------
interrupt_logic #(
                .FIFO_DEPTH     (FIFO_DEPTH  )
)           uut7
(               .clk            (PCLK        )   ,
                .nRst           (PRESETn     )   ,
                .i_tx_count     (w_tx_count  )   ,
                .i_rx_count     (w_rx_count  )   ,
                .i_rx_empty     (w_rx_empty  )   ,
                .i_rx_push      (w_rx_push   )   ,
                .i_rx_err       (w_rx_wdata[10:8])   ,
                .i_overrun      (w_overrun   )   ,
                .i_tick_16x     (w_tick      )   ,
                .i_imsc         (w_imsc      )   ,
                .i_icr          (w_icr       )   ,
                .o_ris          (w_ris       )   ,
                .o_mis          (w_mis       )   ,
                .o_rxintr       (UARTRXINTR  )   ,
                .o_txintr       (UARTTXINTR  )   ,
                .o_rtintr       (UARTRTINTR  )   ,
                .o_eintr        (UARTEINTR   )   ,
                .o_intr         (UARTINTR    )
);

endmodule