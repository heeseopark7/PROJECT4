//==============================================================================
// Module  : add32_ks
// Purpose : 32-bit Kogge-Stone parallel-prefix adder with carry-in.
//           Replaces the "+" / "-" operators of the ALU in sccpu (V3 change).
//           sub is done outside as a + ~b + 1 (b inverted, cin = 1).
//
// Structure:
//   1) bit level   : g[i] = a[i] & b[i], p[i] = a[i] ^ b[i]
//                    cin is folded into bit 0 (g[0] |= p[0] & cin)
//   2) prefix tree : 5 stages, distance 1, 2, 4, 8, 16
//                    G = G_hi | (P_hi & G_lo), P = P_hi & P_lo
//   3) sum         : sum[i] = p[i] ^ carry into bit i
//                    carry into bit 0 is cin, into bit i is G[i-1] of the tree
//
// Ports:
//   a, b : operands
//   cin  : carry in (1 for subtraction)
//   sum  : a + b + cin (carry out is not used)
//==============================================================================
module add32_ks (
    input  [31:0] a   ,
    input  [31:0] b   ,
    input         cin ,
    output [31:0] sum
);

//------------------------------------------------------------------------------
// Stage 0 : bit-level generate / propagate
//------------------------------------------------------------------------------
wire [31:0] w_p0 ;
wire [31:0] w_g0 ;

assign w_p0 = a ^ b ;
assign w_g0 = {a[31:1] & b[31:1], (a[0] & b[0]) | (w_p0[0] & cin)} ;

//------------------------------------------------------------------------------
// Stage 1..5 : Kogge-Stone prefix tree (distance 1, 2, 4, 8, 16)
//------------------------------------------------------------------------------
wire [31:0] w_g1, w_p1 ;
wire [31:0] w_g2, w_p2 ;
wire [31:0] w_g3, w_p3 ;
wire [31:0] w_g4, w_p4 ;
wire [31:0] w_g5 ;

assign w_g1 = w_g0 | (w_p0 & {w_g0[30:0], 1'b0}) ;
assign w_p1 =         w_p0 & {w_p0[30:0], 1'b0}  ;

assign w_g2 = w_g1 | (w_p1 & {w_g1[29:0], 2'b0}) ;
assign w_p2 =         w_p1 & {w_p1[29:0], 2'b0}  ;

assign w_g3 = w_g2 | (w_p2 & {w_g2[27:0], 4'b0}) ;
assign w_p3 =         w_p2 & {w_p2[27:0], 4'b0}  ;

assign w_g4 = w_g3 | (w_p3 & {w_g3[23:0], 8'b0}) ;
assign w_p4 =         w_p3 & {w_p3[23:0], 8'b0}  ;

assign w_g5 = w_g4 | (w_p4 & {w_g4[15:0], 16'b0}) ;   // last stage, P not needed

//------------------------------------------------------------------------------
// Sum : carry into bit i is w_g5[i-1], carry into bit 0 is cin
//------------------------------------------------------------------------------
assign sum = w_p0 ^ {w_g5[30:0], cin} ;

endmodule
