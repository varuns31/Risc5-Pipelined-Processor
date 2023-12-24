module execute
import rv32i_types::*;
(
    input logic clk, rst,
    input ID_EX struct_in,
    output EX_MEM struct_out,

    input rv32i_word rs1_out,
    input rv32i_word rs2_out,
    input MEM_WB fwd_mem_wb,
    input EX_MEM fwd_ex_mem,
    input rv32i_word regfilemux_out, 

    output rv32i_reg rs1, rs2,

    //For PC during branch instructions
    output logic bubble_prop,
    output rv32i_word alu_out,

    output logic branch_mispredicted,
    output logic btb_write,
    output rv32i_word ex_pc_wdata,
    output rv32i_word ex_pc,

    //Mul/div bubble
    output logic mul_div_bubble
);

//change for slight optimization
logic br_en, br_taken , br_not_taken;
assign br_taken =  br_en & struct_in.valid & struct_in.done & ~bubble_prop;
assign br_not_taken = ~br_en & struct_in.valid & struct_in.done & ~bubble_prop;

assign ex_pc = struct_out.pc_rdata;
assign btb_write = br_en;

logic branch_mispredicted;
assign branch_mispredicted =  struct_in.valid & struct_in.done & ~bubble_prop & ((struct_in.pred_br_taken & br_not_taken) || (~struct_in.pred_br_taken & br_taken) || (struct_in.control_word.opcode == op_jalr || struct_in.control_word.opcode == op_jal));

//Forwarding
ID_EX struct_fwd;
always_comb begin
    struct_fwd = struct_in;
    //RS1 forwarding
    begin
        if (fwd_ex_mem.control_word.load_regfile && fwd_ex_mem.done && fwd_ex_mem.valid && fwd_ex_mem.rd != '0 && fwd_ex_mem.rd == rs1) begin
            if(fwd_ex_mem.control_word.regfilemux_sel == regfilemux::br_en )begin
                struct_out.rs1_out = fwd_ex_mem.cmp_out;
            end
            else if(fwd_ex_mem.control_word.regfilemux_sel == regfilemux::pc_plus4 )begin
                struct_out.rs1_out = fwd_ex_mem.pc_rdata + 4;
            end
            else if(fwd_ex_mem.control_word.regfilemux_sel == regfilemux::u_imm )begin
                struct_out.rs1_out = {fwd_ex_mem.imem_rdata[31:12], 12'h000};;
            end
            else    
                struct_out.rs1_out = fwd_ex_mem.alu_out; //if memory is loading to rd, then this won't catch it, but a bubble will appear, so it will be caught next cycle
        end else if (fwd_mem_wb.control_word.load_regfile && fwd_mem_wb.done && fwd_mem_wb.valid && fwd_mem_wb.rd != '0 && fwd_mem_wb.rd == rs1) begin
            struct_out.rs1_out = regfilemux_out; //dont discriminate the source of the write data
        end
        else begin
            struct_out.rs1_out = rs1_out;
        end
    end
    //RS2 forwarding
    begin
        if (fwd_ex_mem.control_word.load_regfile && fwd_ex_mem.done && fwd_ex_mem.valid && fwd_ex_mem.rd != '0 && fwd_ex_mem.rd == rs2) begin
            if(fwd_ex_mem.control_word.regfilemux_sel == regfilemux::br_en )begin
                struct_out.rs2_out = fwd_ex_mem.cmp_out;
            end
            else if(fwd_ex_mem.control_word.regfilemux_sel == regfilemux::pc_plus4 )begin
                struct_out.rs2_out = fwd_ex_mem.pc_rdata + 4;
            end
            else if(fwd_ex_mem.control_word.regfilemux_sel == regfilemux::u_imm )begin
                struct_out.rs2_out = {fwd_ex_mem.imem_rdata[31:12], 12'h000};;
            end
            else    
            struct_out.rs2_out = fwd_ex_mem.alu_out;
        end else if (fwd_mem_wb.control_word.load_regfile && fwd_mem_wb.done && fwd_mem_wb.valid && fwd_mem_wb.rd != '0 && fwd_mem_wb.rd == rs2) begin
            struct_out.rs2_out = regfilemux_out;
        end
        else begin
            struct_out.rs2_out = rs2_out;
        end
    end
end

assign rs1 = struct_in.rs1;
assign rs2 = struct_in.rs2;

logic [31:0] alumux_a, alumux_b, alu_res;
alu ALU(
    .aluop(struct_in.control_word.aluop),
    .a(alumux_a),
    .b(alumux_b),
    .f(alu_res)
);
assign alu_out = alu_res;

//CMP
logic [31:0] cmp_in;
logic cmp_out;
cmp CMP(
    .cmpop(struct_in.control_word.cmpop),
    .rs1_out(struct_out.rs1_out),
    .cmp_in(cmp_in),
    .br_en(cmp_out)
);

//MUL
logic [63:0] mul_out;
logic mul_start, mul_done;
mul MUL(
    .clk(clk),
    .rst(rst),
    .multiplicand(struct_out.rs1_out),
    .multiplier(struct_out.rs2_out),
    .mulop(struct_out.control_word.mulop),
    .start(mul_start),
    .result(mul_out),
    .done(mul_done)
);

//DIV
logic [31:0] div_quotient, div_remainder;
logic div_start, div_done;
div DIV(
    .clk(clk),
    .rst(rst),
    .dividend(struct_out.rs1_out),
    .divisor(struct_out.rs2_out),
    .divop(struct_out.control_word.divop),
    .start(div_start),
    .quotient(div_quotient),
    .remainder(div_remainder),
    .done(div_done)
);


//Bubble logic
always_comb begin
    bubble_prop = 1'b0;
    if( ( fwd_ex_mem.control_word.opcode == op_load  || fwd_ex_mem.control_word.opcode == op_lui || fwd_ex_mem.control_word.opcode == op_auipc) && (fwd_ex_mem.rd == struct_out.rs1 || fwd_ex_mem.rd == struct_out.rs2) && fwd_ex_mem.valid && fwd_ex_mem.rd != '0) begin 
        bubble_prop = 1'b1;
    end
end

//Multiplier/Divider logic
always_comb begin
    mul_start = 1'b0;
    div_start = 1'b0;
    if (struct_in.valid && struct_in.done && ~bubble_prop) begin //only do work if no bubble - allow forwarding
        if (struct_in.control_word.opcode == op_reg && struct_in.control_word.funct7 == 7'b0000001 && struct_in.control_word.funct3[2] == 1'b0) mul_start = 1'b1;
        if (struct_in.control_word.opcode == op_reg && struct_in.control_word.funct7 == 7'b0000001 && struct_in.control_word.funct3[2] == 1'b1) div_start = 1'b1;
    end
end
assign mul_div_bubble = (mul_start & ~mul_done) || (div_start && ~div_done);


//struct_out
always_comb begin
    //defaults
    struct_out.pc_rdata = struct_in.pc_rdata;
    struct_out.pc_wdata = struct_in.pc_wdata;
    ex_pc_wdata = struct_in.pc_rdata + 4;
    if(branch_mispredicted && br_not_taken)
        struct_out.pc_wdata = struct_in.pc_rdata + 4;
    struct_out.rs1 = struct_in.rs1;
    struct_out.rs2 = struct_in.rs2;
    struct_out.imem_rdata = struct_in.imem_rdata;
    struct_out.control_word = struct_in.control_word;

    struct_out.rd = struct_in.rd;
    struct_out.cmp_out = cmp_out;
    struct_out.done = struct_in.done;
    struct_out.valid = (bubble_prop || mul_div_bubble) ? 1'b0 : struct_in.valid;

    if (mul_start) begin
        unique case (struct_in.control_word.mulop)
            mul_lo: struct_out.alu_out = mul_out[31:0];
            mul_ss, mul_su, mul_uu: struct_out.alu_out = mul_out[63:32];
        endcase
    end
    else if (div_start) begin
        unique case (struct_in.control_word.divop)
            div_signed, div_unsigned: struct_out.alu_out = div_quotient;
            rem_signed, rem_unsigned: struct_out.alu_out = div_remainder;
        endcase
    end
    else struct_out.alu_out = alu_out;

    //branching
    br_en = '0;
    case (struct_in.control_word.opcode)
        op_br: begin
            br_en = cmp_out;
            if (br_en) begin
                struct_out.pc_wdata = alu_out;
                ex_pc_wdata = alu_out;
            end
        end
        op_jal: begin
            br_en = 1'b1; //unconditonal branching
            struct_out.pc_wdata = alu_out;
            ex_pc_wdata = alu_out;
        end
        op_jalr: begin
            br_en = ~struct_in.control_word.ras_pop; //signal branch only if we didn't pop ras
            struct_out.pc_wdata = {alu_out[31:1],1'b0};
            ex_pc_wdata = {alu_out[31:1],1'b0};
        end
    endcase
end


/*             MUXES               */

logic [31:0] i_imm, s_imm, b_imm, u_imm, j_imm;
logic [31:0] data;
assign data = struct_in.imem_rdata;
assign i_imm = {{21{data[31]}}, data[30:20]};
assign s_imm = {{21{data[31]}}, data[30:25], data[11:7]};
assign b_imm = {{20{data[31]}}, data[7], data[30:25], data[11:8], 1'b0};
assign u_imm = {data[31:12], 12'h000};
assign j_imm = {{12{data[31]}}, data[19:12], data[20], data[30:21], 1'b0};

always_comb begin : MUXES

    unique case (struct_in.control_word.alumux1_sel)
        alumux::rs1_out: alumux_a = struct_out.rs1_out;
        alumux::pc_out: alumux_a = struct_in.pc_rdata;
        default: alumux_a = '0;
    endcase

    unique case (struct_in.control_word.alumux2_sel)
        alumux::i_imm: alumux_b = i_imm;
        alumux::u_imm: alumux_b = u_imm;
        alumux::b_imm: alumux_b = b_imm;
        alumux::s_imm: alumux_b = s_imm;
        alumux::j_imm: alumux_b = j_imm;
        alumux::rs2_out: alumux_b = struct_out.rs2_out;
        default: alumux_b = '0;
    endcase

    unique case (struct_in.control_word.cmpmux_sel)
        cmpmux::rs2_out: cmp_in = struct_out.rs2_out;
        cmpmux::i_imm: cmp_in = i_imm;
        default: cmp_in = '0;
    endcase
end


endmodule