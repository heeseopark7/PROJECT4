//==============================================================================
// Module  : spi_slave
// Purpose : SPI slave, 8 bits per byte, MSB first, modes 0~3, full duplex.
//           Works on the system clock: SCLK, CS_N and MOSI are asynchronous
//           inputs and pass a 2-FF synchronizer (delay about 3~4 clocks), so
//           SCLK must be slower than clk by a safe margin (>= 8x).
//           CS_N high aborts a running frame and resets the bit counter.
//
//           FSM : IDLE -> SHIFT (8 bits = 16 SCLK edges) -> DONE -> WAIT -> LOAD
//                  -> (SHIFT | IDLE)
//           A new byte starts while CS_N stays low (back-to-back bytes).
//           i_tx_data is the reply byte. It is read once per byte (at IDLE exit
//           and in LOAD). WAIT gives the user logic one clock after o_rx_valid
//           to update i_tx_data (for example an echo of the last received byte).
//==============================================================================

`timescale 1ns / 1ps

module spi_slave (
                    clk                                 ,
                    nRst                                ,
                    i_cpol                              ,
                    i_cpha                              ,
                    i_sclk                              ,
                    i_cs_n                              ,
                    i_mosi                              ,
                    o_miso                              ,
                    i_tx_data                           ,
                    o_rx_data                           ,
                    o_rx_valid
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input               clk                                 ;   // system clock
input               nRst                                ;   // reset, active-LOW, async assert
input               i_cpol                              ;   // clock polarity (idle level of SCLK)
input               i_cpha                              ;   // clock phase
input               i_sclk                              ;   // serial clock from the master (asynchronous)
input               i_cs_n                              ;   // chip select, active-LOW (asynchronous)
input               i_mosi                              ;   // master out, slave in (asynchronous)
output              o_miso                              ;   // master in, slave out
input   [7:0]       i_tx_data                           ;   // reply byte
output  [7:0]       o_rx_data                           ;   // received byte (valid with o_rx_valid)
output              o_rx_valid                          ;   // received byte ready, 1-clock pulse

//------------------------------------------------------------------------------
// Parameters (FSM states)
//------------------------------------------------------------------------------
localparam [2:0]    S_IDLE  = 3'd0                      ;
localparam [2:0]    S_SHIFT = 3'd1                      ;
localparam [2:0]    S_DONE  = 3'd2                      ;
localparam [2:0]    S_WAIT  = 3'd3                      ;
localparam [2:0]    S_LOAD  = 3'd4                      ;

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
reg     [2:0]       r_state                             ;   // FSM state
reg     [1:0]       r_sclk_s                            ;   // SCLK synchronizer
reg                 r_sclk_d                            ;   // SCLK delayed by one clock (edge detect)
reg     [1:0]       r_cs_s                              ;   // CS_N synchronizer
reg     [1:0]       r_mosi_s                            ;   // MOSI synchronizer
reg                 r_miso                              ;   // MISO output
reg     [7:0]       r_rx_data                           ;   // received byte
reg                 r_rx_valid                          ;   // received byte ready
reg     [7:0]       r_tx_sr                             ;   // transmit shift register
reg     [7:0]       r_rx_sr                             ;   // receive shift register
reg     [4:0]       r_ecnt                              ;   // SCLK edges in this byte (0..16)

//------------------------------------------------------------------------------
// Internal wires
//------------------------------------------------------------------------------
wire                w_sclk_q                            ;   // synchronized SCLK
wire                w_cs_q                              ;   // synchronized CS_N
wire                w_mosi_q                            ;   // synchronized MOSI
wire                w_rise                              ;   // SCLK rising edge
wire                w_fall                              ;   // SCLK falling edge
wire                w_edge                              ;   // any SCLK edge
wire                w_leading                           ;   // edge that leaves the idle level
wire                w_sample_edge                       ;   // edge where MOSI is sampled
wire                w_update_edge                       ;   // edge where MISO is updated

assign  w_sclk_q        = r_sclk_s[1]                           ;
assign  w_cs_q          = r_cs_s[1]                             ;
assign  w_mosi_q        = r_mosi_s[1]                           ;
assign  w_rise          = ~r_sclk_d &  w_sclk_q                 ;
assign  w_fall          =  r_sclk_d & ~w_sclk_q                 ;
assign  w_edge          = w_rise | w_fall                       ;
assign  w_leading       = i_cpol ? w_fall : w_rise              ;
assign  w_sample_edge   = w_edge & (i_cpha ? ~w_leading : w_leading) ;
assign  w_update_edge   = w_edge & (i_cpha ?  w_leading : ~w_leading) ;

assign  o_miso          = r_miso                                ;
assign  o_rx_data       = r_rx_data                             ;
assign  o_rx_valid      = r_rx_valid                            ;

//------------------------------------------------------------------------------
// Input synchronizers (reset to the idle levels: SCLK low, CS_N high)
//------------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
    if (!nRst)  begin
        r_sclk_s    <=  2'b00           ;
        r_sclk_d    <=  1'b0            ;
        r_cs_s      <=  2'b11           ;
        r_mosi_s    <=  2'b00           ;
    end
    else    begin
        r_sclk_s    <=  {r_sclk_s[0], i_sclk}   ;
        r_sclk_d    <=  w_sclk_q                ;
        r_cs_s      <=  {r_cs_s[0],   i_cs_n}   ;
        r_mosi_s    <=  {r_mosi_s[0], i_mosi}   ;
    end
end

//------------------------------------------------------------------------------
// Transfer FSM
//   Start of a byte (IDLE exit and LOAD): store i_tx_data; with CPHA=0 the MSB
//   goes to MISO at once, with CPHA=1 it goes out at the first leading edge.
//------------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
    if (!nRst)  begin
        r_state     <=  S_IDLE          ;
        r_miso      <=  1'b0            ;
        r_rx_data   <=  8'd0            ;
        r_rx_valid  <=  1'b0            ;
        r_tx_sr     <=  8'd0            ;
        r_rx_sr     <=  8'd0            ;
        r_ecnt      <=  5'd0            ;
    end
    else    begin
        r_rx_valid  <=  1'b0            ;

        case (r_state)
        S_IDLE  :   begin
            r_ecnt      <=  5'd0        ;
            if (!w_cs_q)    begin
                if (i_cpha) begin
                    r_tx_sr     <=  i_tx_data                   ;
                end
                else    begin
                    r_miso      <=  i_tx_data[7]                ;
                    r_tx_sr     <=  {i_tx_data[6:0], 1'b0}      ;
                end
                r_state     <=  S_SHIFT ;
            end
        end

        S_SHIFT :   begin
            if (w_cs_q) begin
                r_state     <=  S_IDLE      ;       // frame aborted, clear the bit counter
                r_ecnt      <=  5'd0        ;
            end
            else if (w_edge)    begin
                r_ecnt      <=  r_ecnt + 5'd1   ;
                if (w_sample_edge)  begin
                    r_rx_sr     <=  {r_rx_sr[6:0], w_mosi_q}    ;
                end
                if (w_update_edge && (r_ecnt != 5'd15)) begin
                    r_miso      <=  r_tx_sr[7]                  ;
                    r_tx_sr     <=  {r_tx_sr[6:0], 1'b0}        ;
                end
                if (r_ecnt == 5'd15)    begin
                    r_state     <=  S_DONE  ;
                end
            end
        end

        S_DONE  :   begin
            r_rx_data   <=  r_rx_sr     ;
            r_rx_valid  <=  1'b1        ;
            r_state     <=  S_WAIT      ;
        end

        S_WAIT  :   begin
            r_state     <=  S_LOAD      ;
        end

        S_LOAD  :   begin
            if (w_cs_q) begin
                r_state     <=  S_IDLE      ;
                r_ecnt      <=  5'd0        ;
            end
            else    begin                           // CS_N still low: next byte
                r_ecnt      <=  5'd0        ;
                if (i_cpha) begin
                    r_tx_sr     <=  i_tx_data                   ;
                end
                else    begin
                    r_miso      <=  i_tx_data[7]                ;
                    r_tx_sr     <=  {i_tx_data[6:0], 1'b0}      ;
                end
                r_state     <=  S_SHIFT ;
            end
        end

        default :   begin
            r_state     <=  S_IDLE      ;
        end
        endcase
    end
end

endmodule
