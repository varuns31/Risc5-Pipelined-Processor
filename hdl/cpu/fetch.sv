

module fetch
import rv32i_types::*;
(
    input logic clk, rst,
    input rv32i_word alu_out,
    input logic pc_stall,
    input logic br_taken,
    input logic jalr_br_taken,

    output IF_ID struct_out,

    //I-Cache signals
    input logic imem_resp,
    input rv32i_word imem_rdata,
    input logic btb_miss,
    input rv32i_word btb_rdata,
    input logic branch_mispredicted,
    input rv32i_word ex_pc_wdata,
    output logic imem_read,
    output logic [31:0] imem_address
);

rv32i_word pc, pc_next;

always_ff @ (posedge clk) begin
    if(rst)
        pc <= 32'h40000000;
    else 
        pc <= pc_next;
end


always_comb begin
    if (pc_stall)
        pc_next = pc;
    else if(branch_mispredicted)
        pc_next = ex_pc_wdata;
    else if (~btb_miss) begin
        pc_next = btb_rdata;
    end
    else 
        pc_next = pc + 4;
end


always_comb begin
    struct_out.valid = 1'b1;
    if (branch_mispredicted) struct_out.valid = 1'b0;
end

assign struct_out.pc_rdata =  pc;
assign struct_out.pc_wdata = pc_next; //branches will change this in execute
assign struct_out.imem_rdata = imem_rdata;
assign struct_out.done = imem_resp;
assign struct_out.pred_br_taken = ~btb_miss;
always_comb begin
    if(btb_miss) 
        struct_out.pred_pc = '0;
    else 
        struct_out.pred_pc = btb_rdata;
end

assign imem_read = (rst) ? 1'b0 : 1'b1; //always be reading?
assign imem_address = pc;


endmodule