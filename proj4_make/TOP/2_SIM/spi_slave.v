// spi_slave : (검증용, 칩 미포함) SPI 슬레이브 모델 - 합성 대상 아님
//  FSM : IDLE -> SHIFT(8비트 = SCLK 에지 16개) -> DONE -> WAIT -> LOAD -> (SHIFT | IDLE)
//  sclk / cs_n / mosi 는 2단 동기기를 통과 (지연 약 3~4클록)
//  tx_data : 응답 데이터. TB에서 직전 수신 바이트(echo)를 연결한다.
//            rx_valid 로 TB가 echo를 갱신할 시간을 주기 위해 WAIT 1클록 뒤 LOAD에서 읽는다.
module spi_slave (
    input        clk,
    input        rst_n,
    input        cpol,
    input        cpha,
    input        sclk,
    input        cs_n,
    input        mosi,
    output reg   miso,
    input  [7:0] tx_data,
    output reg [7:0] rx_data,
    output reg   rx_valid
);
    localparam [2:0] S_IDLE = 3'd0, S_SHIFT = 3'd1, S_DONE = 3'd2, S_WAIT = 3'd3, S_LOAD = 3'd4;

    reg [2:0] state;
    reg [1:0] sclk_s;  reg sclk_d;
    reg [1:0] cs_s;
    reg [1:0] mosi_s;
    reg [7:0] tx_sr, rx_sr;
    reg [4:0] ecnt;        // SCLK 에지 수 (0..16)

    wire sclk_q = sclk_s[1];
    wire cs_q   = cs_s[1];
    wire mosi_q = mosi_s[1];

    wire rise    = ~sclk_d &  sclk_q;
    wire fall    =  sclk_d & ~sclk_q;
    wire edge_   = rise | fall;
    wire leading = cpol ? fall : rise;            // idle에서 벗어나는 에지
    wire sample_edge = edge_ & (cpha ? ~leading : leading);
    wire update_edge = edge_ & (cpha ?  leading : ~leading);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_s <= 2'b00; sclk_d <= 1'b0;
            cs_s   <= 2'b11;
            mosi_s <= 2'b00;
        end else begin
            sclk_s <= {sclk_s[0], sclk};
            sclk_d <= sclk_q;
            cs_s   <= {cs_s[0], cs_n};
            mosi_s <= {mosi_s[0], mosi};
        end
    end

    // 새 바이트 시작 준비 : tx_data 저장, cpha=0 이면 MSB를 miso에 바로 올림
    task load_byte;
        begin
            ecnt <= 5'd0;
            if (cpha) begin
                tx_sr <= tx_data;
            end else begin
                miso  <= tx_data[7];
                tx_sr <= {tx_data[6:0], 1'b0};
            end
        end
    endtask

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            miso     <= 1'b0;
            rx_data  <= 8'd0;
            rx_valid <= 1'b0;
            tx_sr    <= 8'd0;
            rx_sr    <= 8'd0;
            ecnt     <= 5'd0;
        end else begin
            rx_valid <= 1'b0;
            case (state)
                S_IDLE: begin
                    ecnt <= 5'd0;
                    if (!cs_q) begin
                        load_byte;
                        state <= S_SHIFT;
                    end
                end

                S_SHIFT: begin
                    if (cs_q) begin
                        state <= S_IDLE;            // 프레임 중단 : 비트 카운터 초기화
                        ecnt  <= 5'd0;
                    end else if (edge_) begin
                        ecnt <= ecnt + 5'd1;
                        if (sample_edge)
                            rx_sr <= {rx_sr[6:0], mosi_q};
                        if (update_edge && ecnt != 5'd15) begin
                            miso  <= tx_sr[7];
                            tx_sr <= {tx_sr[6:0], 1'b0};
                        end
                        if (ecnt == 5'd15) state <= S_DONE;
                    end
                end

                S_DONE: begin
                    rx_data  <= rx_sr;
                    rx_valid <= 1'b1;
                    state    <= S_WAIT;
                end

                S_WAIT: state <= S_LOAD;

                S_LOAD: begin
                    if (cs_q) begin
                        state <= S_IDLE;
                        ecnt  <= 5'd0;
                    end else begin
                        load_byte;                  // cs_n이 아직 Low : 다음 바이트
                        state <= S_SHIFT;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule
