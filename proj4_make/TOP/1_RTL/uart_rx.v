// UART receiver, 16x oversampling, samples mid-bit. Output {PE,FE} flags with data.
module uart_rx (
    input        clk,
    input        rstn,
    input        tick,
    input        en,         // UARTEN & RXE
    input  [1:0] wlen,
    input        pen,
    input        eps,
    input        rxd,        // already synchronized
    output reg   valid,      // 1-clk pulse
    output reg [7:0] dout,
    output reg   fe,
    output reg   pe,
    output       busy
);
    localparam IDLE = 0, START = 1, DATA = 2, PAR = 3, STOP = 4;
    reg [2:0] st;
    reg [3:0] tcnt;
    reg [2:0] bidx;
    reg [7:0] sh;
    reg       perr;
    assign busy = (st != IDLE);

    reg [7:0] aligned;
    wire last_bit = (bidx == {1'b0, wlen} + 3'd4);   // word length - 1

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            st <= IDLE; tcnt <= 0; bidx <= 0; sh <= 0; valid <= 0; dout <= 0;
            fe <= 0; pe <= 0; perr <= 0;
        end else begin
            valid <= 1'b0;
            case (st)
            IDLE: if (en && !rxd) begin st <= START; tcnt <= 0; end
            START: if (tick) begin
                if (tcnt == 4'd7) begin
                    if (!rxd) begin st <= DATA; tcnt <= 0; bidx <= 0; sh <= 0; end
                    else st <= IDLE;               // glitch
                end else tcnt <= tcnt + 1;
            end
            DATA: if (tick) begin
                if (tcnt == 4'd15) begin
                    tcnt <= 0;
                    sh <= {rxd, sh[7:1]};
                    bidx <= bidx + 1;
                    if (last_bit) st <= pen ? PAR : STOP;
                end else tcnt <= tcnt + 1;
            end
            PAR: if (tick) begin
                if (tcnt == 4'd15) begin
                    tcnt <= 0;
                    // right-align data, compute expected parity
                    perr <= (eps ? ^aligned : ~^aligned) != rxd;
                    st <= STOP;
                end else tcnt <= tcnt + 1;
            end
            STOP: if (tick) begin
                if (tcnt == 4'd15) begin
                    tcnt  <= 0;
                    dout  <= aligned;
                    fe    <= ~rxd;
                    pe    <= pen & perr;
                    valid <= 1'b1;
                    st    <= IDLE;
                end else tcnt <= tcnt + 1;
            end
            endcase
        end
    end

    // sh shifts right with newest bit at [7]; align to LSB for <8-bit words
    always @(*) case (wlen)
        2'd0: aligned = {3'b0, sh[7:3]};
        2'd1: aligned = {2'b0, sh[7:2]};
        2'd2: aligned = {1'b0, sh[7:1]};
        default: aligned = sh;
    endcase
endmodule
