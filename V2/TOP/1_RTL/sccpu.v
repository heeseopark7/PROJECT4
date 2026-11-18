//==============================================================================
// Module  : sccpu
// Purpose : Single-cycle MIPS CPU (Yamin Li, ch.5 style). One instruction per
//           clock. 20 integer instructions:
//             R-type : add sub and or xor sll srl sra jr
//             I-type : addi andi ori xori lw sw beq bne lui
//             J-type : j jal
//           No delay slot, no exceptions, no alignment check.
//           Extra input i_stall (spec OI-2): while 1, the PC and the register
//           file keep their values, so the instruction is held.
//
// Reset   : PC = 0, all registers = 0.
//==============================================================================

`timescale 1ns / 1ps

module sccpu (
                    clk                                 ,
                    nRst                                ,
                    i_inst                              ,
                    i_memout                            ,
                    i_stall                             ,
                    o_pc                                ,
                    o_wmem                              ,
                    o_aluout                            ,
                    o_data
);

//------------------------------------------------------------------------------
// External ports
//------------------------------------------------------------------------------
input               clk                                 ;   // clock
input               nRst                                ;   // reset, active-LOW, async assert
input   [31:0]      i_inst                              ;   // current instruction (from scinstmem)
input   [31:0]      i_memout                            ;   // load data (RAM or APB read data)
input               i_stall                             ;   // 1 = freeze PC and register file
output  [31:0]      o_pc                                ;   // instruction address
output              o_wmem                              ;   // store (sw) strobe
output  [31:0]      o_aluout                            ;   // data address / ALU result
output  [31:0]      o_data                              ;   // store data (rt)

//------------------------------------------------------------------------------
// Internal registers
//------------------------------------------------------------------------------
reg     [31:0]      r_pc                                ;   // program counter
reg     [31:0]      r_regs [1:31]                       ;   // register file ($0 is constant 0)
reg     [31:0]      r_alu                               ;   // ALU result (combinational)
integer             i                                   ;   // reset loop index

//------------------------------------------------------------------------------
// Internal wires
//------------------------------------------------------------------------------
wire    [5:0]       w_op                                ;   // opcode
wire    [4:0]       w_rs                                ;   // source register 1
wire    [4:0]       w_rt                                ;   // source register 2 / I-type destination
wire    [4:0]       w_rd                                ;   // R-type destination
wire    [4:0]       w_sa                                ;   // shift amount
wire    [5:0]       w_func                              ;   // R-type function code
wire    [15:0]      w_imm                               ;   // 16-bit immediate
wire    [25:0]      w_jaddr                             ;   // 26-bit jump target field
wire                w_rtype                             ;   // opcode == 0
wire                w_add                               ;   // decoded instructions
wire                w_sub                               ;
wire                w_and                               ;
wire                w_or                                ;
wire                w_xor                               ;
wire                w_sll                               ;
wire                w_srl                               ;
wire                w_sra                               ;
wire                w_jr                                ;
wire                w_addi                              ;
wire                w_andi                              ;
wire                w_ori                               ;
wire                w_xori                              ;
wire                w_lw                                ;
wire                w_sw                                ;
wire                w_beq                               ;
wire                w_bne                               ;
wire                w_lui                               ;
wire                w_j                                 ;
wire                w_jal                               ;
wire                w_shift                             ;   // sll / srl / sra
wire                w_zext                              ;   // immediate is zero-extended (andi/ori/xori)
wire                w_alu_r                             ;   // R-type ALU operation (result goes to rd)
wire                w_wreg                              ;   // writes a register
wire    [31:0]      w_qa                                ;   // register read port A (rs)
wire    [31:0]      w_qb                                ;   // register read port B (rt)
wire    [31:0]      w_imm_ext                           ;   // extended immediate
wire    [31:0]      w_a                                 ;   // ALU input A
wire    [31:0]      w_b                                 ;   // ALU input B
wire    [31:0]      w_p4                                ;   // PC + 4
wire                w_take_br                           ;   // branch taken
wire    [31:0]      w_br_target                         ;   // branch target
wire    [31:0]      w_npc                               ;   // next PC
wire    [4:0]       w_wn                                ;   // write register number
wire    [31:0]      w_wd                                ;   // write register data

//------------------------------------------------------------------------------
// Instruction fields
//------------------------------------------------------------------------------
assign  w_op    = i_inst[31:26] ;
assign  w_rs    = i_inst[25:21] ;
assign  w_rt    = i_inst[20:16] ;
assign  w_rd    = i_inst[15:11] ;
assign  w_sa    = i_inst[10:6]  ;
assign  w_func  = i_inst[5:0]   ;
assign  w_imm   = i_inst[15:0]  ;
assign  w_jaddr = i_inst[25:0]  ;

//------------------------------------------------------------------------------
// Decoder
//------------------------------------------------------------------------------
assign  w_rtype = (w_op == 6'b000000)                       ;
assign  w_add   = w_rtype & (w_func == 6'b100000)           ;
assign  w_sub   = w_rtype & (w_func == 6'b100010)           ;
assign  w_and   = w_rtype & (w_func == 6'b100100)           ;
assign  w_or    = w_rtype & (w_func == 6'b100101)           ;
assign  w_xor   = w_rtype & (w_func == 6'b100110)           ;
assign  w_sll   = w_rtype & (w_func == 6'b000000)           ;
assign  w_srl   = w_rtype & (w_func == 6'b000010)           ;
assign  w_sra   = w_rtype & (w_func == 6'b000011)           ;
assign  w_jr    = w_rtype & (w_func == 6'b001000)           ;
assign  w_addi  = (w_op == 6'b001000)                       ;
assign  w_andi  = (w_op == 6'b001100)                       ;
assign  w_ori   = (w_op == 6'b001101)                       ;
assign  w_xori  = (w_op == 6'b001110)                       ;
assign  w_lw    = (w_op == 6'b100011)                       ;
assign  w_sw    = (w_op == 6'b101011)                       ;
assign  w_beq   = (w_op == 6'b000100)                       ;
assign  w_bne   = (w_op == 6'b000101)                       ;
assign  w_lui   = (w_op == 6'b001111)                       ;
assign  w_j     = (w_op == 6'b000010)                       ;
assign  w_jal   = (w_op == 6'b000011)                       ;

assign  w_shift = w_sll | w_srl | w_sra                     ;
assign  w_zext  = w_andi | w_ori | w_xori                   ;
assign  w_alu_r = w_add | w_sub | w_and | w_or | w_xor | w_shift ;
assign  w_wreg  = w_alu_r | w_addi | w_andi | w_ori | w_xori | w_lw | w_lui | w_jal ;

assign  o_wmem  = w_sw                                      ;

//------------------------------------------------------------------------------
// Register file read ($0 always reads 0)
//------------------------------------------------------------------------------
assign  w_qa    = (w_rs == 5'd0) ? 32'd0 : r_regs[w_rs]     ;
assign  w_qb    = (w_rt == 5'd0) ? 32'd0 : r_regs[w_rt]     ;

//------------------------------------------------------------------------------
// ALU
//   shift amount comes from sa, shifted value is rt
//   I-type uses the extended immediate as input B
//------------------------------------------------------------------------------
assign  w_imm_ext = w_zext ? {16'd0, w_imm} : {{16{w_imm[15]}}, w_imm} ;
assign  w_a       = w_shift ? {27'd0, w_sa} : w_qa          ;
assign  w_b       = w_alu_r ? w_qb : w_imm_ext              ;

always @(*) begin
    if      (w_sub)             r_alu   =   w_a - w_b               ;
    else if (w_and | w_andi)    r_alu   =   w_a & w_b               ;
    else if (w_or  | w_ori )    r_alu   =   w_a | w_b               ;
    else if (w_xor | w_xori)    r_alu   =   w_a ^ w_b               ;
    else if (w_sll)             r_alu   =   w_qb << w_sa            ;
    else if (w_srl)             r_alu   =   w_qb >> w_sa            ;
    else if (w_sra)             r_alu   =   $signed(w_qb) >>> w_sa  ;
    else if (w_lui)             r_alu   =   {w_imm, 16'd0}          ;
    else                        r_alu   =   w_a + w_b               ;   // add, addi, lw, sw
end

assign  o_aluout = r_alu        ;
assign  o_data   = w_qb         ;

//------------------------------------------------------------------------------
// Next PC
//------------------------------------------------------------------------------
assign  w_p4        = r_pc + 32'd4                                          ;
assign  w_take_br   = (w_beq & (w_qa == w_qb)) | (w_bne & (w_qa != w_qb))   ;
assign  w_br_target = w_p4 + {{14{w_imm[15]}}, w_imm, 2'b00}                ;
assign  w_npc       = w_jr              ? w_qa                              :
                      (w_j | w_jal)     ? {w_p4[31:28], w_jaddr, 2'b00}     :
                      w_take_br         ? w_br_target                       : w_p4 ;

assign  o_pc        = r_pc                                                  ;

//------------------------------------------------------------------------------
// Write-back selection
//------------------------------------------------------------------------------
assign  w_wn = w_jal ? 5'd31 : (w_alu_r ? w_rd : w_rt)      ;
assign  w_wd = w_jal ? w_p4  : (w_lw ? i_memout : r_alu)    ;

//------------------------------------------------------------------------------
// PC and register file update (frozen while i_stall = 1)
//------------------------------------------------------------------------------
always @(posedge clk or negedge nRst) begin
    if (!nRst)  begin
        r_pc        <=  32'd0           ;
        for (i = 1; i < 32; i = i + 1)  begin
            r_regs[i]   <=  32'd0       ;
        end
    end
    else if (!i_stall)  begin
        r_pc        <=  w_npc           ;
        if (w_wreg && (w_wn != 5'd0))   begin
            r_regs[w_wn]    <=  w_wd    ;
        end
    end
end

endmodule
