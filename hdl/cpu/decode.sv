module Decode
import rv32i_types::*;
(
    input IF_ID fetch_input,
    output ID_EX decode_output,
    output logic [31:0] ras_addr_in,
    input logic [31:0] ras_addr_out,
    input logic ras_empty,
    output logic ras_push, ras_pop,
    input logic any_stall,
    input logic branch_mispredicted
);

logic [2:0] funct3;
logic [6:0] funct7;
rv32i_opcode opcode;
rv32i_word data;

assign data = fetch_input.imem_rdata;

assign funct3 = data[14:12];
assign funct7 = data[31:25];
assign opcode = rv32i_opcode'(data[6:0]);


rv32i_reg rs1, rs2, rd;
assign rs1 = data[19:15];
assign rs2 = data[24:20];
assign rd = data[11:7];


rv32i_control_word control_word_next;

control_rom rom(.opcode(opcode),.funct3(funct3),.control_word(control_word_next),.funct7(funct7),.data(data));

always_comb begin
    decode_output.valid = fetch_input.valid;
    if (branch_mispredicted) decode_output.valid = 1'b0;
end

//RAS
assign ras_addr_in = fetch_input.pc_wdata;
always_comb begin : RAS
    ras_push = '0;
    ras_pop = '0;
    if (~branch_mispredicted && ~any_stall) begin //only do stuff if we're not behind a branch or stalled, because this is stateful
        if (opcode == op_jal && (rd == 5'b1 || rd == 5'b101)) ras_push = 1'b1;
        if (opcode == op_jalr) begin
            if (rd == rs1 && (rd == 5'b1 || rd == 5'b101)) ras_push = 1'b1;
            else if ((rd == 5'b1 || rd == 5'b101) && (rs1 == 5'b1 || rs1 == 5'b101) && ~ras_empty) begin ras_pop = 1'b1; ras_push = 1'b1; end
            else if (rd == 5'b1 || rd == 5'b101) ras_push = 1'b1;
            else if ((rs1 == 5'b1 || rs1 == 5'b101) && ~ras_empty) ras_pop = 1'b1;
        end
    end
end
always_comb begin
    decode_output.control_word = control_word_next;
    decode_output.control_word.ras_pop = ras_pop;
end



assign decode_output.pc_rdata = fetch_input.pc_rdata;
assign decode_output.pc_wdata = (ras_pop) ? ras_addr_out : fetch_input.pc_wdata;
assign decode_output.imem_rdata = fetch_input.imem_rdata;
assign decode_output.rs1_out = '0;
assign decode_output.rs2_out = '0;
assign decode_output.rs1 = rs1;
assign decode_output.rs2 = rs2;
assign decode_output.rd = rd;
assign decode_output.done = fetch_input.done;
assign decode_output.pred_br_taken = fetch_input.pred_br_taken;
assign decode_output.pred_pc = fetch_input.pred_pc;
endmodule