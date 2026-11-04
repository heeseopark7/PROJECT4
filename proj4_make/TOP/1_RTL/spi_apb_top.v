// spi_apb_top : APB 슬레이브 SPI 마스터 (합성 / P&R 대상 top)
//  MCU 슬롯 0x4000_1000, PCLK=clk, PRESETn=clrn (비동기 active-low)
//  PREADY / PSLVERR 없음 (wait state 없이 같은 사이클 응답)
module spi_apb_top (
    input         PCLK,
    input         PRESETn,
    input         PSEL,
    input         PENABLE,
    input         PWRITE,
    input  [9:0]  PADDR,      // aluout[11:2], SPI는 [1:0]만 사용
    input  [31:0] PWDATA,
    output [31:0] PRDATA,

    output        SPISCLK,
    output        SPIMOSI,
    input         SPIMISO,
    output        SPICSN,
    output        SPIINTR
);
    wire        start, busy, done, tick;
    wire [7:0]  tx_data, rx_data, div;
    wire        cpol, cpha, loop;

    spi_regs u_regs (
        .PCLK(PCLK), .PRESETn(PRESETn),
        .PSEL(PSEL), .PENABLE(PENABLE), .PWRITE(PWRITE),
        .PADDR(PADDR), .PWDATA(PWDATA), .PRDATA(PRDATA),
        .start(start), .tx_data(tx_data),
        .cpol(cpol), .cpha(cpha), .loop(loop),
        .div(div), .busy(busy), .done(done), .rx_data(rx_data),
        .cs_n(SPICSN), .intr(SPIINTR));

    sclk_gen u_sclk_gen (
        .PCLK(PCLK), .PRESETn(PRESETn),
        .en(busy), .div(div), .tick(tick));

    spi_master u_master (
        .PCLK(PCLK), .PRESETn(PRESETn),
        .tick(tick), .start(start), .tx_data(tx_data),
        .cpol(cpol), .cpha(cpha), .loop(loop),
        .busy(busy), .done(done), .rx_data(rx_data),
        .sclk(SPISCLK), .mosi(SPIMOSI), .miso(SPIMISO));
endmodule
