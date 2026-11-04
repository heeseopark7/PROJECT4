// spi_regs : APB 접근을 해석해 레지스터(SPCR/SPSR/SPDR/SPDIV)를 보관하고 spi_master를 제어
//  오프셋(PADDR[1:0]) 0:SPCR 1:SPSR 2:SPDR 3:SPDIV (4바이트 간격, 슬롯 안에서 alias)
//  쓰기/읽기 부수효과는 PSEL & PENABLE (ACCESS) 일 때만. SETUP 사이클은 상태를 바꾸지 않음.
//  PRDATA는 PADDR[1:0]으로 고르는 4:1 mux (PSEL 게이팅은 mcu_top 읽기 mux 담당)
module spi_regs (
    input         PCLK,
    input         PRESETn,
    input         PSEL,
    input         PENABLE,
    input         PWRITE,
    input  [9:0]  PADDR,
    input  [31:0] PWDATA,
    output [31:0] PRDATA,

    // spi_master / sclk_gen 쪽
    output        start,
    output [7:0]  tx_data,
    output        cpol,
    output        cpha,
    output        loop,
    output [7:0]  div,
    input         busy,
    input         done,
    input  [7:0]  rx_data,

    output        cs_n,
    output        intr
);
    localparam [1:0] A_SPCR = 2'd0, A_SPSR = 2'd1, A_SPDR = 2'd2, A_SPDIV = 2'd3;

    reg [5:0] spcr;        // [0]SPE [1]CPOL [2]CPHA [3]CS [4]LOOP [5]SPIE
    reg [7:0] spdiv;       // 리셋값 25
    reg       done_flag;   // SPSR.DONE
    reg       wcol;        // SPSR.WCOL
    reg       busy_flag;   // start 직후 ~ done 까지 1 (master.busy가 한 클록 늦게 올라오는 틈을 메움)

    wire [1:0] sel  = PADDR[1:0];
    wire       acc  = PSEL & PENABLE;
    wire       wr   = acc & PWRITE;
    wire       rd   = acc & ~PWRITE;

    wire busy_eff = busy | busy_flag;
    wire spe      = spcr[0];

    wire wr_spdr  = wr & (sel == A_SPDR);
    wire rd_spdr  = rd & (sel == A_SPDR);

    // SPDR 쓰기 : SPE=1 & BUSY=0 -> 전송 시작, SPE=1 & BUSY=1 -> WCOL (쓰기 무시)
    assign start   = wr_spdr & spe & ~busy_eff;
    wire   wcol_set = wr_spdr & spe &  busy_eff;
    wire   wcol_clr = wr & (sel == A_SPSR) & PWDATA[2];

    assign tx_data = PWDATA[7:0];
    assign cpol    = spcr[1];
    assign cpha    = spcr[2];
    assign loop    = spcr[4];
    assign cs_n    = ~spcr[3];
    assign div     = (spdiv < 8'd8) ? 8'd8 : spdiv;   // 실효 분주값 = max(SPDIV, 8)
    assign intr    = spcr[5] & done_flag;

    always @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            spcr      <= 6'd0;
            spdiv     <= 8'd25;
            done_flag <= 1'b0;
            wcol      <= 1'b0;
            busy_flag <= 1'b0;
        end else begin
            if (wr && sel == A_SPCR)  spcr  <= PWDATA[5:0];
            if (wr && sel == A_SPDIV) spdiv <= PWDATA[7:0];

            // busy_flag : start에서 세트, master의 done pulse에서 클리어
            if (start)     busy_flag <= 1'b1;
            else if (done) busy_flag <= 1'b0;

            // DONE : 세트(done) 우선, 클리어는 SPDR 읽기 또는 새 전송 시작
            if (done)                    done_flag <= 1'b1;
            else if (rd_spdr || start)   done_flag <= 1'b0;

            // WCOL : 세트 우선, W1C
            if (wcol_set)      wcol <= 1'b1;
            else if (wcol_clr) wcol <= 1'b0;
        end
    end

    reg [31:0] rdata;
    always @(*) begin
        case (sel)
            A_SPCR:  rdata = {26'd0, spcr};
            A_SPSR:  rdata = {29'd0, wcol, done_flag, busy_eff};
            A_SPDR:  rdata = {24'd0, rx_data};
            default: rdata = {24'd0, spdiv};
        endcase
    end
    assign PRDATA = rdata;
endmodule
