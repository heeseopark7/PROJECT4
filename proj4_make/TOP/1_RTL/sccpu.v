// Single-cycle MIPS CPU (Yamin Li ch.5 style, 20 integer instructions)
// + stall input: while stall=1 the PC and register file are frozen (OI-2)
module sccpu (
    input         clk,
    input         clrn,
    input  [31:0] inst,
    input  [31:0] memout,   // read data (RAM or APB PRDATA)
    input         stall,
    output reg [31:0] pc,
    output        wmem,     // store
    output [31:0] aluout,   // data address / ALU result
    output [31:0] data      // store data
);
    wire [5:0]  op    = inst[31:26];
    wire [4:0]  rs    = inst[25:21];
    wire [4:0]  rt    = inst[20:16];
    wire [4:0]  rd    = inst[15:11];
    wire [4:0]  sa    = inst[10:6];
    wire [5:0]  func  = inst[5:0];
    wire [15:0] imm   = inst[15:0];
    wire [25:0] jaddr = inst[25:0];

    // decode
    wire rtype = (op == 6'b000000);
    wire i_add  = rtype & (func == 6'b100000);
    wire i_sub  = rtype & (func == 6'b100010);
    wire i_and  = rtype & (func == 6'b100100);
    wire i_or   = rtype & (func == 6'b100101);
    wire i_xor  = rtype & (func == 6'b100110);
    wire i_sll  = rtype & (func == 6'b000000);
    wire i_srl  = rtype & (func == 6'b000010);
    wire i_sra  = rtype & (func == 6'b000011);
    wire i_jr   = rtype & (func == 6'b001000);
    wire i_addi = (op == 6'b001000);
    wire i_andi = (op == 6'b001100);
    wire i_ori  = (op == 6'b001101);
    wire i_xori = (op == 6'b001110);
    wire i_lw   = (op == 6'b100011);
    wire i_sw   = (op == 6'b101011);
    wire i_beq  = (op == 6'b000100);
    wire i_bne  = (op == 6'b000101);
    wire i_lui  = (op == 6'b001111);
    wire i_j    = (op == 6'b000010);
    wire i_jal  = (op == 6'b000011);

    wire shift_op = i_sll | i_srl | i_sra;
    wire zext_imm = i_andi | i_ori | i_xori;
    wire i_alu_r  = i_add | i_sub | i_and | i_or | i_xor | shift_op;
    wire wreg     = i_alu_r | i_addi | i_andi | i_ori | i_xori | i_lw | i_lui | i_jal;
    assign wmem   = i_sw;

    // register file
    reg [31:0] regs [1:31];
    wire [31:0] qa = (rs == 0) ? 32'd0 : regs[rs];
    wire [31:0] qb = (rt == 0) ? 32'd0 : regs[rt];

    wire [31:0] imm_ext = zext_imm ? {16'd0, imm} : {{16{imm[15]}}, imm};

    // ALU
    wire [31:0] a = shift_op ? {27'd0, sa} : qa;
    wire [31:0] b = (i_alu_r) ? qb : imm_ext;
    reg  [31:0] alu;
    always @(*) begin
        if (i_sub)                          alu = a - b;
        else if (i_and | i_andi)            alu = a & b;
        else if (i_or  | i_ori)             alu = a | b;
        else if (i_xor | i_xori)            alu = a ^ b;
        else if (i_sll)                     alu = qb << sa;
        else if (i_srl)                     alu = qb >> sa;
        else if (i_sra)                     alu = $signed(qb) >>> sa;
        else if (i_lui)                     alu = {imm, 16'd0};
        else                                alu = a + b;   // add, addi, lw, sw
    end
    assign aluout = alu;
    assign data   = qb;

    // next PC
    wire [31:0] p4 = pc + 32'd4;
    wire take_br   = (i_beq & (qa == qb)) | (i_bne & (qa != qb));
    wire [31:0] br_target = p4 + {{14{imm[15]}}, imm, 2'b00};
    wire [31:0] npc = i_jr            ? qa :
                      (i_j | i_jal)   ? {p4[31:28], jaddr, 2'b00} :
                      take_br         ? br_target : p4;

    // write-back
    wire [4:0]  wn = i_jal ? 5'd31 : (i_alu_r ? rd : rt);
    wire [31:0] wd = i_jal ? p4 : (i_lw ? memout : alu);

    integer i;
    always @(posedge clk or negedge clrn) begin
        if (!clrn) begin
            pc <= 32'd0;
            for (i = 1; i < 32; i = i + 1) regs[i] <= 32'd0;
        end else if (!stall) begin
            pc <= npc;
            if (wreg && wn != 0) regs[wn] <= wd;
        end
    end
endmodule
