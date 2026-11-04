// spi_master : 8비트, MSB first, 모드 0~3, 풀듀플렉스
//  FSM : IDLE -> START(1 T_h) -> DATA(16 에지) -> STOP(1 T_h) -> IDLE
//  한 바이트 = 18 x T_h (busy 구간). cs_n은 건드리지 않음 (SPCR.CS, spi_regs)
//
//  에지 동작 (ecnt 짝수 = leading 에지, 홀수 = trailing 에지)
//            cpha=0              cpha=1
//  leading   miso 샘플           mosi 갱신 (첫 에지에서 MSB)
//  trailing  mosi 갱신(마지막 X) miso 샘플
module spi_master (
    input        PCLK,
    input        PRESETn,

    input        tick,        // sclk_gen
    input        start,       // spi_regs (SPDR 쓰기 ACCESS 사이클의 1클록 pulse)
    input  [7:0] tx_data,
    input        cpol,
    input        cpha,
    input        loop,        // 1이면 miso 대신 자신의 mosi 사용 (동기기 앞에서 선택)

    output reg   busy,
    output reg   done,        // 전송 완료 1클록 pulse
    output reg [7:0] rx_data, // done 시점에 확정, 다음 done까지 유지

    output reg   sclk,
    output reg   mosi,
    input        miso
);
    localparam [1:0] S_IDLE  = 2'd0,
                     S_START = 2'd1,
                     S_DATA  = 2'd2,
                     S_STOP  = 2'd3;

    reg [1:0] state;
    reg       cpol_r, cpha_r;     // start 시점에 캡처한 모드
    reg [7:0] tx_sr, rx_sr;
    reg [3:0] ecnt;               // 0..15 : 지금까지 만든 SCLK 에지 수
    reg       miso_s1, miso_s2;   // 2단 동기기

    wire miso_in = loop ? mosi : miso;
    wire leading = ~ecnt[0];      // 이번 tick이 만드는 에지가 leading 인가

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            miso_s1 <= 1'b0;
            miso_s2 <= 1'b0;
        end else begin
            miso_s1 <= miso_in;
            miso_s2 <= miso_s1;
        end
    end

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            state   <= S_IDLE;
            busy    <= 1'b0;
            done    <= 1'b0;
            rx_data <= 8'd0;
            sclk    <= 1'b0;
            mosi    <= 1'b0;
            cpol_r  <= 1'b0;
            cpha_r  <= 1'b0;
            tx_sr   <= 8'd0;
            rx_sr   <= 8'd0;
            ecnt    <= 4'd0;
        end else begin
            done <= 1'b0;

            case (state)
                S_IDLE: begin
                    sclk <= cpol;                 // idle 레벨 = CPOL
                    if (start) begin
                        state  <= S_START;
                        busy   <= 1'b1;
                        cpol_r <= cpol;
                        cpha_r <= cpha;
                        ecnt   <= 4'd0;
                        if (cpha) begin
                            tx_sr <= tx_data;                    // MSB는 첫 leading 에지에서
                        end else begin
                            mosi  <= tx_data[7];                 // START 동안 MSB 준비
                            tx_sr <= {tx_data[6:0], 1'b0};
                        end
                    end
                end

                S_START: begin
                    if (tick) state <= S_DATA;
                end

                S_DATA: begin
                    if (tick) begin
                        sclk <= ~sclk;
                        ecnt <= ecnt + 4'd1;
                        if (cpha_r == leading) begin
                            // (cpha=0, trailing) 또는 (cpha=1, leading) -> mosi 갱신
                            // cpha=0 의 마지막(16번째) 에지에서는 갱신하지 않음
                            if (ecnt != 4'd15) begin
                                mosi  <= tx_sr[7];
                                tx_sr <= {tx_sr[6:0], 1'b0};
                            end
                        end else begin
                            // (cpha=0, leading) 또는 (cpha=1, trailing) -> miso 샘플
                            rx_sr <= {rx_sr[6:0], miso_s2};
                        end
                        if (ecnt == 4'd15) state <= S_STOP;
                    end
                end

                S_STOP: begin
                    if (tick) begin
                        rx_data <= rx_sr;
                        busy    <= 1'b0;
                        done    <= 1'b1;
                        state   <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
