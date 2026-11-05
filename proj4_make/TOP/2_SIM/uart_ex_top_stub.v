// uart_ex_top stub (시뮬레이션 전용): UART RTL이 레포에 없어서 포트만 맞춘 빈 모듈
module uart_ex_top (
    input         PCLK,
    input         PRESETn,
    input         PSEL,
    input         PENABLE,
    input         PWRITE,
    input  [9:0]  PADDR,
    input  [31:0] PWDATA,
    output [31:0] PRDATA,
    output        PREADY,
    output        PSLVERR,
    input         UARTRXD,
    output        UARTTXD,
    output        UARTRXINTR,
    output        UARTTXINTR,
    output        UARTRTINTR,
    output        UARTEINTR,
    output        UARTINTR
);
    assign PRDATA = 32'd0;
    assign PREADY = 1'b1;
    assign PSLVERR = 1'b0;
    assign UARTTXD = 1'b1;
    assign UARTRXINTR = 1'b0;
    assign UARTTXINTR = 1'b0;
    assign UARTRTINTR = 1'b0;
    assign UARTEINTR = 1'b0;
    assign UARTINTR = 1'b0;
endmodule
