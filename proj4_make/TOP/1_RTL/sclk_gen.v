// sclk_gen : PCLK를 분주해 SCLK 반주기(T_h)마다 1클록 폭 tick을 생성
//  - en=0 이면 카운터를 0으로 유지
//  - en=1 이면 div 클록마다 tick 1개 (en 상승 후 div번째 클록에서 tick)
//  - div는 busy 중에는 바뀌지 않아야 함 (spi_regs가 max(SPDIV,8)을 공급)
module sclk_gen (
    input        PCLK,
    input        PRESETn,
    input        en,
    input  [7:0] div,
    output       tick
);
    reg [7:0] cnt;

    assign tick = en & (cnt == (div - 8'd1));

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn)          cnt <= 8'd0;
        else if (!en || tick)  cnt <= 8'd0;
        else                   cnt <= cnt + 8'd1;
    end
endmodule
