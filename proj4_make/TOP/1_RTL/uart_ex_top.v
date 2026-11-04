// APB UART (PL011-style register subset). Register map per MCU spec 4.2.
//  0x000 UARTDR  0x018 UARTFR  0x024 UARTIBRD  0x02C UARTLCR_H  0x030 UARTCR
//  0x038 UARTIMSC 0x03C UARTRIS 0x040 UARTMIS  0x044 UARTICR
// Side effects (FIFO push/pop, ICR clear) happen only in the ACCESS phase (PSEL&PENABLE).
module uart_ex_top (
    input         PCLK,
    input         PRESETn,
    input         PSEL,
    input         PENABLE,
    input         PWRITE,
    input  [11:0] PADDR,
    input  [31:0] PWDATA,
    output reg [31:0] PRDATA,
    input         UARTRXD,
    output        UARTTXD,
    output        UARTINTR,
    output        UARTRXINTR,
    output        UARTTXINTR,
    output        UARTRTINTR,
    output        UARTEINTR
);
    // registers
    reg [15:0] ibrd;
    reg [6:0]  lcr_h;                // [6:5] WLEN, [4] FEN(ignored, FIFO always on), [3] STP2, [2] EPS, [1] PEN
    reg [9:0]  cr;                   // [0] UARTEN [7] LBE [8] TXE [9] RXE
    reg [10:0] imsc;
    reg [10:0] ris;                  // [4]RX [5]TX [6]RT(unused) [7]FE [8]PE [9]BE(unused) [10]OE

    wire acc     = PSEL & PENABLE;
    wire wr      = acc & PWRITE;
    wire rd      = acc & ~PWRITE;
    wire uarten  = cr[0];
    wire lbe     = cr[7];
    wire txe     = cr[8];
    wire rxe     = cr[9];

    wire sel_dr   = (PADDR == 12'h000);
    wire sel_fr   = (PADDR == 12'h018);
    wire sel_ibrd = (PADDR == 12'h024);
    wire sel_lcr  = (PADDR == 12'h02C);
    wire sel_cr   = (PADDR == 12'h030);
    wire sel_imsc = (PADDR == 12'h038);
    wire sel_ris  = (PADDR == 12'h03C);
    wire sel_mis  = (PADDR == 12'h040);
    wire sel_icr  = (PADDR == 12'h044);

    // baud tick
    wire tick;
    uart_baud u_baud (.clk(PCLK), .rstn(PRESETn), .ibrd(ibrd), .tick(tick));

    // TX path
    wire       txf_empty, txf_full, txf_pop;
    wire [7:0] txf_dout;
    wire       tx_busy, txd_core;
    wire       txf_push = wr & sel_dr & uarten;
    uart_fifo #(8) u_txf (.clk(PCLK), .rstn(PRESETn), .push(txf_push), .pop(txf_pop),
                          .din(PWDATA[7:0]), .dout(txf_dout), .empty(txf_empty), .full(txf_full));
    uart_tx u_tx (.clk(PCLK), .rstn(PRESETn), .tick(tick), .en(uarten & txe),
                  .wlen(lcr_h[6:5]), .pen(lcr_h[1]), .eps(lcr_h[2]), .stp2(lcr_h[3]),
                  .din(txf_dout), .empty(txf_empty), .pop(txf_pop), .txd(txd_core), .busy(tx_busy));
    assign UARTTXD = lbe ? 1'b1 : txd_core;   // loopback: TX line idles high externally

    // RX path
    reg rx_s1, rx_s2;
    wire rxd_in = lbe ? txd_core : UARTRXD;
    always @(posedge PCLK or negedge PRESETn)
        if (!PRESETn) begin rx_s1 <= 1'b1; rx_s2 <= 1'b1; end
        else begin rx_s1 <= rxd_in; rx_s2 <= rx_s1; end

    wire       rx_valid, rx_fe, rx_pe, rx_busy;
    wire [7:0] rx_data;
    uart_rx u_rx (.clk(PCLK), .rstn(PRESETn), .tick(tick), .en(uarten & rxe),
                  .wlen(lcr_h[6:5]), .pen(lcr_h[1]), .eps(lcr_h[2]), .rxd(rx_s2),
                  .valid(rx_valid), .dout(rx_data), .fe(rx_fe), .pe(rx_pe), .busy(rx_busy));

    wire        rxf_empty, rxf_full;
    wire [10:0] rxf_dout;                         // {BE(0), PE, FE, data}
    wire        rxf_pop = rd & sel_dr;
    wire        rxf_push = rx_valid & ~rxf_full;
    uart_fifo #(11) u_rxf (.clk(PCLK), .rstn(PRESETn), .push(rx_valid), .pop(rxf_pop),
                           .din({1'b0, rx_pe, rx_fe, rx_data}), .dout(rxf_dout),
                           .empty(rxf_empty), .full(rxf_full));

    // interrupt raw status: set on event, cleared by ICR
    reg txf_empty_d;
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) txf_empty_d <= 1'b1;
        else          txf_empty_d <= txf_empty;
    end
    wire [10:0] ev;
    assign ev[3:0]  = 4'b0;
    assign ev[4]    = rxf_push;                         // RX: a character arrived
    assign ev[5]    = txf_empty & ~txf_empty_d;         // TX: FIFO drained
    assign ev[6]    = 1'b0;
    assign ev[7]    = rx_valid & rx_fe;
    assign ev[8]    = rx_valid & rx_pe;
    assign ev[9]    = 1'b0;
    assign ev[10]   = rx_valid & rxf_full;              // overrun: dropped

    wire [10:0] icr_clr = (wr & sel_icr) ? PWDATA[10:0] : 11'd0;

    // register write / interrupt status
    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            ibrd <= 16'd0; lcr_h <= 7'd0; cr <= 10'h300; imsc <= 11'd0; ris <= 11'd0;
        end else begin
            ris <= (ris | ev) & ~icr_clr;
            if (wr) begin
                if (sel_ibrd) ibrd  <= PWDATA[15:0];
                if (sel_lcr)  lcr_h <= PWDATA[6:0];
                if (sel_cr)   cr    <= PWDATA[9:0];
                if (sel_imsc) imsc  <= PWDATA[10:0];
            end
        end
    end

    wire [10:0] mis = ris & imsc;
    assign UARTINTR   = |mis;
    assign UARTRXINTR = mis[4];
    assign UARTTXINTR = mis[5];
    assign UARTRTINTR = mis[6];
    assign UARTEINTR  = |mis[10:7];

    // flag register
    wire [31:0] fr = {24'd0, txf_empty, rxf_full, txf_full, rxf_empty,
                      tx_busy | ~txf_empty | rx_busy, 3'b000};

    // read mux (valid in ACCESS; undefined addresses read 0)
    always @(*) begin
        PRDATA = 32'd0;
        if      (sel_dr)   PRDATA = {20'd0, 1'b0, rxf_empty ? 11'd0 : rxf_dout};
        else if (sel_fr)   PRDATA = fr;
        else if (sel_ibrd) PRDATA = {16'd0, ibrd};
        else if (sel_lcr)  PRDATA = {25'd0, lcr_h};
        else if (sel_cr)   PRDATA = {22'd0, cr};
        else if (sel_imsc) PRDATA = {21'd0, imsc};
        else if (sel_ris)  PRDATA = {21'd0, ris};
        else if (sel_mis)  PRDATA = {21'd0, mis};
    end
endmodule
