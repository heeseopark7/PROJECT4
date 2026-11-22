//==============================================================================
// Module  : spi_master
// Purpose : SPI master shift engine. 8 bits, MSB first, modes 0~3, full duplex.
//           FSM : IDLE -> START (1 T_h) -> DATA (16 edges) -> STOP (1 T_h) -> IDLE
//           One byte takes 18 x T_h (the busy period). The chip select is not
//           driven here (SPCR.CS in spi_regs).
//
//           Edge behavior (r_ecnt even = leading edge, odd = trailing edge)
//                       CPHA=0                   CPHA=1
//             leading   sample MISO              update MOSI (MSB at 1st edge)
//             trailing  update MOSI (not last)   sample MISO
//
//           MISO passes a 2-FF synchronizer. i_loop = 1 feeds MOSI back into it
//           instead of the external MISO pin.
//==============================================================================

`timescale 1ns / 1ps

module spi_master (
                    clk                                 ,
                    nRst                                ,
                    i_tick                              ,
                    i_start                             ,
                    i_tx_data                           ,
                    i_cpol                              ,
                    i_cpha                              ,
                    i_loop                              ,
                    o_busy                              ,
                    o_done                              ,
                    o_rx_data                           ,
                    o_sclk                              ,
                    o_mosi                              ,
                    i_miso
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input               clk                                 ;   // clock (PCLK)
input               nRst                                ;   // reset, active-LOW, async assert
input               i_tick                              ;   // half-period tick from sclk_gen
input               i_start                             ;   // 1-clock start pulse (SPDR write, ACCESS phase)
input   [7:0]       i_tx_data                           ;   // byte to send
input               i_cpol                              ;   // clock polarity (idle level of SCLK)
input               i_cpha                              ;   // clock phase
input               i_loop                              ;   // 1 = internal loopback (MOSI -> MISO)
output              o_busy                              ;   // transfer in progress
output              o_done                              ;   // transfer finished, 1-clock pulse
output  [7:0]       o_rx_data                           ;   // received byte (valid at done, held until next done)
output              o_sclk                              ;   // serial clock
output              o_mosi                              ;   // master out, slave in
input               i_miso                              ;   // master in, slave out (asynchronous)

//------------------------------------------------------------------------------
// Parameters (FSM states)
//------------------------------------------------------------------------------
localparam [1:0]    S_IDLE  = 2'd0                      ;
localparam [1:0]    S_START = 2'd1                      ;
localparam [1:0]    S_DATA  = 2'd2                      ;
localparam [1:0]    S_STOP  = 2'd3                      ;

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
reg     [1:0]       r_state                             ;   // FSM state
reg                 r_busy                              ;   // transfer in progress
reg                 r_done                              ;   // done pulse
reg     [7:0]       r_rx_data                           ;   // received byte
reg                 r_sclk                              ;   // SCLK output
reg                 r_mosi                              ;   // MOSI output
reg                 r_cpol                              ;   // mode captured at start
reg                 r_cpha                              ;   // mode captured at start
reg     [7:0]       r_tx_sr                             ;   // transmit shift register
reg     [7:0]       r_rx_sr                             ;   // receive shift register
reg     [3:0]       r_ecnt                              ;   // 0..15, SCLK edges made so far
reg                 r_miso_s1                           ;   // synchronizer, 1st stage
reg                 r_miso_s2                           ;   // synchronizer, 2nd stage

//------------------------------------------------------------------------------
// Internal wires
//------------------------------------------------------------------------------
wire                w_miso_in                           ;   // MISO source (pin or loopback)
wire                w_leading                           ;   // the edge made by this tick is a leading edge

assign  w_miso_in   = i_loop ? r_mosi : i_miso          ;
assign  w_leading   = ~r_ecnt[0]                        ;

assign  o_busy      = r_busy                            ;
assign  o_done      = r_done                            ;
assign  o_rx_data   = r_rx_data                         ;
assign  o_sclk      = r_sclk                            ;
assign  o_mosi      = r_mosi                            ;

//------------------------------------------------------------------------------
// MISO 2-FF synchronizer
//------------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
    if (!nRst)  begin
        r_miso_s1   <=  1'b0            ;
        r_miso_s2   <=  1'b0            ;
    end
    else    begin
        r_miso_s1   <=  w_miso_in       ;
        r_miso_s2   <=  r_miso_s1       ;
    end
end

//------------------------------------------------------------------------------
// Transfer FSM
//------------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
    if (!nRst)  begin
        r_state     <=  S_IDLE          ;
        r_busy      <=  1'b0            ;
        r_done      <=  1'b0            ;
        r_rx_data   <=  8'd0            ;
        r_sclk      <=  1'b0            ;
        r_mosi      <=  1'b0            ;
        r_cpol      <=  1'b0            ;
        r_cpha      <=  1'b0            ;
        r_tx_sr     <=  8'd0            ;
        r_rx_sr     <=  8'd0            ;
        r_ecnt      <=  4'd0            ;
    end
    else    begin
        r_done      <=  1'b0            ;

        case (r_state)
        S_IDLE  :   begin
            r_sclk      <=  i_cpol          ;       // idle level = CPOL
            if (i_start)    begin
                r_state     <=  S_START     ;
                r_busy      <=  1'b1        ;
                r_cpol      <=  i_cpol      ;
                r_cpha      <=  i_cpha      ;
                r_ecnt      <=  4'd0        ;
                if (i_cpha) begin
                    r_tx_sr     <=  i_tx_data                   ;   // MSB goes out at the first leading edge
                end
                else    begin
                    r_mosi      <=  i_tx_data[7]                ;   // prepare MSB during START
                    r_tx_sr     <=  {i_tx_data[6:0], 1'b0}      ;
                end
            end
        end

        S_START :   begin
            if (i_tick) begin
                r_state     <=  S_DATA      ;
            end
        end

        S_DATA  :   begin
            if (i_tick) begin
                r_sclk      <=  ~r_sclk         ;
                r_ecnt      <=  r_ecnt + 4'd1   ;
                if (r_cpha == w_leading)    begin
                    // (CPHA=0, trailing) or (CPHA=1, leading) -> update MOSI
                    // no update on the last (16th) edge of CPHA=0
                    if (r_ecnt != 4'd15)    begin
                        r_mosi      <=  r_tx_sr[7]              ;
                        r_tx_sr     <=  {r_tx_sr[6:0], 1'b0}    ;
                    end
                end
                else    begin
                    // (CPHA=0, leading) or (CPHA=1, trailing) -> sample MISO
                    r_rx_sr     <=  {r_rx_sr[6:0], r_miso_s2}   ;
                end
                if (r_ecnt == 4'd15)    begin
                    r_state     <=  S_STOP  ;
                end
            end
        end

        S_STOP  :   begin
            if (i_tick) begin
                r_rx_data   <=  r_rx_sr     ;
                r_busy      <=  1'b0        ;
                r_done      <=  1'b1        ;
                r_state     <=  S_IDLE      ;
            end
        end

        default :   begin
            r_state     <=  S_IDLE          ;
        end
        endcase
    end
end

endmodule
