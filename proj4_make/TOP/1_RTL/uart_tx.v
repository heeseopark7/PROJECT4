// UART transmitter. Frame (LSB first): start, data[n], [parity], stop x1/2
module uart_tx (
    input        clk,
    input        rstn,
    input        tick,       // 16x tick
    input        en,         // UARTEN & TXE
    input  [1:0] wlen,       // 00=5 .. 11=8 bits
    input        pen,
    input        eps,        // even parity select
    input        stp2,
    input  [7:0] din,
    input        empty,      // TX FIFO empty
    output       pop,
    output reg   txd,
    output       busy
);
    reg [11:0] sh;
    reg [3:0]  nbits, bcnt;
    reg [3:0]  tcnt;
    reg        run;
    assign busy = run;

    wire [3:0] nd = 4'd5 + {2'b0, wlen};
    reg  [7:0] dm;
    always @(*) case (wlen) 2'd0: dm = din & 8'h1F; 2'd1: dm = din & 8'h3F;
                            2'd2: dm = din & 8'h7F; default: dm = din; endcase
    wire par = eps ? ^dm : ~^dm;     // even: parity makes total ones even

    reg [10:0] body;
    integer k;
    always @(*) begin
        body = {11{1'b1}};
        for (k = 0; k < 8; k = k + 1) if (k < nd) body[k] = dm[k];
        if (pen) body[nd] = par;
    end

    assign pop = ~run & en & ~empty;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            run <= 0; txd <= 1'b1; sh <= 12'hFFF; bcnt <= 0; tcnt <= 0; nbits <= 0;
        end else if (!run) begin
            txd <= 1'b1;
            if (pop) begin
                // sh[0]=start, then data, parity; remaining upper bits (stop) are 1
                sh    <= {body, 1'b0};
                nbits <= 4'd1 + nd + {3'b0, pen} + (stp2 ? 4'd2 : 4'd1);
                bcnt  <= 0; tcnt <= 0; run <= 1;
                txd   <= 1'b0;                       // start bit
            end
        end else if (tick) begin
            if (tcnt == 4'd15) begin
                tcnt <= 0;
                if (bcnt == nbits - 1) begin run <= 0; txd <= 1'b1; end
                else begin
                    bcnt <= bcnt + 1;
                    sh   <= {1'b1, sh[11:1]};
                    txd  <= sh[1];
                end
            end else tcnt <= tcnt + 1;
        end
    end
endmodule
