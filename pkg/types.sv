package pcmux;
typedef enum bit [1:0] {
    pc_plus4  = 2'b00
    ,alu_out  = 2'b01
    ,alu_mod2 = 2'b10
} pcmux_sel_t;
endpackage

package marmux;
typedef enum bit {
    pc_out = 1'b0
    ,alu_out = 1'b1
} marmux_sel_t;
endpackage

package cmpmux;
typedef enum bit {
    rs2_out = 1'b0
    ,i_imm = 1'b1
} cmpmux_sel_t;
endpackage

package alumux;
typedef enum bit {
    rs1_out = 1'b0
    ,pc_out = 1'b1
} alumux1_sel_t;

typedef enum bit [2:0] {
    i_imm    = 3'b000
    ,u_imm   = 3'b001
    ,b_imm   = 3'b010
    ,s_imm   = 3'b011
    ,j_imm   = 3'b100
    ,rs2_out = 3'b101
} alumux2_sel_t;
endpackage

package regfilemux;
typedef enum bit [3:0] {
    alu_out   = 4'b0000
    ,br_en    = 4'b0001
    ,u_imm    = 4'b0010
    ,lw       = 4'b0011
    ,pc_plus4 = 4'b0100
    ,lb        = 4'b0101
    ,lbu       = 4'b0110  // unsigned byte
    ,lh        = 4'b0111
    ,lhu       = 4'b1000  // unsigned halfword
} regfilemux_sel_t;
endpackage



package rv32i_types;
// Mux types are in their own packages to prevent identiier collisions
// e.g. pcmux::pc_plus4 and regfilemux::pc_plus4 are seperate identifiers
// for seperate enumerated types
import pcmux::*;
import marmux::*;
import cmpmux::*;
import alumux::*;
import regfilemux::*;

typedef logic [31:0] rv32i_word;
typedef logic [4:0] rv32i_reg;
typedef logic [3:0] rv32i_mem_wmask;

typedef enum bit [6:0] {
    op_lui   = 7'b0110111, //load upper immediate (U type)
    op_auipc = 7'b0010111, //add upper immediate PC (U type)
    op_jal   = 7'b1101111, //jump and link (J type)
    op_jalr  = 7'b1100111, //jump and link register (I type)
    op_br    = 7'b1100011, //branch (B type)
    op_load  = 7'b0000011, //load (I type)
    op_store = 7'b0100011, //store (S type)
    op_imm   = 7'b0010011, //arith ops with register/immediate operands (I type)
    op_reg   = 7'b0110011, //arith ops with register operands (R type)
    op_csr   = 7'b1110011  //control and status register (I type)
} rv32i_opcode;

typedef enum bit [2:0] {
    beq  = 3'b000,
    bne  = 3'b001,
    blt  = 3'b100,
    bge  = 3'b101,
    bltu = 3'b110,
    bgeu = 3'b111
} branch_funct3_t;

typedef enum bit [2:0] {
    lb  = 3'b000,
    lh  = 3'b001,
    lw  = 3'b010,
    lbu = 3'b100,
    lhu = 3'b101
} load_funct3_t;

typedef enum bit [2:0] {
    sb = 3'b000,
    sh = 3'b001,
    sw = 3'b010
} store_funct3_t;

typedef enum bit [2:0] {
    add  = 3'b000, //check bit30 for sub if op_reg opcode
    sll  = 3'b001,
    slt  = 3'b010,
    sltu = 3'b011,
    axor = 3'b100,
    sr   = 3'b101, //check bit30 for logical/arithmetic
    aor  = 3'b110,
    aand = 3'b111
} arith_funct3_t;

typedef enum bit [2:0] {
    alu_add = 3'b000,
    alu_sll = 3'b001,
    alu_sra = 3'b010,
    alu_sub = 3'b011,
    alu_xor = 3'b100,
    alu_srl = 3'b101,
    alu_or  = 3'b110,
    alu_and = 3'b111
} alu_ops;

// M-extension - guess it really should be rv32im_types now
typedef enum bit [1:0] { 
    mul_lo = 2'b00,
    mul_ss = 2'b01,
    mul_su = 2'b10,
    mul_uu = 2'b11
 } mul_ops;

 typedef enum bit [1:0] { 
    div_signed = 2'b00,
    div_unsigned = 2'b01,
    rem_signed = 2'b10,
    rem_unsigned = 2'b11
  } div_ops;

typedef struct {

    // Common
    rv32i_opcode opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    // ID
    alumux::alumux1_sel_t alumux1_sel;
    alumux::alumux2_sel_t alumux2_sel;
    cmpmux::cmpmux_sel_t cmpmux_sel;
    logic load_data_out;
    logic ras_pop;

    // EX
    alu_ops aluop;
    mul_ops mulop;
    div_ops divop;
    branch_funct3_t cmpop;
    marmux::marmux_sel_t marmux_sel;
    logic load_mar;

    // MEM
    logic dmem_read;
    logic dmem_write;
    logic [3:0] dmem_wmask;
    logic [3:0] dmem_rmask;

    // WB
    regfilemux::regfilemux_sel_t regfilemux_sel;
    logic load_regfile;

} rv32i_control_word;


//IF_ID
typedef struct {

    /* RVFI Monitor */
    rv32i_word pc_rdata;
    rv32i_word pc_wdata;

    /*Decode*/
    rv32i_word imem_rdata;

    logic pred_br_taken;
    rv32i_word pred_pc;

    logic done;
    logic valid;

} IF_ID;

typedef struct {
    /* RVFI Monitor */
    rv32i_word pc_rdata;
    rv32i_word pc_wdata;
    rv32i_reg rs1;
    rv32i_reg rs2;

    /*Decode*/
    rv32i_word imem_rdata;
    rv32i_control_word control_word;
    logic pred_br_taken;
    rv32i_word pred_pc;
    rv32i_word rs1_out;
    rv32i_word rs2_out;
    rv32i_reg rd;
    logic done;
    logic valid;


} ID_EX;

typedef struct {

    /* RVFI Monitor */
    rv32i_word pc_rdata;
    rv32i_word pc_wdata;
    rv32i_reg rs1;
    rv32i_reg rs2;
    rv32i_word imem_rdata;

    /*Decode*/
    rv32i_control_word control_word;
    rv32i_word rs1_out;
    rv32i_word rs2_out;
    rv32i_reg rd;
    rv32i_word  alu_out;
    logic cmp_out;
    logic done;
    logic valid;


} EX_MEM;

typedef struct {

    /* RVFI Monitor */
    rv32i_word pc_rdata;
    rv32i_word pc_wdata;
    rv32i_reg rs1;
    rv32i_reg rs2;
    rv32i_word imem_rdata;
    rv32i_word  dmem_addr;

    /*Decode*/
    rv32i_control_word control_word;
    rv32i_word rs1_out;
    rv32i_word rs2_out;
    rv32i_reg rd;
    rv32i_word  dmem_rdata;
    rv32i_word  dmem_wdata;
    rv32i_word  alu_out;
    logic cmp_out;
    logic done;
    logic valid;
    rv32i_word regfilemux_out;

} MEM_WB;


endpackage : rv32i_types
